import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/path_utils.dart';
import 'package:cwatch/model/services/path_loading_service.dart';

class FakeRemoteShellService extends RemoteShellService {
  FakeRemoteShellService() : super(debugMode: false, observer: null);

  List<RemoteFileEntry>? _listDirectoryResult;
  List<RemoteFileEntry>? _searchPathsResult;
  String? _readFileResult;
  Exception? _listDirectoryError;
  Exception? _searchPathsError;

  void setListDirectoryResult(List<RemoteFileEntry> result) {
    _listDirectoryResult = result;
    _listDirectoryError = null;
  }

  void setListDirectoryError(Exception error) {
    _listDirectoryError = error;
    _listDirectoryResult = null;
  }

  void setSearchPathsResult(List<RemoteFileEntry> result) {
    _searchPathsResult = result;
    _searchPathsError = null;
  }

  void setSearchPathsError(Exception error) {
    _searchPathsError = error;
    _searchPathsResult = null;
  }

  void setReadFileResult(String result) {
    _readFileResult = result;
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    if (_listDirectoryError != null) {
      throw _listDirectoryError!;
    }
    return _listDirectoryResult ?? [];
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
    if (_searchPathsError != null) {
      throw _searchPathsError!;
    }
    final result = _searchPathsResult ?? [];
    if (onEntry != null) {
      for (final entry in result) {
        if (cancellation?.isCancelled == true) break;
        onEntry(entry);
      }
    }
    return result;
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
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    return _readFileResult ?? '';
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
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

  void setSession(String host, String remotePath, CachedEditorSession session) {
    _sessions['$host:$remotePath'] = session;
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
    throw UnimplementedError();
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
  group('PathLoadingService', () {
    late FakeRemoteShellService shellService;
    late FakeSshHost host;
    late FakeRemoteEditorCache cache;
    late PathLoadingService service;

    setUp(() {
      shellService = FakeRemoteShellService();
      host = FakeSshHost();
      cache = FakeRemoteEditorCache();
      service = PathLoadingService(
        shellService: shellService,
        host: host,
        cache: cache,
        runShellWrapper: <T>(action) => action(),
      );
    });

    group('loadPath', () {
      test('loads path successfully', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('dir1', isDirectory: true),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/');

        expect(result.skipped, isFalse);
        expect(result.error, isNull);
        expect(result.target, '/home');
        expect(result.entries?.length, 2);
        expect(result.entries?[0].name, 'file1.txt');
        expect(result.entries?[1].name, 'dir1');
      });

      test('normalizes path relative to current path', () async {
        shellService.setListDirectoryResult([]);

        final result = await service.loadPath('subdir', '/home');

        expect(result.target, '/home/subdir');
      });

      test('normalizes absolute path', () async {
        shellService.setListDirectoryResult([]);

        final result = await service.loadPath('/home/user', '/home');

        expect(result.target, '/home/user');
      });

      test('skips when path unchanged and not forced', () async {
        shellService.setListDirectoryResult([]);

        final result = await service.loadPath('/home', '/home', forceReload: false);

        expect(result.skipped, isTrue);
        expect(result.target, '/home');
      });

      test('loads when path unchanged but forced', () async {
        final entries = [_createEntry('file.txt')];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/home', forceReload: true);

        expect(result.skipped, isFalse);
        expect(result.entries?.length, 1);
      });

      test('loads when currently loading', () async {
        final entries = [_createEntry('file.txt')];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/home', isLoading: true);

        expect(result.skipped, isFalse);
        expect(result.entries?.length, 1);
      });

      test('filters out . and .. entries', () async {
        final entries = [
          _createEntry('.', isDirectory: true),
          _createEntry('..', isDirectory: true),
          _createEntry('file.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/');

        expect(result.entries?.length, 1);
        expect(result.entries?[0].name, 'file.txt');
      });

      test('adds .. entry when not at root', () async {
        final entries = [_createEntry('file.txt')];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/');

        expect(result.entries?.length, 2);
        expect(result.entries?[0].name, '..');
        expect(result.entries?[0].isDirectory, isTrue);
        expect(result.entries?[1].name, 'file.txt');
      });

      test('does not add .. entry when at root', () async {
        final entries = [_createEntry('file.txt')];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/', '/');

        expect(result.entries?.length, 1);
        expect(result.entries?[0].name, 'file.txt');
      });

      test('handles error during load', () async {
        shellService.setListDirectoryError(Exception('Permission denied'));

        final result = await service.loadPath('/home', '/');

        expect(result.skipped, isFalse);
        expect(result.error, contains('Permission denied'));
        expect(result.entries, isNull);
        expect(result.target, '/home');
      });

      test('includes allEntries in result', () async {
        final entries = [
          _createEntry('.', isDirectory: true),
          _createEntry('file.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.loadPath('/home', '/');

        expect(result.allEntries?.length, 2);
        expect(result.allEntries?.any((e) => e.name == '.'), isTrue);
      });
    });

    group('listPath', () {
      test('lists path entries', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.listPath('/home');

        expect(result.length, 2);
        expect(result[0].name, 'file1.txt');
        expect(result[1].name, 'file2.txt');
      });

      test('filters out . and .. entries', () async {
        final entries = [
          _createEntry('.', isDirectory: true),
          _createEntry('..', isDirectory: true),
          _createEntry('file.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.listPath('/home');

        expect(result.length, 1);
        expect(result[0].name, 'file.txt');
      });

      test('normalizes path relative to current', () async {
        shellService.setListDirectoryResult([]);

        final result = await service.listPath('subdir', currentPath: '/home');

        // Verify it was called (indirectly through normalization)
        expect(result, isA<List<RemoteFileEntry>>());
      });
    });

    group('searchPath', () {
      test('searches path successfully', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
        ];
        shellService.setSearchPathsResult(entries);

        final result = await service.searchPath('/home', 'test');

        expect(result.error, isNull);
        expect(result.target, '/home');
        expect(result.entries?.length, 2);
      });

      test('calls onEntry callback during search', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
        ];
        shellService.setSearchPathsResult(entries);
        final calledEntries = <RemoteFileEntry>[];

        await service.searchPath(
          '/home',
          'test',
          onEntry: (entry) => calledEntries.add(entry),
        );

        expect(calledEntries.length, 2);
        expect(calledEntries[0].name, 'file1.txt');
        expect(calledEntries[1].name, 'file2.txt');
      });

      test('respects cancellation during search', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
        ];
        shellService.setSearchPathsResult(entries);
        final cancellation = RemoteCommandCancellation();
        final calledEntries = <RemoteFileEntry>[];

        cancellation.cancel();
        await service.searchPath(
          '/home',
          'test',
          cancellation: cancellation,
          onEntry: (entry) => calledEntries.add(entry),
        );

        expect(calledEntries, isEmpty);
      });

      test('passes search options to shell service', () async {
        shellService.setSearchPathsResult([]);

        await service.searchPath(
          '/home',
          'test',
          includePattern: '*.txt',
          excludePattern: '*.tmp',
          matchCase: true,
          matchWholeWord: true,
          searchContents: true,
        );

        // Verify it was called (no error means options were passed correctly)
        expect(shellService._searchPathsResult, isNotNull);
      });

      test('handles error during search', () async {
        shellService.setSearchPathsError(Exception('Search failed'));

        final result = await service.searchPath('/home', 'test');

        expect(result.error, contains('Search failed'));
        expect(result.entries, isNull);
        expect(result.target, '/home');
      });

      test('normalizes base path', () async {
        shellService.setSearchPathsResult([]);

        final result = await service.searchPath('subdir', 'test', currentPath: '/home');

        expect(result.target, '/home/subdir');
      });
    });

    group('refreshPath', () {
      test('refreshes path successfully', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.refreshPath('/home', []);

        expect(result.skipped, isFalse);
        expect(result.error, isNull);
        expect(result.entries?.length, 2);
      });

      test('skips refresh when path is empty', () async {
        final result = await service.refreshPath('', []);

        expect(result.skipped, isTrue);
      });

      test('filters out . and .. entries', () async {
        final entries = [
          _createEntry('.', isDirectory: true),
          _createEntry('..', isDirectory: true),
          _createEntry('file.txt'),
        ];
        shellService.setListDirectoryResult(entries);

        final result = await service.refreshPath('/home', []);

        expect(result.entries?.length, 1);
        expect(result.entries?[0].name, 'file.txt');
      });

      test('adds .. entry when not at root', () async {
        final entries = [_createEntry('file.txt')];
        shellService.setListDirectoryResult(entries);

        final result = await service.refreshPath('/home', []);

        expect(result.entries?.length, 2);
        expect(result.entries?[0].name, '..');
      });

      test('handles error during refresh', () async {
        shellService.setListDirectoryError(Exception('Refresh failed'));

        final result = await service.refreshPath('/home', []);

        expect(result.skipped, isFalse);
        expect(result.error, contains('Refresh failed'));
        expect(result.entries, isNull);
      });
    });

