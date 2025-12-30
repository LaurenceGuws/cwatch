import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/remote_editor_cache.dart';
import 'path_utils.dart';
import 'file_entry_list.dart';

/// Service for handling path loading and refreshing
class PathLoadingService {
  PathLoadingService({
    required this.shellService,
    required this.host,
    required this.cache,
    required this.runShellWrapper,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final RemoteEditorCache cache;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;

  /// Load entries for a path
  Future<PathLoadResult> loadPath(
    String path,
    String currentPath, {
    bool forceReload = false,
    bool isLoading = false,
  }) async {
    final target = PathUtils.normalizePath(path, currentPath: currentPath);

    // Skip if already at this path and not loading, unless forced
    if (!forceReload && target == currentPath && !isLoading) {
      return PathLoadResult.skipped(target);
    }

    try {
      final entries = await runShellWrapper(
        () => shellService.listDirectory(host, target),
      );

      // Filter out "." and ".." entries from parsed output
      final filteredEntries = entries
          .where((e) => e.name != '.' && e.name != '..')
          .toList();

      // Add ".." entry at the beginning if not at root (for navigation)
      if (target != '/') {
        filteredEntries.insert(
          0,
          RemoteFileEntry(
            name: '..',
            isDirectory: true,
            sizeBytes: 0,
            modified: DateTime.now(),
          ),
        );
      }

      return PathLoadResult.success(
        target: target,
        entries: filteredEntries,
        allEntries: entries,
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to load path $target',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      return PathLoadResult.error(target: target, error: error.toString());
    }
  }

  Future<List<RemoteFileEntry>> listPath(
    String path, {
    String? currentPath,
  }) async {
    final target = PathUtils.normalizePath(path, currentPath: currentPath);
    final entries =
        await runShellWrapper(() => shellService.listDirectory(host, target));
    return entries.where((e) => e.name != '.' && e.name != '..').toList();
  }

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
    final target = PathUtils.normalizePath(basePath, currentPath: currentPath);
    try {
      final entries = await runShellWrapper(
        () => shellService.searchPaths(
          host,
          target,
          query,
          includePattern: includePattern,
          excludePattern: excludePattern,
          matchCase: matchCase,
          matchWholeWord: matchWholeWord,
          searchContents: searchContents,
          onEntry: onEntry,
          cancellation: cancellation,
        ),
      );
      final hitNames =
          entries.map((entry) => entry.name).take(50).join(', ');
      AppLogger.d(
        'Search hits (${entries.length}) base="$target" query="$query" '
        'include="${includePattern ?? ''}" exclude="${excludePattern ?? ''}" '
        'contents=$searchContents: $hitNames',
        tag: 'ExplorerSearch',
      );
      return PathSearchResult.success(target: target, entries: entries);
    } catch (error) {
      AppLogger.w(
        'Search failed base="$target" query="$query": $error',
        tag: 'ExplorerSearch',
        error: error,
      );
      return PathSearchResult.error(target: target, error: error.toString());
    }
  }

  /// Refresh entries for current path (soft refresh)
  Future<PathRefreshResult> refreshPath(
    String currentPath,
    List<RemoteFileEntry> currentEntries,
  ) async {
    if (currentPath.isEmpty) {
      return PathRefreshResult.skipped();
    }

    try {
      final entries = await runShellWrapper(
        () => shellService.listDirectory(host, currentPath),
      );

      // Filter out "." and ".." entries from parsed output
      final filteredEntries = entries
          .where((e) => e.name != '.' && e.name != '..')
          .toList();

      // Add ".." entry at the beginning if not at root (for navigation)
      if (currentPath != '/') {
        filteredEntries.insert(
          0,
          RemoteFileEntry(
            name: '..',
            isDirectory: true,
            sizeBytes: 0,
            modified: DateTime.now(),
          ),
        );
      }

      return PathRefreshResult.success(
        entries: filteredEntries,
        allEntries: entries,
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to refresh path $currentPath',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      return PathRefreshResult.error(error: error.toString());
    }
  }

  /// Hydrate cached sessions for entries
  Future<Map<String, LocalFileSession>> hydrateCachedSessions(
    List<RemoteFileEntry> entries,
    String basePath,
  ) async {
    final updates = <String, LocalFileSession>{};
    for (final entry in entries) {
      if (entry.isDirectory) {
        continue;
      }
      final remotePath = PathUtils.joinWithBase(basePath, entry.name);
      final session = await cache.loadSession(
        host: host.name,
        remotePath: remotePath,
      );
      if (session != null) {
        updates[remotePath] = LocalFileSession(
          localPath: session.workingPath,
          snapshotPath: session.snapshotPath,
          remotePath: remotePath,
        );
      }
    }
    return updates;
  }
}

class PathLoadResult {
  PathLoadResult.success({
    required this.target,
    required this.entries,
    required this.allEntries,
  }) : error = null,
       skipped = false;

  PathLoadResult.error({required this.target, required this.error})
    : entries = null,
      allEntries = null,
      skipped = false;

  PathLoadResult.skipped(this.target)
    : entries = null,
      allEntries = null,
      error = null,
      skipped = true;

  final String target;
  final List<RemoteFileEntry>? entries;
  final List<RemoteFileEntry>? allEntries;
  final String? error;
  final bool skipped;
}

class PathRefreshResult {
  PathRefreshResult.success({required this.entries, required this.allEntries})
    : error = null,
      skipped = false;

  PathRefreshResult.error({required this.error})
    : entries = null,
      allEntries = null,
      skipped = false;

  PathRefreshResult.skipped()
    : entries = null,
      allEntries = null,
      error = null,
      skipped = true;

  final List<RemoteFileEntry>? entries;
  final List<RemoteFileEntry>? allEntries;
  final String? error;
  final bool skipped;
}

class PathSearchResult {
  PathSearchResult.success({required this.target, required this.entries})
    : error = null;

  PathSearchResult.error({required this.target, required this.error})
    : entries = null;

  final String target;
  final List<RemoteFileEntry>? entries;
  final String? error;
}
