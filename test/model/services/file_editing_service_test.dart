import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services/file_editing_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  group('FileEditingService', () {
    test('openEditor opens inline editor tab when provided', () async {
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'hello world';
      final opened = <(String, String)>[];
      final messages = <String>[];
      final service = _service(
        shell: shell,
        onOpenEditorTab: (path, contents) async => opened.add((path, contents)),
        onMessage: messages.add,
      );

      await service.openEditor(_entry('readme.md'), '/srv');

      expect(opened, [('/srv/readme.md', 'hello world')]);
      expect(messages, isEmpty);
    });

    test('openEditor emits fallback message when inline editor is unavailable', () async {
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'hello world';
      final messages = <String>[];
      final service = _service(
        shell: shell,
        onMessage: messages.add,
      );

      await service.openEditor(_entry('readme.md'), '/srv');

      expect(messages, ['Inline editor unavailable. Open via editor tab instead.']);
    });

    test('openLocally creates cache when missing, launches local app, and returns session', () async {
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'remote contents';
      final cache = _FakeRemoteEditorCache();
      final launched = <String>[];
      final messages = <String>[];
      final service = _service(
        shell: shell,
        cache: cache,
        launchLocalApp: (path) async => launched.add(path),
        onMessage: messages.add,
      );

      final session = await service.openLocally(_entry('readme.md'), '/srv');

      expect(session, isNotNull);
      expect(session?.remotePath, '/srv/readme.md');
      expect(cache.createdSessions, hasLength(1));
      expect(launched, [cache.createdSessions.single.workingPath]);
      expect(messages.single, contains('Opened local copy:'));
    });

    test('openLocally reuses existing cache session when present', () async {
      final cache = _FakeRemoteEditorCache(
        loadedSessions: {
          'test-host:/srv/readme.md': const CachedEditorSession(
            snapshotPath: '/tmp/readme.server',
            workingPath: '/tmp/readme.md',
          ),
        },
      );
      final launched = <String>[];
      final service = _service(
        cache: cache,
        launchLocalApp: (path) async => launched.add(path),
      );

      final session = await service.openLocally(_entry('readme.md'), '/srv');

      expect(session?.localPath, '/tmp/readme.md');
      expect(cache.createCalls, 0);
      expect(launched, ['/tmp/readme.md']);
    });

    test('syncLocalEdit writes local contents when remote matches snapshot', () async {
      final dir = await Directory.systemTemp.createTemp('cwatch-file-editing-');
      addTearDown(() => dir.delete(recursive: true));
      final working = File('${dir.path}/work.txt')..writeAsStringSync('local-v2');
      final snapshot = File('${dir.path}/snap.txt')..writeAsStringSync('base');
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'base';
      final messages = <String>[];
      final synced = <LocalFileSession>[];
      final service = _service(
        shell: shell,
        onMessage: messages.add,
      );
      final session = LocalFileSession(
        localPath: working.path,
        snapshotPath: snapshot.path,
        remotePath: '/srv/readme.md',
      );

      await service.syncLocalEdit(session, synced.add);

      expect(shell.writes['/srv/readme.md'], 'local-v2');
      expect(snapshot.readAsStringSync(), 'local-v2');
      expect(session.lastSynced, isNotNull);
      expect(synced, [same(session)]);
      expect(messages.single, contains('Synced /srv/readme.md'));
    });

    test('syncLocalEdit pulls remote changes when local file is unchanged', () async {
      final dir = await Directory.systemTemp.createTemp('cwatch-file-editing-');
      addTearDown(() => dir.delete(recursive: true));
      final working = File('${dir.path}/work.txt')..writeAsStringSync('base');
      final snapshot = File('${dir.path}/snap.txt')..writeAsStringSync('base');
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'remote-new';
      final messages = <String>[];
      final service = _service(
        shell: shell,
        onMessage: messages.add,
      );
      final session = LocalFileSession(
        localPath: working.path,
        snapshotPath: snapshot.path,
        remotePath: '/srv/readme.md',
      );

      await service.syncLocalEdit(session, (_) {});

      expect(working.readAsStringSync(), 'remote-new');
      expect(snapshot.readAsStringSync(), 'remote-new');
      expect(messages.single, contains('Remote changes pulled'));
    });

    test('syncLocalEdit uses merge dialog when local and remote diverged', () async {
      final dir = await Directory.systemTemp.createTemp('cwatch-file-editing-');
      addTearDown(() => dir.delete(recursive: true));
      final working = File('${dir.path}/work.txt')..writeAsStringSync('local-new');
      final snapshot = File('${dir.path}/snap.txt')..writeAsStringSync('base');
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'remote-new';
      final promptCalls = <(String, String, String)>[];
      final messages = <String>[];
      final synced = <LocalFileSession>[];
      final service = _service(
        shell: shell,
        promptMergeDialog: ({
          required remotePath,
          required local,
          required remote,
        }) async {
          promptCalls.add((remotePath, local, remote));
          return 'merged-result';
        },
        onMessage: messages.add,
      );
      final session = LocalFileSession(
        localPath: working.path,
        snapshotPath: snapshot.path,
        remotePath: '/srv/readme.md',
      );

      await service.syncLocalEdit(session, synced.add);

      expect(promptCalls, [('/srv/readme.md', 'local-new', 'remote-new')]);
      expect(shell.writes['/srv/readme.md'], 'merged-result');
      expect(working.readAsStringSync(), 'merged-result');
      expect(snapshot.readAsStringSync(), 'merged-result');
      expect(session.lastSynced, isNotNull);
      expect(synced, [same(session)]);
      expect(messages.single, contains('Merged and synced'));
    });

    test('refreshCacheFromServer updates working copy directly when unchanged', () async {
      final dir = await Directory.systemTemp.createTemp('cwatch-file-editing-');
      addTearDown(() => dir.delete(recursive: true));
      final working = File('${dir.path}/work.txt')..writeAsStringSync('same');
      final snapshot = File('${dir.path}/snap.txt')..writeAsStringSync('old');
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'same';
      final messages = <String>[];
      final service = _service(
        shell: shell,
        onMessage: messages.add,
      );
      final session = LocalFileSession(
        localPath: working.path,
        snapshotPath: snapshot.path,
        remotePath: '/srv/readme.md',
      );

      await service.refreshCacheFromServer(session);

      expect(working.readAsStringSync(), 'same');
      expect(snapshot.readAsStringSync(), 'same');
      expect(messages.single, contains('Cache refreshed'));
    });

    test('refreshCacheFromServer keeps remote snapshot when merge is cancelled', () async {
      final dir = await Directory.systemTemp.createTemp('cwatch-file-editing-');
      addTearDown(() => dir.delete(recursive: true));
      final working = File('${dir.path}/work.txt')..writeAsStringSync('local-change');
      final snapshot = File('${dir.path}/snap.txt')..writeAsStringSync('old');
      final shell = _FakeRemoteShellService()
        ..fileContents['/srv/readme.md'] = 'remote-change';
      final service = _service(
        shell: shell,
        promptMergeDialog: ({
          required remotePath,
          required local,
          required remote,
        }) async => null,
      );
      final session = LocalFileSession(
        localPath: working.path,
        snapshotPath: snapshot.path,
        remotePath: '/srv/readme.md',
      );

      await service.refreshCacheFromServer(session);

      expect(working.readAsStringSync(), 'local-change');
      expect(snapshot.readAsStringSync(), 'remote-change');
    });

    test('clearCachedCopy delegates to cache and emits message', () async {
      final cache = _FakeRemoteEditorCache();
      final messages = <String>[];
      final service = _service(
        cache: cache,
        onMessage: messages.add,
      );
      final session = LocalFileSession(
        localPath: '/tmp/work.txt',
        snapshotPath: '/tmp/snap.txt',
        remotePath: '/srv/readme.md',
      );

      await service.clearCachedCopy(session);

      expect(cache.clearedKeys, ['test-host:/srv/readme.md']);
      expect(messages.single, contains('Cleared cached copy'));
    });
  });
}

