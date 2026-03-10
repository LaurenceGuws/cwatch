import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services/explorer_ops.dart';
import 'package:cwatch/model/services/path_loading_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/model/shared/services/explorer_state.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';

void main() {
  group('ExplorerOps', () {
    test('loadPath updates entries, path history, selection, and cached sessions', () async {
      final state = ExplorerState()
        ..searchActive = true
        ..searchQuery = 'old query'
        ..loading = false;
      final selection = ExplorerSelectionState(
        currentPath: '/',
        joinPath: PathUtils.joinPath,
      );
      selection.selectedPaths.add('/stale.txt');
      final loader = _FakePathLoadingService(
        loadPathResult: PathLoadResult.success(
          target: '/srv',
          entries: [
            _entry('logs', isDirectory: true),
            _entry('notes.txt'),
          ],
          allEntries: [
            _entry('.', isDirectory: true),
            _entry('..', isDirectory: true),
            _entry('logs', isDirectory: true),
            _entry('notes.txt'),
          ],
        ),
        hydratedSessions: {
          '/srv/notes.txt': LocalFileSession(
            localPath: '/tmp/notes.txt',
            snapshotPath: '/tmp/notes.server',
            remotePath: '/srv/notes.txt',
          ),
        },
      );
      final notifications = <String>[];
      final pathChanges = <String>[];
      final ops = ExplorerOps(
        state: state,
        pathLoadingService: loader,
        selectionController: selection,
        onPathChanged: pathChanges.add,
        notify: () => notifications.add('notify'),
      );

      await ops.loadPath(
        '/srv',
        currentPath: '/',
        forceReload: false,
        keepSearchActive: false,
      );

      expect(state.searchActive, isFalse);
      expect(state.searchQuery, isEmpty);
      expect(ops.currentPath, '/srv');
      expect(selection.currentPath, '/srv');
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(state.entries.map((entry) => entry.name).toList(), ['logs', 'notes.txt']);
      expect(selection.selectedPaths, isEmpty);
      expect(state.pathHistory.contains('/srv'), isTrue);
      expect(state.pathHistory.contains('/srv/logs'), isTrue);
      expect(state.localEdits['/srv/notes.txt']?.localPath, '/tmp/notes.txt');
      expect(pathChanges, ['/srv']);
      expect(notifications.length, 3);
      expect(loader.lastHydrateBasePath, '/srv');
    });

    test('loadPath surfaces errors and does not mutate loaded entries', () async {
      final state = ExplorerState()
        ..loading = false
        ..entries.add(_entry('keep.txt'));
      final selection = ExplorerSelectionState(
        currentPath: '/',
        joinPath: PathUtils.joinPath,
      );
      final loader = _FakePathLoadingService(
        loadPathResult: PathLoadResult.error(
          target: '/broken',
          error: 'permission denied',
        ),
      );
      final notifications = <String>[];
      final ops = ExplorerOps(
        state: state,
        pathLoadingService: loader,
        selectionController: selection,
        onPathChanged: null,
        notify: () => notifications.add('notify'),
      );

      await ops.loadPath(
        '/broken',
        currentPath: '/',
        forceReload: true,
        keepSearchActive: true,
      );

      expect(state.loading, isFalse);
      expect(state.error, 'permission denied');
      expect(state.entries.map((entry) => entry.name).toList(), ['keep.txt']);
      expect(notifications.length, 2);
    });

    test('searchCurrentPath streams unique entries and replaces with final results', () async {
      final state = ExplorerState()
        ..searchActive = true
        ..entries.add(_entry('stale.txt'))
        ..searchInclude = '*.dart'
        ..searchExclude = '*.g.dart'
        ..searchMatchCase = true
        ..searchMatchWholeWord = true
        ..searchContents = true;
      final selection = ExplorerSelectionState(
        currentPath: '/workspace',
        joinPath: PathUtils.joinPath,
      );
      selection.selectedPaths.add('/workspace/stale.txt');
      final streamed = [
        _entry('alpha.txt'),
        _entry('alpha.txt'),
        _entry('beta', isDirectory: true),
      ];
      final loader = _FakePathLoadingService(
        searchPathResult: PathSearchResult.success(
          target: '/workspace',
          entries: [
            _entry('beta', isDirectory: true),
            _entry('gamma.txt'),
          ],
        ),
        onSearch: ({onEntry}) {
          for (final entry in streamed) {
            onEntry?.call(entry);
          }
        },
      );
      final notifications = <String>[];
      final ops = ExplorerOps(
        state: state,
        pathLoadingService: loader,
        selectionController: selection,
        onPathChanged: null,
        notify: () => notifications.add('notify'),
      )..currentPath = '/workspace';

      await ops.searchCurrentPath('query');

      expect(state.searchQuery, 'query');
      expect(state.loading, isFalse);
      expect(state.error, isNull);
      expect(selection.selectedPaths, isEmpty);
      expect(state.entries.map((entry) => entry.name).toList(), ['beta', 'gamma.txt']);
      expect(loader.searchCalls, 1);
      expect(loader.lastSearchQuery, 'query');
      expect(loader.lastSearchInclude, '*.dart');
      expect(loader.lastSearchExclude, '*.g.dart');
      expect(loader.lastSearchMatchCase, isTrue);
      expect(loader.lastSearchMatchWholeWord, isTrue);
      expect(loader.lastSearchContents, isTrue);
      expect(notifications.length, greaterThanOrEqualTo(4));
    });

    test('empty search query reloads current path instead of running search', () async {
      final state = ExplorerState()..searchActive = true;
      final selection = ExplorerSelectionState(
        currentPath: '/workspace',
        joinPath: PathUtils.joinPath,
      );
      final loader = _FakePathLoadingService(
        loadPathResult: PathLoadResult.success(
          target: '/workspace',
          entries: [_entry('reloaded.txt')],
          allEntries: [_entry('reloaded.txt')],
        ),
      );
      final ops = ExplorerOps(
        state: state,
        pathLoadingService: loader,
        selectionController: selection,
        onPathChanged: null,
        notify: () {},
      )..currentPath = '/workspace';

      await ops.searchCurrentPath('   ');

      expect(loader.searchCalls, 0);
      expect(loader.loadCalls, 1);
      expect(state.entries.map((entry) => entry.name).toList(), ['reloaded.txt']);
    });

    test('prefetchPath populates history once and reports errors through callback', () async {
      final state = ExplorerState();
      final selection = ExplorerSelectionState(
        currentPath: '/',
        joinPath: PathUtils.joinPath,
      );
      final loader = _FakePathLoadingService(
        listPathEntries: [
          _entry('child', isDirectory: true),
          _entry('file.txt'),
        ],
      );
      final prefetched = <String>{};
      final notifications = <String>[];
      final ops = ExplorerOps(
        state: state,
        pathLoadingService: loader,
        selectionController: selection,
        onPathChanged: null,
        notify: () => notifications.add('notify'),
      );

      await ops.prefetchPath(
        '/prefetch',
        currentPath: '/',
        prefetchedPaths: prefetched,
      );
      await ops.prefetchPath(
        '/prefetch',
        currentPath: '/',
        prefetchedPaths: prefetched,
      );

      expect(loader.listCalls, 1);
      expect(prefetched, {'/prefetch'});
      expect(state.pathHistory.contains('/prefetch'), isTrue);
      expect(state.pathHistory.contains('/prefetch/child'), isTrue);
      expect(notifications.length, 1);

      Object? capturedError;
      String? errorPath;
      ops.onPrefetchError = (path, error, _) {
        errorPath = path;
        capturedError = error;
      };
      loader.listPathError = StateError('boom');

      await ops.prefetchPath(
        '/broken',
        currentPath: '/',
        prefetchedPaths: prefetched,
      );

      expect(errorPath, '/broken');
      expect(capturedError, isA<StateError>());
    });
  });
}

