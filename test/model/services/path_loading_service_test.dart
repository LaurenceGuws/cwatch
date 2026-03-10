import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services/path_loading_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  group('PathLoadingService', () {
    test('loadPath skips when target matches current path and reload is not forced', () async {
      final shell = _FakeRemoteShellService();
      final service = _service(shell: shell);

      final result = await service.loadPath(
        '/srv',
        '/srv',
        forceReload: false,
        isLoading: false,
      );

      expect(result.skipped, isTrue);
      expect(result.target, '/srv');
      expect(shell.listCalls, 0);
    });

    test('loadPath normalizes path, filters dot entries, and injects parent row outside root', () async {
      final shell = _FakeRemoteShellService()
        ..directoryEntries = [
          _entry('.'),
          _entry('..', isDirectory: true),
          _entry('logs', isDirectory: true),
          _entry('notes.txt'),
        ];
      final service = _service(shell: shell);

      final result = await service.loadPath(
        '../srv',
        '/home/user',
        forceReload: false,
        isLoading: true,
      );

      expect(result.skipped, isFalse);
      expect(result.target, '/home/srv');
      expect(shell.lastListPath, '/home/srv');
      expect(result.entries?.map((entry) => entry.name).toList(), [
        '..',
        'logs',
        'notes.txt',
      ]);
      expect(result.allEntries?.map((entry) => entry.name).toList(), [
        '.',
        '..',
        'logs',
        'notes.txt',
      ]);
    });

    test('loadPath at root does not inject parent row', () async {
      final shell = _FakeRemoteShellService()
        ..directoryEntries = [
          _entry('alpha'),
          _entry('beta', isDirectory: true),
        ];
      final service = _service(shell: shell);

      final result = await service.loadPath(
        '/',
        '/other',
        forceReload: true,
        isLoading: false,
      );

      expect(result.target, '/');
      expect(result.entries?.map((entry) => entry.name).toList(), [
        'alpha',
        'beta',
      ]);
    });

    test('loadPath returns error result when directory listing fails', () async {
      final shell = _FakeRemoteShellService()
        ..listDirectoryError = StateError('no shell');
      final service = _service(shell: shell);

      final result = await service.loadPath(
        '/broken',
        '/',
        forceReload: true,
        isLoading: false,
      );

      expect(result.skipped, isFalse);
      expect(result.entries, isNull);
      expect(result.error, contains('Bad state: no shell'));
    });

    test('listPath normalizes path and filters dot entries without parent injection', () async {
      final shell = _FakeRemoteShellService()
        ..directoryEntries = [
          _entry('.'),
          _entry('..', isDirectory: true),
          _entry('visible.txt'),
        ];
      final service = _service(shell: shell);

      final entries = await service.listPath('nested/dir', currentPath: '/srv');

      expect(shell.lastListPath, '/srv/nested/dir');
      expect(entries.map((entry) => entry.name).toList(), ['visible.txt']);
    });

    test('searchPath forwards search options and returns success result', () async {
      final shell = _FakeRemoteShellService()
        ..searchEntries = [
          _entry('alpha.txt'),
          _entry('beta.txt'),
        ];
      final streamed = <String>[];
      final cancellation = RemoteCommandCancellation();
      final service = _service(shell: shell);

      final result = await service.searchPath(
        'src',
        'needle',
        currentPath: '/workspace',
        includePattern: '*.dart',
        excludePattern: '*.g.dart',
        matchCase: true,
        matchWholeWord: true,
        searchContents: true,
        onEntry: (entry) => streamed.add(entry.name),
        cancellation: cancellation,
      );

      expect(result.target, '/workspace/src');
      expect(result.entries?.map((entry) => entry.name).toList(), [
        'alpha.txt',
        'beta.txt',
      ]);
      expect(streamed, ['alpha.txt', 'beta.txt']);
      expect(shell.lastSearchBasePath, '/workspace/src');
      expect(shell.lastSearchQuery, 'needle');
      expect(shell.lastIncludePattern, '*.dart');
      expect(shell.lastExcludePattern, '*.g.dart');
      expect(shell.lastMatchCase, isTrue);
      expect(shell.lastMatchWholeWord, isTrue);
      expect(shell.lastSearchContents, isTrue);
      expect(shell.lastCancellation, same(cancellation));
    });

    test('searchPath returns error result when remote search fails', () async {
      final shell = _FakeRemoteShellService()
        ..searchError = StateError('search unavailable');
      final service = _service(shell: shell);

      final result = await service.searchPath('/srv', 'needle');

      expect(result.entries, isNull);
      expect(result.error, contains('Bad state: search unavailable'));
    });

    test('refreshPath skips empty current path and injects parent row for subdirectories', () async {
      final shell = _FakeRemoteShellService()
        ..directoryEntries = [
          _entry('.'),
          _entry('..', isDirectory: true),
          _entry('child', isDirectory: true),
          _entry('file.txt'),
        ];
      final service = _service(shell: shell);

      final skipped = await service.refreshPath('', const []);
      expect(skipped.skipped, isTrue);
      expect(shell.listCalls, 0);

      final refreshed = await service.refreshPath('/srv', const []);

      expect(refreshed.skipped, isFalse);
      expect(refreshed.entries?.map((entry) => entry.name).toList(), [
        '..',
        'child',
        'file.txt',
      ]);
    });

    test('hydrateCachedSessions only returns cached file entries', () async {
      final cache = _FakeRemoteEditorCache(
        sessions: {
          'test-host:/srv/file.txt': const CachedEditorSession(
            snapshotPath: '/tmp/file.server',
            workingPath: '/tmp/file.txt',
          ),
          'test-host:/srv/other.md': const CachedEditorSession(
            snapshotPath: '/tmp/other.server',
            workingPath: '/tmp/other.md',
          ),
        },
      );
      final service = _service(cache: cache);

      final result = await service.hydrateCachedSessions([
        _entry('folder', isDirectory: true),
        _entry('file.txt'),
        _entry('other.md'),
      ], '/srv');

      expect(cache.loadCalls, [
        'test-host:/srv/file.txt',
        'test-host:/srv/other.md',
      ]);
      expect(result.keys.toList()..sort(), ['/srv/file.txt', '/srv/other.md']);
      expect(result['/srv/file.txt']?.localPath, '/tmp/file.txt');
      expect(result['/srv/other.md']?.snapshotPath, '/tmp/other.server');
    });
  });
}

