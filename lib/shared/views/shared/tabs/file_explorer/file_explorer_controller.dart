import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/ssh/remote_editor_cache.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'clipboard_operations_handler.dart';
import 'delete_operations_handler.dart';
import 'explorer_clipboard.dart';
import 'external_app_launcher.dart';
import 'file_editing_service.dart';
import 'file_entry_list.dart';
import 'file_operations_service.dart';
import 'path_loading_service.dart';
import 'path_utils.dart';
import 'selection_controller.dart';
import 'ssh_auth_handler.dart';

/// ChangeNotifier that centralizes File Explorer state and lifecycle wiring.
class FileExplorerController extends ChangeNotifier {
  FileExplorerController({
    required this.host,
    required this.explorerContext,
    required this.shellService,
    required this.trashManager,
    required this.promptMergeDialog,
    this.onOpenEditorTab,
  });

  final SshHost host;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;
  final ExplorerTrashManager trashManager;
  final Future<String?> Function({
    required String remotePath,
    required String local,
    required String remote,
  })
  promptMergeDialog;
  final Future<void> Function(String path, String initialContent)?
  onOpenEditorTab;

  final RemoteEditorCache cache = RemoteEditorCache();
  late final SelectionController selectionController;
  late final PathLoadingService _pathLoadingService;
  late final FileOperationsService fileOpsService;
  late final FileEditingService fileEditingService;
  late final DeleteOperationsHandler deleteHandler;
  late final ClipboardOperationsHandler clipboardHandler;
  late final SshAuthHandler _sshAuthHandler;

  late final VoidCallback _clipboardListener;
  late final VoidCallback _cutEventListener;
  late final VoidCallback _trashRestoreListener;

  final List<RemoteFileEntry> entries = [];
  final Map<String, LocalFileSession> localEdits = {};
  final Set<String> syncingPaths = {};
  final Set<String> refreshingPaths = {};
  final Set<String> pathHistory = {'/'};

  String currentPath = '/';
  bool loading = true;
  String? error;
  bool showBreadcrumbs = true;
  bool _initialized = false;

  Future<void> initialize(BuildContext context) async {
    _sshAuthHandler = SshAuthHandler(
      shellService: shellService,
      context: context,
      host: host,
    );
    selectionController = SelectionController(
      currentPath: currentPath,
      joinPath: PathUtils.joinPath,
    );
    _pathLoadingService = PathLoadingService(
      shellService: shellService,
      host: host,
      cache: cache,
      runShellWrapper: _runShell,
    );
    fileOpsService = FileOperationsService(
      shellService: shellService,
      host: host,
      trashManager: trashManager,
      runShellWrapper: _runShell,
      explorerContext: explorerContext,
    );
    fileEditingService = FileEditingService(
      shellService: shellService,
      host: host,
      cache: cache,
      runShellWrapper: _runShell,
      promptMergeDialog: promptMergeDialog,
      launchLocalApp: ExternalAppLauncher.launch,
      onOpenEditorTab: onOpenEditorTab,
    );
    deleteHandler = DeleteOperationsHandler(
      shellService: shellService,
      host: host,
      trashManager: trashManager,
      runShellWrapper: _runShell,
      explorerContext: explorerContext,
    );
    clipboardHandler = ClipboardOperationsHandler(
      host: host,
      currentPath: currentPath,
      explorerContext: explorerContext,
      shellService: shellService,
    );
    _clipboardListener = notifyListeners;
    _cutEventListener = () {
      final event = ExplorerClipboard.cutEvents.value;
      if (event == null) {
        return;
      }
      if (event.contextId != explorerContext.id) {
        return;
      }
      final parent = PathUtils.parentDirectory(event.remotePath);
      if (parent == currentPath) {
        unawaited(refreshCurrentPath());
      }
    };
    _trashRestoreListener = () {
      final event = trashManager.restoreEvents.value;
      if (event == null) {
        return;
      }
      if (event.contextId != explorerContext.id) {
        return;
      }
      if (event.directory == currentPath) {
        unawaited(refreshCurrentPath());
      }
    };
    ExplorerClipboard.listenable.addListener(_clipboardListener);
    ExplorerClipboard.cutEvents.addListener(_cutEventListener);
    trashManager.restoreEvents.addListener(_trashRestoreListener);
    _initialized = true;
    await _initializeExplorer();
  }

