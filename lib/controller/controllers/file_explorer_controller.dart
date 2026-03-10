import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/desktop_drag_source.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/selection_controller.dart';
import '../adapters/clipboard_operations_handler.dart';
import '../adapters/delete_operations_handler.dart';
import '../adapters/explorer_os_drag_manager.dart';
import '../adapters/explorer_ui_adapter.dart';
import '../adapters/external_app_launcher.dart';
import '../adapters/file_operations_ui_handler.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'package:cwatch/model/services/explorer_ops.dart';
import 'package:cwatch/model/services/file_editing_service.dart';
import 'package:cwatch/model/services/file_operations_service.dart';
import 'package:cwatch/model/services/path_loading_service.dart';
import 'package:cwatch/model/services/ssh_auth_handler.dart';
import 'package:cwatch/model/shared/services/explorer_state.dart';

/// ChangeNotifier that centralizes File Explorer state and lifecycle wiring.
class FileExplorerController extends ChangeNotifier {
  FileExplorerController({
    required this.host,
    required this.explorerContext,
    required this.shellService,
    required this.settingsController,
    required this.trashManager,
    required this.uiAdapter,
    this.initialPath,
    this.onPathChanged,
    this.onOpenEditorTab,
  });

  final SshHost host;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;
  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final ExplorerUiAdapter uiAdapter;
  final String? initialPath;
  final ValueChanged<String>? onPathChanged;
  final Future<void> Function(String path, String initialContent)?
  onOpenEditorTab;

  final RemoteEditorCache cache = RemoteEditorCache();
  final ExplorerState state = ExplorerState();
  late final SelectionController selectionController;
  late final PathLoadingService _pathLoadingService;
  late final ExplorerOps _ops;
  late final FileOperationsService fileOpsService;
  late final FileOperationsUiHandler fileOpsUiHandler;
  late final FileEditingService fileEditingService;
  late final DeleteOperationsHandler deleteHandler;
  late final ClipboardOperationsHandler clipboardHandler;
  late final SshAuthHandler _sshAuthHandler;
  final DesktopDragSource? dragSource = createDesktopDragSource();
  late final ExplorerOsDragManager _osDragManager;

  bool get isOsDragActive => _osDragManager.isOsDragActive;

  late final VoidCallback _clipboardListener;
  late final VoidCallback _cutEventListener;
  late final VoidCallback _trashRestoreListener;

  final Set<String> _prefetchedPaths = {};
  String currentPath = '/';
  bool _initialized = false;
  late final VoidCallback _settingsListener;

  void setShowRowHeightControl(bool value) {
    if (state.showRowHeightControl == value) return;
    state.showRowHeightControl = value;
    notifyListeners();
  }

  void setShowBreadcrumbs(bool value) {
    if (state.showBreadcrumbs == value) return;
    state.showBreadcrumbs = value;
    settingsController.update(
      (current) => current.copyWith(explorerShowBreadcrumbs: value),
    );
    notifyListeners();
  }

  void setRowHeight(double value) {
    final next = _sanitizeRowHeight(value);
    if (state.rowHeight == next) return;
    state.rowHeight = next;
    settingsController.update(
      (current) => current.copyWith(explorerRowHeight: next),
    );
    notifyListeners();
  }

