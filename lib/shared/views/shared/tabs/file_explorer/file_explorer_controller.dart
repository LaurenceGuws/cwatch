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
import '../../../../../services/ssh/remote_editor_cache.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'clipboard_operations_handler.dart';
import 'delete_operations_handler.dart';
import 'desktop_drag_source.dart';
import 'drag_types.dart';
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
  late final SelectionController selectionController;
  late final PathLoadingService _pathLoadingService;
  late final FileOperationsService fileOpsService;
  late final FileEditingService fileEditingService;
  late final DeleteOperationsHandler deleteHandler;
  late final ClipboardOperationsHandler clipboardHandler;
  late final SshAuthHandler _sshAuthHandler;
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
      settingsController: settingsController,
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
    final startingPath = initialPath;
    final preferredPath = startingPath?.trim().isNotEmpty == true
        ? PathUtils.normalizePath(startingPath!)
        : null;
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
    if (home.isEmpty && preferredPath == null) {
      return;
    }
    final targetPath = preferredPath ?? (home.isNotEmpty ? home : '/');
    pathHistory
      ..clear()
      ..add(targetPath);
    await loadPath(targetPath);
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
    onPathChanged?.call(currentPath);
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drag-out not supported on this OS')),
        );
      }
      return;
    }
    if (entriesToDrag.isEmpty) {
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
            AppLogger.w(
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
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Nothing to drag')));
        }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drag started. Drop to copy/move.')),
      );
    } finally {
      _osDragActive = false;
      _activeDragTempDir = null;
      _activeDragSourcePath = null;
      // Cleanup temp dir later.
      Future<void>.delayed(const Duration(minutes: 2), () async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
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