  Future<void> _initializeExplorer() async {
    final home = await _runShell(() => shellService.homeDirectory(host))
        .catchError((error) {
          if (error is CancelledExplorerOperation) {
            loading = false;
            error = 'Unlock cancelled';
            notifyListeners();
            return '';
          }
          throw error;
        });
    if (home.isEmpty) {
      return;
    }
    final initialPath = home.isNotEmpty ? home : '/';
    pathHistory
      ..clear()
      ..add(initialPath);
    await loadPath(initialPath);
  }

  Future<void> loadPath(String path, {bool forceReload = false}) async {
    final result = await _pathLoadingService.loadPath(
      path,
      currentPath,
      forceReload: forceReload,
      isLoading: loading,
    );
    if (result.skipped) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();

    if (result.error != null) {
      loading = false;
      error = result.error;
      notifyListeners();
      return;
    }
    if (result.entries == null) {
      return;
    }
    entries
      ..clear()
      ..addAll(result.entries!);
    currentPath = result.target;
    selectionController.currentPath = result.target;
    clipboardHandler.currentPath = result.target;
    loading = false;
    pathHistory.add(currentPath);
    selectionController.clearSelection();
    for (final entry in result.entries!) {
      if (entry.isDirectory && entry.name != '..') {
        pathHistory.add(PathUtils.joinPath(currentPath, entry.name));
      }
    }
    notifyListeners();

    if (result.allEntries != null) {
      final updates = await _pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        result.target,
      );
      if (updates.isNotEmpty) {
        localEdits.addAll(updates);
        notifyListeners();
      }
    }
  }

  Future<void> refreshCurrentPath() async {
    final result = await _pathLoadingService.refreshPath(currentPath, entries);
    if (result.skipped || result.entries == null) {
      return;
    }
    if (result.error != null) {
      return;
    }
    entries
      ..clear()
      ..addAll(result.entries!);
    for (final entry in result.entries!) {
      if (entry.isDirectory && entry.name != '..') {
        pathHistory.add(PathUtils.joinPath(currentPath, entry.name));
      }
    }
    notifyListeners();

    if (result.allEntries != null) {
      final updates = await _pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        currentPath,
      );
      if (updates.isNotEmpty) {
        localEdits.addAll(updates);
        notifyListeners();
      }
    }
  }

  List<RemoteFileEntry> currentSortedEntries() {
    final sorted = [...entries];
    sorted.sort((a, b) {
      if (a.isDirectory == b.isDirectory) {
        return a.name.compareTo(b.name);
      }
      return a.isDirectory ? -1 : 1;
    });
    return sorted;
  }

  Future<T> runShell<T>(Future<T> Function() action) => _runShell(action);

  Future<T> _runShell<T>(Future<T> Function() action) async {
    try {
      return await _sshAuthHandler.runShell(action);
    } on SshUnlockCancelled {
      throw const CancelledExplorerOperation();
    }
  }

  void markSyncing(String path, {required bool syncing}) {
    if (syncing) {
      syncingPaths.add(path);
    } else {
      syncingPaths.remove(path);
    }
    notifyListeners();
  }

  void markRefreshing(String path, {required bool refreshing}) {
    if (refreshing) {
      refreshingPaths.add(path);
    } else {
      refreshingPaths.remove(path);
    }
    notifyListeners();
  }

  void updateLocalEdit(LocalFileSession session) {
    localEdits[session.remotePath] = session;
    notifyListeners();
  }

  void removeLocalEdit(LocalFileSession session) {
    localEdits.remove(session.remotePath);
    syncingPaths.remove(session.remotePath);
    refreshingPaths.remove(session.remotePath);
    notifyListeners();
  }

  void setShowBreadcrumbs(bool value) {
    showBreadcrumbs = value;
    notifyListeners();
  }

  void markNeedsBuild() {
    notifyListeners();
  }

  @override
  void dispose() {
    if (_initialized) {
      ExplorerClipboard.listenable.removeListener(_clipboardListener);
      ExplorerClipboard.cutEvents.removeListener(_cutEventListener);
      trashManager.restoreEvents.removeListener(_trashRestoreListener);
      _sshAuthHandler.dispose();
    }
    super.dispose();
  }
}

class CancelledExplorerOperation implements Exception {
  const CancelledExplorerOperation();

  @override
  String toString() => 'CancelledExplorerOperation';
}