FileEditingService _service({
  _FakeRemoteShellService? shell,
  _FakeRemoteEditorCache? cache,
  Future<String?> Function({
    required String remotePath,
    required String local,
    required String remote,
  })? promptMergeDialog,
  Future<void> Function(String path)? launchLocalApp,
  void Function(String message)? onMessage,
  Future<void> Function(String path, String initialContent)? onOpenEditorTab,
}) {
  return FileEditingService(
    shellService: shell ?? _FakeRemoteShellService(),
    host: const SshHost(
      name: 'test-host',
      hostname: 'localhost',
      port: 22,
      available: true,
    ),
    cache: cache ?? _FakeRemoteEditorCache(),
    runShellWrapper: <T>(action) => action(),
    promptMergeDialog:
        promptMergeDialog ??
        ({
          required remotePath,
          required local,
          required remote,
        }) async => null,
    launchLocalApp: launchLocalApp ?? (_) async {},
    onMessage: onMessage,
    onOpenEditorTab: onOpenEditorTab,
  );
}

class _FakeRemoteEditorCache extends RemoteEditorCache {
  _FakeRemoteEditorCache({
    this.loadedSessions = const {},
  });

  final Map<String, CachedEditorSession> loadedSessions;
  final List<CachedEditorSession> createdSessions = [];
  final List<String> clearedKeys = [];
  int createCalls = 0;

  @override
  Future<CachedEditorSession?> loadSession({
    required String host,
    required String remotePath,
  }) async {
    return loadedSessions['$host:$remotePath'];
  }

  @override
  Future<CachedEditorSession> createSession({
    required String host,
    required String remotePath,
    required String contents,
  }) async {
    createCalls += 1;
    final session = CachedEditorSession(
      snapshotPath: '/tmp/${remotePath.hashCode}.server',
      workingPath: '/tmp/${remotePath.hashCode}.txt',
    );
    createdSessions.add(session);
    return session;
  }

  @override
  Future<void> clearSession({
    required String host,
    required String remotePath,
  }) async {
    clearedKeys.add('$host:$remotePath');
  }
}

class _FakeRemoteShellService extends RemoteShellService {
  final Map<String, String> fileContents = {};
  final Map<String, String> writes = {};

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    return fileContents[path] ?? '';
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    fileContents[path] = contents;
    writes[path] = contents;
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
    Duration timeout = const Duration(seconds: 30),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();
}

RemoteFileEntry _entry(String name) {
  return RemoteFileEntry(
    name: name,
    isDirectory: false,
    sizeBytes: 10,
    modified: DateTime(2024, 1, 1),
  );
}