PathLoadingService _service({
  _FakeRemoteShellService? shell,
  _FakeRemoteEditorCache? cache,
}) {
  return PathLoadingService(
    shellService: shell ?? _FakeRemoteShellService(),
    host: const SshHost(
      name: 'test-host',
      hostname: 'localhost',
      port: 22,
      available: true,
    ),
    cache: cache ?? _FakeRemoteEditorCache(),
    runShellWrapper: <T>(action) => action(),
  );
}

class _FakeRemoteEditorCache extends RemoteEditorCache {
  _FakeRemoteEditorCache({this.sessions = const {}});

  final Map<String, CachedEditorSession> sessions;
  final List<String> loadCalls = [];

  @override
  Future<CachedEditorSession?> loadSession({
    required String host,
    required String remotePath,
  }) async {
    final key = '$host:$remotePath';
    loadCalls.add(key);
    return sessions[key];
  }
}

class _FakeRemoteShellService extends RemoteShellService {
  List<RemoteFileEntry> directoryEntries = const [];
  Object? listDirectoryError;
  List<RemoteFileEntry> searchEntries = const [];
  Object? searchError;

  int listCalls = 0;
  String? lastListPath;
  String? lastSearchBasePath;
  String? lastSearchQuery;
  String? lastIncludePattern;
  String? lastExcludePattern;
  bool lastMatchCase = false;
  bool lastMatchWholeWord = false;
  bool lastSearchContents = false;
  RemoteCommandCancellation? lastCancellation;

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    listCalls += 1;
    lastListPath = path;
    if (listDirectoryError != null) {
      throw listDirectoryError!;
    }
    return directoryEntries;
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
  }) async {
    lastSearchBasePath = basePath;
    lastSearchQuery = query;
    lastIncludePattern = includePattern;
    lastExcludePattern = excludePattern;
    lastMatchCase = matchCase;
    lastMatchWholeWord = matchWholeWord;
    lastSearchContents = searchContents;
    lastCancellation = cancellation;
    if (searchError != null) {
      throw searchError!;
    }
    for (final entry in searchEntries) {
      onEntry?.call(entry);
    }
    return searchEntries;
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
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
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
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();
}

RemoteFileEntry _entry(String name, {bool isDirectory = false}) {
  return RemoteFileEntry(
    name: name,
    isDirectory: isDirectory,
    sizeBytes: isDirectory ? 0 : 10,
    modified: DateTime(2024, 1, 1),
  );
}
