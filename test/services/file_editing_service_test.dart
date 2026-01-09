import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services/file_editing_service.dart';

class FakeRemoteShellService extends RemoteShellService {
  FakeRemoteShellService() : super(debugMode: false, observer: null);

  String? _readFileResult;
  Exception? _readFileError;
  String? _lastWrittenFile;
  String? _lastWrittenContent;
  Exception? _writeFileError;

  void setReadFileResult(String result) {
    _readFileResult = result;
    _readFileError = null;
  }

  void setReadFileError(Exception error) {
    _readFileError = error;
    _readFileResult = null;
  }

  void setWriteFileError(Exception error) {
    _writeFileError = error;
  }

  String? get lastWrittenFile => _lastWrittenFile;
  String? get lastWrittenContent => _lastWrittenContent;

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    if (_readFileError != null) {
      throw _readFileError!;
    }
    return _readFileResult ?? '';
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    if (_writeFileError != null) {
      throw _writeFileError!;
    }
    _lastWrittenFile = path;
    _lastWrittenContent = contents;
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) {
    throw UnimplementedError();
  }
}

class FakeRemoteEditorCache extends RemoteEditorCache {
  FakeRemoteEditorCache() : super();

  final Map<String, CachedEditorSession> _sessions = {};
  final Map<String, String> _sessionContents = {};

  void setSession(String host, String remotePath, CachedEditorSession session, {String? contents}) {
    _sessions['$host:$remotePath'] = session;
    if (contents != null) {
      _sessionContents['$host:$remotePath'] = contents;
    }
  }

  @override
  Future<CachedEditorSession?> loadSession({
    required String host,
    required String remotePath,
  }) async {
    return _sessions['$host:$remotePath'];
  }

  @override
  Future<CachedEditorSession> createSession({
    required String host,
    required String remotePath,
    required String contents,
  }) async {
    final session = CachedEditorSession(
      workingPath: '/cache/$host/$remotePath/working',
      snapshotPath: '/cache/$host/$remotePath/snapshot',
    );
    _sessions['$host:$remotePath'] = session;
    _sessionContents['$host:$remotePath'] = contents;
    return session;
  }

  @override
  Future<void> clearSession({
    required String host,
    required String remotePath,
  }) async {
    _sessions.remove('$host:$remotePath');
    _sessionContents.remove('$host:$remotePath');
  }
}

class FakeSshHost extends SshHost {
  FakeSshHost() : super(
    name: 'test-host',
    hostname: 'example.com',
    port: 22,
    available: true,
  );
}

RemoteFileEntry _createEntry(String name, {bool isDirectory = false}) {
  return RemoteFileEntry(
    name: name,
    isDirectory: isDirectory,
    sizeBytes: isDirectory ? 0 : 100,
    modified: DateTime.now(),
  );
}