  void _syncFromSettings(AppSettings settings) {
    final nextRowHeight = _sanitizeRowHeight(settings.explorerRowHeight);
    final nextShowBreadcrumbs = settings.explorerShowBreadcrumbs;
    var changed = false;
    if (state.rowHeight != nextRowHeight) {
      state.rowHeight = nextRowHeight;
      changed = true;
    }
    if (state.showBreadcrumbs != nextShowBreadcrumbs) {
      state.showBreadcrumbs = nextShowBreadcrumbs;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  double _sanitizeRowHeight(double value) {
    if (value < 24) return 24;
    if (value > 88) return 88;
    return value;
  }

  Future<void> initialize() async {
    _settingsListener = () => _syncFromSettings(settingsController.settings);
    settingsController.addListener(_settingsListener);
    _syncFromSettings(settingsController.settings);
    _sshAuthHandler = SshAuthHandler(shellService: shellService);
    _osDragManager = ExplorerOsDragManager(
      host: host,
      shellService: shellService,
      uiAdapter: uiAdapter,
      runShell: _runShell,
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
    _ops =
        ExplorerOps(
            state: state,
            pathLoadingService: _pathLoadingService,
            selectionController: selectionController,
            onPathChanged: onPathChanged,
            notify: notifyListeners,
          )
          ..onPrefetchError = (path, error, stackTrace) {
            AppLogger().warn(
              'Failed to prefetch path $path',
              tag: 'Explorer',
              error: error,
              stackTrace: stackTrace,
            );
          };
    fileOpsService = FileOperationsService(
      shellService: shellService,
      host: host,
      settingsController: settingsController,
      trashManager: trashManager,
      runShellWrapper: _runShell,
      explorerContext: explorerContext,
    );
    fileOpsUiHandler = FileOperationsUiHandler(
      service: fileOpsService,
      uiAdapter: uiAdapter,
    );
    fileEditingService = FileEditingService(
      shellService: shellService,
      host: host,
      cache: cache,
      runShellWrapper: _runShell,
      promptMergeDialog: uiAdapter.showMergeConflictDialog,
      launchLocalApp: ExternalAppLauncher.launch,
      onMessage: uiAdapter.showSnackBar,
      onOpenEditorTab: onOpenEditorTab,
    );
    deleteHandler = DeleteOperationsHandler(
      shellService: shellService,
      host: host,
      trashManager: trashManager,
      runShellWrapper: _runShell,
      explorerContext: explorerContext,
      uiAdapter: uiAdapter,
    );
    clipboardHandler = ClipboardOperationsHandler(
      host: host,
      currentPath: currentPath,
      explorerContext: explorerContext,
      shellService: shellService,
      uiAdapter: uiAdapter,
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
    final startingPath = initialPath;
    final preferredPath = startingPath?.trim().isNotEmpty == true
        ? PathUtils.normalizePath(startingPath!)
        : null;
    final home = await _runShell(() => shellService.homeDirectory(host))
        .catchError((error) {
          if (error is CancelledExplorerOperation) {
            state.loading = false;
            state.error = 'Unlock cancelled';
            notifyListeners();
            return '';
          }
          throw error;
        });
    if (home.isEmpty && preferredPath == null) {
      return;
    }
    final targetPath = preferredPath ?? (home.isNotEmpty ? home : '/');
    state.pathHistory
      ..clear()
      ..add(targetPath);
    await loadPath(targetPath);
  }

  Future<void> loadPath(
    String path, {
    bool forceReload = false,
    bool keepSearchActive = false,
  }) async {
    _ops.currentPath = currentPath;
    await _ops.loadPath(
      path,
      currentPath: currentPath,
      forceReload: forceReload,
      keepSearchActive: keepSearchActive,
    );
    currentPath = _ops.currentPath;
    clipboardHandler.currentPath = currentPath;
  }

  Future<void> refreshCurrentPath() async {
    _ops.currentPath = currentPath;
    await _ops.refreshCurrentPath();
  }

  Future<void> setSearchActive(bool value) async {
    _ops.currentPath = currentPath;
    await _ops.setSearchActive(value);
  }

  Future<void> searchCurrentPath(String query) async {
    _ops.currentPath = currentPath;
    await _ops.searchCurrentPath(query);
  }

  void setSearchQuery(String query) {
    _ops.setSearchQuery(query);
  }

  void cancelSearch() {
    _ops.cancelSearch();
  }

  void setSearchInclude(String value) {
    _ops.setSearchInclude(value);
  }

  void setSearchExclude(String value) {
    _ops.setSearchExclude(value);
  }

  void toggleSearchMatchCase() {
    _ops.toggleSearchMatchCase();
  }

  void toggleSearchMatchWholeWord() {
    _ops.toggleSearchMatchWholeWord();
  }

  void setSearchContents(bool value) {
    _ops.setSearchContents(value);
  }

  List<RemoteFileEntry> currentSortedEntries() {
    return _ops.currentSortedEntries();
  }

  Future<T> runShell<T>(Future<T> Function() action) => _runShell(action);

  Future<T> _runShell<T>(Future<T> Function() action) async {
    try {
      return await _sshAuthHandler.runShell(action);
    } on SshDecryptCancelled {
      throw const CancelledExplorerOperation();
    }
  }

  void markSyncing(String path, {required bool syncing}) {
    if (syncing) {
      state.syncingPaths.add(path);
    } else {
      state.syncingPaths.remove(path);
    }
    notifyListeners();
  }

  void markRefreshing(String path, {required bool refreshing}) {
    if (refreshing) {
      state.refreshingPaths.add(path);
    } else {
      state.refreshingPaths.remove(path);
    }
    notifyListeners();
  }

  void updateLocalEdit(LocalFileSession session) {
    state.localEdits[session.remotePath] = session;
    notifyListeners();
  }

  void removeLocalEdit(LocalFileSession session) {
    state.localEdits.remove(session.remotePath);
    state.syncingPaths.remove(session.remotePath);
    state.refreshingPaths.remove(session.remotePath);
    notifyListeners();
  }

  void markNeedsBuild() {
    notifyListeners();
  }

  void prefetchPath(String path) {
    unawaited(_prefetchPath(path));
  }

  Future<void> _prefetchPath(String path) async {
    _ops.currentPath = currentPath;
    await _ops.prefetchPath(
      path,
      currentPath: currentPath,
      prefetchedPaths: _prefetchedPaths,
    );
  }

  bool isSelfDragDrop({
    required List<String> paths,
    required String targetDirectory,
  }) => _osDragManager.isSelfDragDrop(
    paths: paths,
    targetDirectory: targetDirectory,
  );

  bool isSelfDragTarget(String targetDirectory) =>
      _osDragManager.isSelfDragTarget(targetDirectory);

  @override
  void dispose() {
    if (_initialized) {
      settingsController.removeListener(_settingsListener);
      ExplorerClipboard.listenable.removeListener(_clipboardListener);
      ExplorerClipboard.cutEvents.removeListener(_cutEventListener);
      trashManager.restoreEvents.removeListener(_trashRestoreListener);
      _sshAuthHandler.dispose();
    }
    super.dispose();
  }

  Future<void> startOsDrag({
    required Offset globalPosition,
    required List<RemoteFileEntry> entriesToDrag,
  }) => _osDragManager.startOsDrag(
    dragSource: dragSource,
    globalPosition: globalPosition,
    entriesToDrag: entriesToDrag,
    currentPath: currentPath,
  );
}

class CancelledExplorerOperation implements Exception {
  const CancelledExplorerOperation();

  @override
  String toString() => 'CancelledExplorerOperation';
}