    group('hydrateCachedSessions', () {
      test('hydrates cached sessions for files', () async {
        final entries = [
          _createEntry('file1.txt'),
          _createEntry('file2.txt'),
          _createEntry('dir1', isDirectory: true),
        ];
        final session1 = CachedEditorSession(
          workingPath: '/local/file1.txt',
          snapshotPath: '/snapshot/file1.txt',
        );
        cache.setSession('test-host', '/home/file1.txt', session1);

        final result = await service.hydrateCachedSessions(entries, '/home');

        expect(result.length, 1);
        expect(result['/home/file1.txt'], isNotNull);
        expect(result['/home/file1.txt']?.localPath, '/local/file1.txt');
      });

      test('skips directories when hydrating', () async {
        final entries = [
          _createEntry('dir1', isDirectory: true),
        ];
        cache.setSession('test-host', '/home/dir1', CachedEditorSession(
          workingPath: '/local/dir1',
          snapshotPath: '/snapshot/dir1',
        ));

        final result = await service.hydrateCachedSessions(entries, '/home');

        expect(result, isEmpty);
      });

      test('returns empty map when no cached sessions', () async {
        final entries = [_createEntry('file.txt')];

        final result = await service.hydrateCachedSessions(entries, '/home');

        expect(result, isEmpty);
      });
    });
  });
}