void main() {
  group('FileEditingService', () {
    late FakeRemoteShellService shellService;
    late FakeSshHost host;
    late FakeRemoteEditorCache cache;
    late FileEditingService service;
    String? onMessageCalled;
    String? onOpenEditorTabPath;
    String? onOpenEditorTabContent;
    String? promptMergeDialogCalled;
    String? launchLocalAppCalled;
    LocalFileSession? syncedSession;

    setUp(() {
      shellService = FakeRemoteShellService();
      host = FakeSshHost();
      cache = FakeRemoteEditorCache();
      onMessageCalled = null;
      onOpenEditorTabPath = null;
      onOpenEditorTabContent = null;
      promptMergeDialogCalled = null;
      launchLocalAppCalled = null;
      syncedSession = null;

      service = FileEditingService(
        shellService: shellService,
        host: host,
        cache: cache,
        runShellWrapper: <T>(action) => action(),
        promptMergeDialog: ({required remotePath, required local, required remote}) async {
          promptMergeDialogCalled = remotePath;
          return null; // Cancel by default
        },
        launchLocalApp: (path) async {
          launchLocalAppCalled = path;
        },
        onMessage: (message) => onMessageCalled = message,
        onOpenEditorTab: (path, content) async {
          onOpenEditorTabPath = path;
          onOpenEditorTabContent = content;
        },
      );
    });

    group('openEditor', () {
      test('opens file in editor tab', () async {
        shellService.setReadFileResult('file contents');
        final entry = _createEntry('file.txt');

        await service.openEditor(entry, '/home');

        expect(onOpenEditorTabPath, '/home/file.txt');
        expect(onOpenEditorTabContent, 'file contents');
        expect(onMessageCalled, isNull);
      });

      test('shows message when editor tab callback not set', () async {
        service = FileEditingService(
          shellService: shellService,
          host: host,
          cache: cache,
          runShellWrapper: <T>(action) => action(),
          promptMergeDialog: ({required remotePath, required local, required remote}) async => null,
          launchLocalApp: (path) async {},
          onMessage: (message) => onMessageCalled = message,
        );
        shellService.setReadFileResult('file contents');
        final entry = _createEntry('file.txt');

        await service.openEditor(entry, '/home');

        expect(onMessageCalled, contains('Inline editor unavailable'));
      });

      test('handles read error', () async {
        shellService.setReadFileError(Exception('Permission denied'));
        final entry = _createEntry('file.txt');

        await service.openEditor(entry, '/home');

        expect(onOpenEditorTabPath, isNull);
        expect(onMessageCalled, contains('Failed to edit file'));
      });
    });

    group('openLocally', () {
      test('opens existing cached session', () async {
        final cachedSession = CachedEditorSession(
          workingPath: '/cache/test-host/home/file.txt/working',
          snapshotPath: '/cache/test-host/home/file.txt/snapshot',
        );
        cache.setSession('test-host', '/home/file.txt', cachedSession);
        final entry = _createEntry('file.txt');

        final result = await service.openLocally(entry, '/home');

        expect(result, isNotNull);
        expect(result?.localPath, '/cache/test-host/home/file.txt/working');
        expect(result?.snapshotPath, '/cache/test-host/home/file.txt/snapshot');
        expect(result?.remotePath, '/home/file.txt');
        expect(launchLocalAppCalled, '/cache/test-host/home/file.txt/working');
        expect(onMessageCalled, contains('Opened local copy'));
      });

      test('creates new session when cache miss', () async {
        shellService.setReadFileResult('file contents');
        final entry = _createEntry('file.txt');

        final result = await service.openLocally(entry, '/home');

        expect(result, isNotNull);
        expect(result?.remotePath, '/home/file.txt');
        expect(launchLocalAppCalled, isNotNull);
        expect(onMessageCalled, contains('Opened local copy'));
      });

      test('handles read error when creating session', () async {
        shellService.setReadFileError(Exception('Read failed'));
        final entry = _createEntry('file.txt');

        final result = await service.openLocally(entry, '/home');

        expect(result, isNull);
        expect(onMessageCalled, contains('Failed to open locally'));
      });
    });

    group('syncLocalEdit', () {
      test('syncs when remote matches base', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('local changes');
        await snapshotFile.writeAsString('base content');
        shellService.setReadFileResult('base content'); // Remote matches base

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.syncLocalEdit(session, (s) => syncedSession = s);

        expect(shellService.lastWrittenFile, '/home/file.txt');
        expect(shellService.lastWrittenContent, 'local changes');
        expect(syncedSession, session);
        expect(await snapshotFile.readAsString(), 'local changes');
        expect(onMessageCalled, contains('Synced'));
      });

      test('pulls remote changes when local matches base', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('base content');
        await snapshotFile.writeAsString('base content');
        shellService.setReadFileResult('remote changes'); // Remote changed

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.syncLocalEdit(session, (s) => syncedSession = s);

        expect(shellService.lastWrittenFile, isNull); // Should not write
        expect(await workingFile.readAsString(), 'remote changes');
        expect(await snapshotFile.readAsString(), 'remote changes');
        expect(onMessageCalled, contains('Remote changes pulled'));
      });

      test('prompts merge when both changed', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('local changes');
        await snapshotFile.writeAsString('base content');
        shellService.setReadFileResult('remote changes'); // Both changed

        String? mergedResult;
        service = FileEditingService(
          shellService: shellService,
          host: host,
          cache: cache,
          runShellWrapper: <T>(action) => action(),
          promptMergeDialog: ({required remotePath, required local, required remote}) async {
            promptMergeDialogCalled = remotePath;
            mergedResult = 'merged content';
            return mergedResult;
          },
          launchLocalApp: (path) async {},
          onMessage: (message) => onMessageCalled = message,
        );

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.syncLocalEdit(session, (s) => syncedSession = s);

        expect(promptMergeDialogCalled, '/home/file.txt');
        expect(shellService.lastWrittenContent, 'merged content');
        expect(await workingFile.readAsString(), 'merged content');
        expect(await snapshotFile.readAsString(), 'merged content');
        expect(onMessageCalled, contains('Merged and synced'));
      });

      test('skips sync when merge cancelled', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('local changes');
        await snapshotFile.writeAsString('base content');
        shellService.setReadFileResult('remote changes');

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.syncLocalEdit(session, (s) => syncedSession = s);

        expect(shellService.lastWrittenFile, isNull);
        expect(syncedSession, isNull);
      });

      test('handles sync error', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('local changes');
        await snapshotFile.writeAsString('base content');
        shellService.setReadFileResult('base content');
        shellService.setWriteFileError(Exception('Write failed'));

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.syncLocalEdit(session, (s) => syncedSession = s);

        expect(onMessageCalled, contains('Failed to sync'));
      });
    });

    group('refreshCacheFromServer', () {
      test('refreshes when local matches remote', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('remote content');
        await snapshotFile.writeAsString('old content');
        shellService.setReadFileResult('remote content');

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.refreshCacheFromServer(session);

        expect(await snapshotFile.readAsString(), 'remote content');
        expect(onMessageCalled, contains('Cache refreshed'));
      });

      test('prompts merge when local differs from remote', () async {
        final tempDir = Directory.systemTemp.createTempSync('file_editing_test');
        final workingFile = File('${tempDir.path}/working.txt');
        final snapshotFile = File('${tempDir.path}/snapshot.txt');
        await workingFile.writeAsString('local changes');
        await snapshotFile.writeAsString('old content');
        shellService.setReadFileResult('remote changes');

        String? mergedResult;
        service = FileEditingService(
          shellService: shellService,
          host: host,
          cache: cache,
          runShellWrapper: <T>(action) => action(),
          promptMergeDialog: ({required remotePath, required local, required remote}) async {
            mergedResult = 'merged content';
            return mergedResult;
          },
          launchLocalApp: (path) async {},
          onMessage: (message) => onMessageCalled = message,
        );

        final session = LocalFileSession(
          localPath: workingFile.path,
          snapshotPath: snapshotFile.path,
          remotePath: '/home/file.txt',
        );

        await service.refreshCacheFromServer(session);

        expect(await workingFile.readAsString(), 'merged content');
        expect(await snapshotFile.readAsString(), 'remote changes');
      });
    });

    group('clearCachedCopy', () {
      test('clears cached session', () async {
        final session = LocalFileSession(
          localPath: '/cache/working',
          snapshotPath: '/cache/snapshot',
          remotePath: '/home/file.txt',
        );
        cache.setSession('test-host', '/home/file.txt', CachedEditorSession(
          workingPath: '/cache/working',
          snapshotPath: '/cache/snapshot',
        ));

        await service.clearCachedCopy(session);

        expect(await cache.loadSession(host: 'test-host', remotePath: '/home/file.txt'), isNull);
        expect(onMessageCalled, contains('Cleared cached copy'));
      });
    });

    group('hydrateCachedSessions', () {
      test('hydrates cached sessions for files', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
          _createEntry('dir1', isDirectory: true),
        ];
        cache.setSession('test-host', '/home/file1.txt', CachedEditorSession(
          workingPath: '/cache/file1.txt',
          snapshotPath: '/cache/file1.txt.snapshot',
        ));

        final result = await service.hydrateCachedSessions(entries, '/home');

        expect(result.length, 1);
        expect(result['/home/file1.txt'], isNotNull);
        expect(result['/home/file1.txt']?.localPath, '/cache/file1.txt');
      });

      test('skips directories', () async {
        final entries = [
          _createEntry('dir1', isDirectory: true),
        ];

        final result = await service.hydrateCachedSessions(entries, '/home');

        expect(result, isEmpty);
      });
    });
  });
}
