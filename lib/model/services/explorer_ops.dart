import 'dart:async';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/model/shared/services/explorer_state.dart';
import 'path_loading_service.dart';

class ExplorerOps {
  ExplorerOps({
    required this.state,
    required this.pathLoadingService,
    required this.selectionController,
    required this.onPathChanged,
    required this.notify,
  });

  final ExplorerState state;
  final PathLoadingService pathLoadingService;
  final ExplorerSelectionState selectionController;
  final void Function(String)? onPathChanged;
  final void Function() notify;

  String currentPath = '/';

  Future<void> loadPath(
    String path, {
    required String currentPath,
    required bool forceReload,
    required bool keepSearchActive,
  }) async {
    if (state.searchActive && !keepSearchActive) {
      state.searchActive = false;
      state.searchQuery = '';
    }
    final result = await pathLoadingService.loadPath(
      path,
      currentPath,
      forceReload: forceReload,
      isLoading: state.loading,
    );
    if (result.skipped) {
      return;
    }
    state.loading = true;
    state.error = null;
    notify();

    if (result.error != null) {
      state.loading = false;
      state.error = result.error;
      notify();
      return;
    }
    if (result.entries == null) {
      return;
    }
    state.entries
      ..clear()
      ..addAll(result.entries!);
    this.currentPath = result.target;
    selectionController.currentPath = result.target;
    state.loading = false;
    state.pathHistory.add(this.currentPath);
    selectionController.clearSelection();
    for (final entry in result.entries!) {
      if (entry.isDirectory && entry.name != '.' && entry.name != '..') {
        state.pathHistory.add(PathUtils.joinPath(this.currentPath, entry.name));
      }
    }
    onPathChanged?.call(this.currentPath);
    notify();

    if (result.allEntries != null) {
      final updates = await pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        result.target,
      );
      if (updates.isNotEmpty) {
        state.localEdits.addAll(updates);
        notify();
      }
    }
  }

  Future<void> refreshCurrentPath() async {
    final result = await pathLoadingService.refreshPath(
      currentPath,
      state.entries,
    );
    if (result.skipped || result.entries == null) {
      return;
    }
    if (result.error != null) {
      return;
    }
    state.entries
      ..clear()
      ..addAll(result.entries!);
    for (final entry in result.entries!) {
      if (entry.isDirectory && entry.name != '.' && entry.name != '..') {
        state.pathHistory.add(PathUtils.joinPath(currentPath, entry.name));
      }
    }
    notify();

    if (result.allEntries != null) {
      final updates = await pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        currentPath,
      );
      if (updates.isNotEmpty) {
        state.localEdits.addAll(updates);
        notify();
      }
    }
  }

  Future<void> setSearchActive(bool value) async {
    if (state.searchActive == value) {
      return;
    }
    state.searchActive = value;
    state.searchQuery = '';
    if (!state.searchActive) {
      state.searchContents = false;
    }
    if (!state.searchActive) {
      await loadPath(
        currentPath,
        currentPath: currentPath,
        forceReload: true,
        keepSearchActive: true,
      );
      return;
    }
    notify();
  }

  Future<void> searchCurrentPath(String query) async {
    if (!state.searchActive) {
      return;
    }
    state.searchQuery = query;
    if (query.trim().isEmpty) {
      await loadPath(
        currentPath,
        currentPath: currentPath,
        forceReload: true,
        keepSearchActive: true,
      );
      return;
    }
    state.searchCancellation?.cancel();
    state.searchCancellation = RemoteCommandCancellation();
    state.loading = true;
    state.error = null;
    state.entries.clear();
    selectionController.clearSelection();
    notify();

    final generation = ++state.searchGeneration;
    final streamedKeys = <String>{};
    void handleEntry(RemoteFileEntry entry) {
      if (generation != state.searchGeneration) {
        return;
      }
      final key = '${entry.isDirectory ? 'd' : 'f'}:${entry.name}';
      if (!streamedKeys.add(key)) {
        return;
      }
      state.entries.add(entry);
      notify();
    }

    final result = await pathLoadingService.searchPath(
      currentPath,
      query,
      currentPath: currentPath,
      includePattern: state.searchInclude,
      excludePattern: state.searchExclude,
      matchCase: state.searchMatchCase,
      matchWholeWord: state.searchMatchWholeWord,
      searchContents: state.searchContents,
      onEntry: handleEntry,
      cancellation: state.searchCancellation,
    );
    if (generation != state.searchGeneration) {
      return;
    }
    state.searchCancellation = null;
    if (result.error != null) {
      state.loading = false;
      state.error = result.error;
      notify();
      return;
    }
    if (result.entries == null) {
      return;
    }
    state.entries
      ..clear()
      ..addAll(result.entries!);
    state.loading = false;
    notify();
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) {
      return;
    }
    state.searchQuery = query;
    notify();
  }

  void cancelSearch() {
    if (!state.loading) {
      return;
    }
    state.searchCancellation?.cancel();
    state.searchCancellation = null;
    state.searchGeneration++;
    state.loading = false;
    state.error = null;
    notify();
  }

  void setSearchInclude(String value) {
    if (state.searchInclude == value) {
      return;
    }
    state.searchInclude = value;
    notify();
  }

  void setSearchExclude(String value) {
    if (state.searchExclude == value) {
      return;
    }
    state.searchExclude = value;
    notify();
  }

  void toggleSearchMatchCase() {
    state.searchMatchCase = !state.searchMatchCase;
    notify();
  }

  void toggleSearchMatchWholeWord() {
    state.searchMatchWholeWord = !state.searchMatchWholeWord;
    notify();
  }

  void setSearchContents(bool value) {
    if (state.searchContents == value) {
      return;
    }
    state.searchContents = value;
    notify();
  }

  List<RemoteFileEntry> currentSortedEntries() {
    final sorted = [...state.entries];
    sorted.sort((a, b) {
      if (a.isDirectory == b.isDirectory) {
        return a.name.compareTo(b.name);
      }
      return a.isDirectory ? -1 : 1;
    });
    return sorted;
  }

  Future<void> prefetchPath(
    String path, {
    required String currentPath,
    required Set<String> prefetchedPaths,
  }) async {
    if (path.trim().isEmpty) {
      return;
    }
    final target = PathUtils.normalizePath(path, currentPath: currentPath);
    if (prefetchedPaths.contains(target)) {
      return;
    }
    prefetchedPaths.add(target);
    try {
      final entries = await pathLoadingService.listPath(
        target,
        currentPath: currentPath,
      );
      state.pathHistory.add(target);
      for (final entry in entries) {
        if (entry.isDirectory && entry.name != '.' && entry.name != '..') {
          state.pathHistory.add(PathUtils.joinPath(target, entry.name));
        }
      }
      notify();
    } catch (error, stackTrace) {
      onPrefetchError?.call(path, error, stackTrace);
    }
  }

  void Function(String path, Object error, StackTrace stackTrace)?
  onPrefetchError;
}