class _FakePathLoadingService extends PathLoadingService {
  _FakePathLoadingService({
    this.loadPathResult,
    this.searchPathResult,
    this.listPathEntries = const [],
    this.hydratedSessions = const {},
    this.onSearch,
  }) : super(
         shellService: const _FakeRemoteShellService(),
         host: const SshHost(
           name: 'test-host',
           hostname: 'localhost',
           port: 22,
           available: true,
         ),
         cache: RemoteEditorCache(),
         runShellWrapper: _runInline,
       );

  final PathLoadResult? loadPathResult;
  final PathSearchResult? searchPathResult;
  final List<RemoteFileEntry> listPathEntries;
  final Map<String, LocalFileSession> hydratedSessions;
  final void Function({
    void Function(RemoteFileEntry entry)? onEntry,
  })? onSearch;

  int loadCalls = 0;
  int searchCalls = 0;
  int listCalls = 0;
  String? lastHydrateBasePath;
  String? lastSearchQuery;
  String? lastSearchInclude;
  String? lastSearchExclude;
  bool lastSearchMatchCase = false;
  bool lastSearchMatchWholeWord = false;
  bool lastSearchContents = false;
  Object? listPathError;

  static Future<T> _runInline<T>(Future<T> Function() action) => action();

  @override
  Future<PathLoadResult> loadPath(
    String path,
    String currentPath, {
    bool forceReload = false,
    bool isLoading = false,
  }) async {
    loadCalls += 1;
    return loadPathResult ??
        PathLoadResult.success(
          target: path,
          entries: const [],
          allEntries: const [],
        );
  }

  @override
  Future<PathSearchResult> searchPath(
    String basePath,
    String query, {
    String? currentPath,
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
  }) async {
    searchCalls += 1;
    lastSearchQuery = query;
    lastSearchInclude = includePattern;
    lastSearchExclude = excludePattern;
    lastSearchMatchCase = matchCase;
    lastSearchMatchWholeWord = matchWholeWord;
    lastSearchContents = searchContents;
    onSearch?.call(onEntry: onEntry);
    return searchPathResult ??
        PathSearchResult.success(target: basePath, entries: const []);
  }

  @override
  Future<List<RemoteFileEntry>> listPath(
    String path, {
    String? currentPath,
  }) async {
    listCalls += 1;
    if (listPathError != null) {
      throw listPathError!;
    }
    return listPathEntries;
  }

  @override
  Future<Map<String, LocalFileSession>> hydrateCachedSessions(
    List<RemoteFileEntry> entries,
    String basePath,
  ) async {
    lastHydrateBasePath = basePath;
    return hydratedSessions;
  }
}

class _FakeRemoteShellService extends RemoteShellService {
  const _FakeRemoteShellService();

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

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();
}

RemoteFileEntry _entry(
  String name, {
  bool isDirectory = false,
}) {
  return RemoteFileEntry(
    name: name,
    isDirectory: isDirectory,
    sizeBytes: isDirectory ? 0 : 10,
    modified: DateTime(2024, 1, 1),
  );
}
