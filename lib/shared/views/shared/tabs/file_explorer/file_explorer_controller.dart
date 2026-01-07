import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../models/app_settings.dart';
import '../../../../../services/ssh/remote_editor_cache.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'clipboard_operations_handler.dart';
import 'delete_operations_handler.dart';
import 'desktop_drag_source.dart';
import 'drag_types.dart';
import 'explorer_clipboard.dart';
import 'explorer_ops.dart';
import 'explorer_state.dart';
import 'explorer_ui_adapter.dart';
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
    required this.settingsController,
    required this.trashManager,
    required this.promptMergeDialog,
    this.initialPath,
    this.onPathChanged,
    this.onOpenEditorTab,
  });

  final SshHost host;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;
  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final String? initialPath;
  final ValueChanged<String>? onPathChanged;
  final Future<String?> Function({
    required String remotePath,
    required String local,
    required String remote,
  })
  promptMergeDialog;
  final Future<void> Function(String path, String initialContent)?
  onOpenEditorTab;

  final RemoteEditorCache cache = RemoteEditorCache();
  final ExplorerState state = ExplorerState();
  late final SelectionController selectionController;
  late final PathLoadingService _pathLoadingService;
  late final ExplorerOps _ops;
  late final FileOperationsService fileOpsService;
  late final FileEditingService fileEditingService;
  late final DeleteOperationsHandler deleteHandler;
  late final ClipboardOperationsHandler clipboardHandler;
  late final SshAuthHandler _sshAuthHandler;
  late final ExplorerUiAdapter _uiAdapter;
  final DesktopDragSource? dragSource = createDesktopDragSource();
  bool _osDragActive = false;
  String? _activeDragTempDir;
  String? _activeDragSourcePath;
  String? _lastDragTempDir;
  String? _lastDragSourcePath;
  DateTime? _lastDragExpiresAt;

  bool get isOsDragActive => _osDragActive;

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

  Future<void> initialize(BuildContext context) async {
    _settingsListener = () => _syncFromSettings(settingsController.settings);
    settingsController.addListener(_settingsListener);
    _syncFromSettings(settingsController.settings);
    _sshAuthHandler = SshAuthHandler(
      shellService: shellService,
      context: context,
      host: host,
    );
    _uiAdapter = ExplorerUiAdapter(context: context);
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
    _ops = ExplorerOps(
      state: state,
      pathLoadingService: _pathLoadingService,
      selectionController: selectionController,
      onPathChanged: onPathChanged,
      notify: notifyListeners,
    )..onPrefetchError = (path, error, stackTrace) {
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
      uiAdapter: _uiAdapter,
    );
    fileEditingService = FileEditingService(
      shellService: shellService,
      host: host,
      cache: cache,
      runShellWrapper: _runShell,
      promptMergeDialog: promptMergeDialog,
      launchLocalApp: ExternalAppLauncher.launch,
      uiAdapter: _uiAdapter,
      onOpenEditorTab: onOpenEditorTab,
    );
    deleteHandler = DeleteOperationsHandler(
      shellService: shellService,
      host: host,
      trashManager: trashManager,
      runShellWrapper: _runShell,
      explorerContext: explorerContext,
      uiAdapter: _uiAdapter,
    );
    clipboardHandler = ClipboardOperationsHandler(
      host: host,
      currentPath: currentPath,
      explorerContext: explorerContext,
      shellService: shellService,
      uiAdapter: _uiAdapter,
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
    } on SshUnlockCancelled {
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
  }) {
    final now = DateTime.now();
    final expiry = _lastDragExpiresAt;
    if (expiry != null && now.isAfter(expiry)) {
      _lastDragTempDir = null;
      _lastDragSourcePath = null;
      _lastDragExpiresAt = null;
    }
    final tempDir = _activeDragTempDir ?? _lastDragTempDir;
    final sourcePath = _activeDragSourcePath ?? _lastDragSourcePath;
    if (tempDir == null || sourcePath == null) {
      return false;
    }
    if (targetDirectory != sourcePath) {
      return false;
    }
    return paths.isNotEmpty &&
        paths.every((path) => p.isWithin(tempDir, path) || path == tempDir);
  }

  bool isSelfDragTarget(String targetDirectory) {
    final now = DateTime.now();
    final expiry = _lastDragExpiresAt;
    if (expiry != null && now.isAfter(expiry)) {
      _lastDragTempDir = null;
      _lastDragSourcePath = null;
      _lastDragExpiresAt = null;
    }
    final sourcePath = _activeDragSourcePath ?? _lastDragSourcePath;
    if (sourcePath == null) {
      return false;
    }
    return targetDirectory == sourcePath;
  }

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
    required BuildContext context,
    required Offset globalPosition,
    required List<RemoteFileEntry> entriesToDrag,
  }) async {
    final source = dragSource;
    if (source == null || !source.isSupported) {
      _uiAdapter.showDragNotSupported();
      return;
    }
    if (entriesToDrag.isEmpty) {
      _uiAdapter.showNothingToDrag();
      return;
    }
    _osDragActive = true;
    final tempDir = await Directory.systemTemp.createTemp('cwatch-drag-');
    _activeDragTempDir = tempDir.path;
    _activeDragSourcePath = currentPath;
    _lastDragTempDir = tempDir.path;
    _lastDragSourcePath = currentPath;
    _lastDragExpiresAt = DateTime.now().add(const Duration(minutes: 2));
    try {
      final staged = <DragLocalItem>[];
      final downloads = <RemotePathDownload>[];
      for (final entry in entriesToDrag) {
        final remotePath = PathUtils.joinPath(currentPath, entry.name);
        final localTarget = p.join(tempDir.path, entry.name);
        downloads.add(
          RemotePathDownload(
            remotePath: remotePath,
            localDestination: tempDir.path,
            recursive: entry.isDirectory,
          ),
        );
        staged.add(
          DragLocalItem(
            localPath: localTarget,
            displayName: entry.name,
            isDirectory: entry.isDirectory,
            remotePath: remotePath,
          ),
        );
      }
      await runShell(
        () => shellService.downloadPaths(
          host: host,
          downloads: downloads,
          onError: (download, error) {
            AppLogger().warn(
              'Failed to stage ${download.remotePath} for drag',
              tag: 'Explorer',
              error: error,
            );
          },
        ),
      );
      staged.removeWhere((item) {
        if (item.isDirectory) {
          return !Directory(item.localPath).existsSync();
        }
        return !File(item.localPath).existsSync();
      });
      if (staged.isEmpty) {
        _uiAdapter.showNothingToDrag();
        return;
      }
      if (!context.mounted) {
        return;
      }
      await source.startDrag(
        context: context,
        globalPosition: globalPosition,
        items: staged,
      );
      if (!context.mounted) {
        return;
      }
      _uiAdapter.showDragStarted();
    } finally {
      _osDragActive = false;
      _activeDragTempDir = null;
      _activeDragSourcePath = null;
      // Cleanup temp dir later.
      Future<void>.delayed(const Duration(minutes: 2), () async {
        try {
          await tempDir.delete(recursive: true);
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to delete temp drag directory ${tempDir.path}',
            tag: 'Explorer',
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (_lastDragTempDir == tempDir.path) {
          _lastDragTempDir = null;
          _lastDragSourcePath = null;
          _lastDragExpiresAt = null;
        }
      });
    }
  }
}

class CancelledExplorerOperation implements Exception {
  const CancelledExplorerOperation();

  @override
  String toString() => 'CancelledExplorerOperation';
}
