import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/remote_file_entry.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/logging/app_logger.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../../services/ssh/remote_editor_cache.dart';
import '../../../../services/filesystem/explorer_trash_manager.dart';
import 'explorer_clipboard.dart';
import 'merge_conflict_dialog.dart';
import 'file_explorer/path_navigator.dart';
import 'file_explorer/command_bar.dart';
import 'file_explorer/ssh_auth_handler.dart';
import 'file_explorer/file_operations_service.dart';
import 'file_explorer/file_entry_list.dart';
import 'file_explorer/context_menu_builder.dart';
import 'file_explorer/path_utils.dart';
import 'file_explorer/file_editing_service.dart';
import 'file_explorer/selection_controller.dart';
import 'file_explorer/path_loading_service.dart';
import 'file_explorer/delete_operations_handler.dart';
import 'file_explorer/clipboard_operations_handler.dart';
import 'file_explorer/external_app_launcher.dart';
import 'file_explorer/dialog_builders.dart';
import '../servers/servers_widgets.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({
    super.key,
    required this.host,
    this.shellService = const ProcessRemoteShellService(),
    required this.trashManager,
    this.builtInVault,
    required this.onOpenTrash,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final ExplorerTrashManager trashManager;
  final BuiltInSshVault? builtInVault;
  final VoidCallback onOpenTrash;

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab> {

  final List<RemoteFileEntry> _entries = [];
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final ScrollController _scrollController = ScrollController();
  final RemoteEditorCache _cache = RemoteEditorCache();
  final Map<String, LocalFileSession> _localEdits = {};
  final Set<String> _syncingPaths = {};
  final Set<String> _refreshingPaths = {};
  Set<String> _pathHistory = {'/'};
  TextEditingController? _pathFieldController;
  late final VoidCallback _clipboardListener;
  late SshAuthHandler _sshAuthHandler;
  late FileOperationsService _fileOpsService;
  late FileEditingService _fileEditingService;
  late final SelectionController _selectionController;
  late PathLoadingService _pathLoadingService;
  late DeleteOperationsHandler _deleteHandler;
  late ClipboardOperationsHandler _clipboardHandler;
  late final VoidCallback _cutEventListener;
  late final VoidCallback _trashRestoreListener;

  String _currentPath = '/';
  bool _loading = true;
  String? _error;
  bool _showBreadcrumbs = true;

  @override
  void initState() {
    super.initState();
    _sshAuthHandler = SshAuthHandler(
      shellService: widget.shellService,
      builtInVault: widget.builtInVault,
      context: context,
      host: widget.host,
    );
    _fileOpsService = FileOperationsService(
      shellService: widget.shellService,
      host: widget.host,
      trashManager: widget.trashManager,
      runShellWrapper: _runShell,
    );
    _fileEditingService = FileEditingService(
      shellService: widget.shellService,
      host: widget.host,
      cache: _cache,
      runShellWrapper: _runShell,
      promptMergeDialog: _promptMergeDialog,
      launchLocalApp: ExternalAppLauncher.launch,
    );
    _selectionController = SelectionController(
      currentPath: _currentPath,
      joinPath: PathUtils.joinPath,
    );
    _pathLoadingService = PathLoadingService(
      shellService: widget.shellService,
      host: widget.host,
      cache: _cache,
      runShellWrapper: _runShell,
    );
    _deleteHandler = DeleteOperationsHandler(
      shellService: widget.shellService,
      host: widget.host,
      trashManager: widget.trashManager,
      runShellWrapper: _runShell,
    );
    _clipboardHandler = ClipboardOperationsHandler(
      host: widget.host,
      currentPath: _currentPath,
    );
    _initializeExplorer();
    _clipboardListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    ExplorerClipboard.listenable.addListener(_clipboardListener);
    _cutEventListener = () {
      final event = ExplorerClipboard.cutEvents.value;
      if (event == null || !mounted) {
        return;
      }
      if (event.hostName != widget.host.name) {
        return;
      }
      final parent = PathUtils.parentDirectory(event.remotePath);
      if (parent == _currentPath) {
        unawaited(_refreshCurrentPath());
      }
    };
    ExplorerClipboard.cutEvents.addListener(_cutEventListener);
    _trashRestoreListener = () {
      final event = widget.trashManager.restoreEvents.value;
      if (event == null || !mounted) {
        return;
      }
      if (event.hostName != widget.host.name) {
        return;
      }
      if (event.directory == _currentPath) {
        unawaited(_refreshCurrentPath());
      }
    };
    widget.trashManager.restoreEvents.addListener(_trashRestoreListener);
  }

  @override
  void didUpdateWidget(covariant FileExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shellService != widget.shellService) {
      _sshAuthHandler = SshAuthHandler(
        shellService: widget.shellService,
        builtInVault: widget.builtInVault,
        context: context,
        host: widget.host,
      );
      _fileOpsService = FileOperationsService(
        shellService: widget.shellService,
        host: widget.host,
        trashManager: widget.trashManager,
        runShellWrapper: _runShell,
      );
      _fileEditingService = FileEditingService(
        shellService: widget.shellService,
        host: widget.host,
        cache: _cache,
        runShellWrapper: _runShell,
        promptMergeDialog: _promptMergeDialog,
        launchLocalApp: ExternalAppLauncher.launch,
      );
      _pathLoadingService = PathLoadingService(
        shellService: widget.shellService,
        host: widget.host,
        cache: _cache,
        runShellWrapper: _runShell,
      );
      _deleteHandler = DeleteOperationsHandler(
        shellService: widget.shellService,
        host: widget.host,
        trashManager: widget.trashManager,
        runShellWrapper: _runShell,
      );
    }
  }

  Future<void> _initializeExplorer() async {
    final home = await _runShell(
      () => widget.shellService.homeDirectory(widget.host),
    ).catchError((error) {
      if (error is CancelledExplorerOperation) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return '';
      }
      throw error;
    });
    if (home.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unlock cancelled';
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final initialPath = home.isNotEmpty ? home : '/';
    _pathHistory = {initialPath};
    await _loadPath(initialPath);
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    _scrollController.dispose();
    ExplorerClipboard.listenable.removeListener(_clipboardListener);
    ExplorerClipboard.cutEvents.removeListener(_cutEventListener);
    widget.trashManager.restoreEvents.removeListener(_trashRestoreListener);
    _sshAuthHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPathHeader(context),
        const SizedBox(height: 12),
        _buildCommandBar(),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _buildEntriesList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPathNavigator(BuildContext context) {
    return PathNavigator(
      currentPath: _currentPath,
      pathHistory: _pathHistory,
      onPathChanged: (path) => _loadPath(path),
      showBreadcrumbs: _showBreadcrumbs,
      onShowBreadcrumbsChanged: (show) {
        setState(() => _showBreadcrumbs = show);
      },
      onNavigateToSubdirectory: () => _showNavigateToSubdirectoryDialog(),
    );
  }

  Widget _buildPathHeader(BuildContext context) {
    final navigator = _buildPathNavigator(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: navigator),
        const SizedBox(width: 8),
        ServersMenu(
          onOpenTrash: widget.onOpenTrash,
          onUploadFiles: () => _handleUploadFiles(_currentPath),
          onUploadFolder: () => _handleUploadFolder(_currentPath),
        ),
      ],
    );
  }

  Widget _buildCommandBar() {
    return CommandBar(
      hostName: widget.host.name,
      onCommandSubmitted: (command) {
        _runAdHocCommand(command);
      },
    );
  }

  Widget _buildEntriesList() {
    final sortedEntries = _currentSortedEntries();
    return FileEntryList(
      entries: sortedEntries,
      currentPath: _currentPath,
      selectedPaths: _selectionController.selectedPaths,
      syncingPaths: _syncingPaths,
      refreshingPaths: _refreshingPaths,
      localEdits: _localEdits,
      scrollController: _scrollController,
      focusNode: _listFocusNode,
      onEntryDoubleTap: _handleEntryDoubleTap,
      onEntryPointerDown: (event, entries, index, remotePath) {
        _selectionController.handleEntryPointerDown(
          event,
          entries,
          index,
          remotePath,
          () => _listFocusNode.requestFocus(),
          () => setState(() {}),
        );
      },
      onDragHover: (event, index, remotePath) {
        _selectionController.handleDragHover(
          event,
          index,
          remotePath,
          () => setState(() {}),
        );
      },
      onStopDragSelection: () => _selectionController.stopDragSelection(),
      onEntryContextMenu: _showEntryContextMenu,
      onBackgroundContextMenu: null,
      onKeyEvent: (node, event, entries) {
        return _selectionController.handleListKeyEvent(
          node,
          event,
          entries,
          () => setState(() {}),
          () {
            final selectedEntries = _selectionController.getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(_handleMultiCopy(selectedEntries));
              } else {
                _handleClipboardSet(selectedEntries.first, ExplorerClipboardOperation.copy);
              }
            }
          },
          () {
            final selectedEntries = _selectionController.getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(_handleMultiCut(selectedEntries));
              } else {
                _handleClipboardSet(selectedEntries.first, ExplorerClipboardOperation.cut);
              }
            }
          },
          () => _handlePaste(targetDirectory: _currentPath),
          () {
            final selectedEntries = _selectionController.getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(_confirmMultiDelete(selectedEntries, permanent: SelectionController.isShiftPressed()));
              } else {
                unawaited(_confirmDelete(selectedEntries.first, permanent: SelectionController.isShiftPressed()));
              }
            }
          },
          () {
            final entry = _selectionController.primarySelectedEntry(entries);
            if (entry != null) {
              unawaited(_promptRename(entry));
            }
          },
        );
      },
      onSyncLocalEdit: _syncLocalEdit,
      onRefreshCacheFromServer: _refreshCacheFromServer,
      onClearCachedCopy: _clearCachedCopy,
      joinPath: PathUtils.joinPath,
    );
  }

  Future<void> _loadPath(String path, {bool forceReload = false}) async {
    final result = await _pathLoadingService.loadPath(
      path,
      _currentPath,
      forceReload: forceReload,
      isLoading: _loading,
    );
    
    if (result.skipped) {
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    if (result.error != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = result.error;
      });
      return;
    }
    
    if (result.entries == null) {
      return;
    }
    
    setState(() {
      _entries
        ..clear()
        ..addAll(result.entries!);
      _currentPath = result.target;
      _selectionController.currentPath = result.target;
      _clipboardHandler.currentPath = result.target;
      _pathFieldController?.text = _currentPath;
      _loading = false;
      _pathHistory.add(_currentPath);
      _selectionController.clearSelection();
      for (final entry in result.entries!) {
        if (entry.isDirectory && entry.name != '..') {
          _pathHistory.add(PathUtils.joinPath(_currentPath, entry.name));
        }
      }
    });
    
    if (result.allEntries != null) {
      final updates = await _pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        result.target,
      );
      if (updates.isNotEmpty && mounted) {
        setState(() {
          _localEdits.addAll(updates);
        });
      }
    }
  }

  /// Soft refresh: reloads entries without resetting scroll position or selection
  Future<void> _refreshCurrentPath() async {
    final result = await _pathLoadingService.refreshPath(_currentPath, _entries);
    
    if (result.skipped || result.entries == null) {
      return;
    }
    
    if (result.error != null) {
      AppLogger.w(
        'Failed to refresh current path',
        tag: 'Explorer',
        error: result.error,
      );
      return;
    }
    
    // Preserve scroll position
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    
    setState(() {
      _entries
        ..clear()
        ..addAll(result.entries!);
      // Update path history for new directories
      for (final entry in result.entries!) {
        if (entry.isDirectory && entry.name != '..') {
          _pathHistory.add(PathUtils.joinPath(_currentPath, entry.name));
        }
      }
    });
    
    // Restore scroll position after rebuild
    if (_scrollController.hasClients && scrollOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(scrollOffset);
        }
      });
    }
    
    if (result.allEntries != null) {
      final updates = await _pathLoadingService.hydrateCachedSessions(
        result.allEntries!,
        _currentPath,
      );
      if (updates.isNotEmpty && mounted) {
        setState(() {
          _localEdits.addAll(updates);
        });
      }
    }
  }

  void _runAdHocCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final parts = trimmed.split(' ');
    if (parts.first == 'cd' && parts.length > 1) {
      _loadPath(parts[1]);
    } else if (parts.first == 'ls') {
      _loadPath(parts.length > 1 ? parts[1] : _currentPath);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Executed: $trimmed')));
  }

  Future<void> _showEntryContextMenu(
    RemoteFileEntry entry,
    Offset position,
  ) async {
    final sortedEntries = _currentSortedEntries();
    final selectedEntries = _selectionController.getSelectedEntries(sortedEntries);
    final builder = ContextMenuBuilder(
      hostName: widget.host.name,
      currentPath: _currentPath,
      selectedEntries: selectedEntries,
      clipboardAvailable: ExplorerClipboard.hasEntries,
      onOpen: (e) => _loadPath(PathUtils.joinPath(_currentPath, e.name)),
      onCopyPath: (e) async {
        final path = PathUtils.joinPath(_currentPath, e.name);
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied $path')),
          );
        }
      },
      onOpenLocally: _openLocally,
      onEditFile: _openEditor,
      onRename: _promptRename,
      onCopy: (entries) async {
        if (entries.length > 1) {
          await _handleMultiCopy(entries);
        } else {
          _handleClipboardSet(entries.first, ExplorerClipboardOperation.copy);
        }
      },
      onCut: (entries) async {
        if (entries.length > 1) {
          await _handleMultiCut(entries);
        } else {
          _handleClipboardSet(entries.first, ExplorerClipboardOperation.cut);
        }
      },
      onPaste: () => _handlePaste(targetDirectory: _currentPath),
      onPasteInto: (e) => _handlePaste(
        targetDirectory: PathUtils.joinPath(_currentPath, e.name),
      ),
      onMove: _promptMove,
      onDelete: (entries) async {
        if (entries.length > 1) {
          await _confirmMultiDelete(entries, permanent: SelectionController.isShiftPressed());
        } else {
          await _confirmDelete(entries.first, permanent: SelectionController.isShiftPressed());
        }
      },
      onDownload: _handleDownload,
      onUploadFiles: _handleUploadFiles,
      onUploadFolder: _handleUploadFolder,
      joinPath: PathUtils.joinPath,
    );

    final menuItems = builder.buildEntryMenuItems(entry);
    final action = await showMenu<ExplorerContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: menuItems,
    );

    if (!mounted) {
      return;
    }

    await builder.handleAction(context, action, entry);
  }

  void _handleEntryDoubleTap(RemoteFileEntry entry) {
    final targetPath = PathUtils.joinPath(_currentPath, entry.name);
    if (entry.isDirectory) {
      _loadPath(targetPath);
    } else {
      unawaited(_openLocally(entry));
    }
  }

  Future<void> _openEditor(RemoteFileEntry entry) async {
    await _fileEditingService.openEditor(context, entry, _currentPath);
  }

  Future<void> _openLocally(RemoteFileEntry entry) async {
    final session = await _fileEditingService.openLocally(context, entry, _currentPath);
    if (session != null && mounted) {
      setState(() {
        _localEdits[session.remotePath] = session;
      });
    }
  }

  Future<void> _syncLocalEdit(LocalFileSession session) async {
    setState(() {
      _syncingPaths.add(session.remotePath);
    });
    await _fileEditingService.syncLocalEdit(
      context,
      session,
      (s) {
        if (mounted) {
          setState(() {
            _localEdits[s.remotePath] = s;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        _syncingPaths.remove(session.remotePath);
      });
    }
  }

  Future<T> _runShell<T>(Future<T> Function() action) async {
    try {
      return await _sshAuthHandler.runShell(action);
    } on SshUnlockCancelled {
      throw const CancelledExplorerOperation();
    }
  }

  Future<void> _refreshCacheFromServer(LocalFileSession session) async {
    setState(() {
      _refreshingPaths.add(session.remotePath);
    });
    await _fileEditingService.refreshCacheFromServer(context, session);
    if (mounted) {
      setState(() {
        _refreshingPaths.remove(session.remotePath);
      });
    }
  }

  Future<void> _clearCachedCopy(LocalFileSession session) async {
    await _fileEditingService.clearCachedCopy(context, session);
    if (mounted) {
      setState(() {
        _localEdits.remove(session.remotePath);
        _syncingPaths.remove(session.remotePath);
        _refreshingPaths.remove(session.remotePath);
      });
    }
  }

  void _handleClipboardSet(
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    _clipboardHandler.setClipboardEntry(context, entry, operation);
  }

  Future<void> _promptRename(RemoteFileEntry entry) async {
    final newName = await DialogBuilders.showRenameDialog(context, entry);
    if (newName == null) {
      return;
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == entry.name) {
      return;
    }
    final sourcePath = PathUtils.joinPath(_currentPath, entry.name);
    final destinationPath = PathUtils.joinPath(_currentPath, trimmed);
    try {
      await _runShell(
        () => widget.shellService.movePath(
          widget.host,
          sourcePath,
          destinationPath,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed ${entry.name} to $trimmed')),
      );
    } catch (error) {
      if (error is CancelledExplorerOperation) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $error')),
      );
    }
  }

  Future<void> _promptMove(RemoteFileEntry entry) async {
    final target = await DialogBuilders.showMoveDialog(context, entry, _currentPath);
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final normalized = PathUtils.normalizePath(target, currentPath: _currentPath);
    if (normalized == PathUtils.joinPath(_currentPath, entry.name)) {
      return;
    }
    try {
      await _runShell(
        () => widget.shellService.movePath(
          widget.host,
          PathUtils.joinPath(_currentPath, entry.name),
          normalized,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${entry.name} to $normalized')),
      );
    } catch (error) {
      if (error is CancelledExplorerOperation) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move: $error')),
      );
    }
  }

  Future<void> _confirmDelete(
    RemoteFileEntry entry, {
    bool permanent = false,
  }) async {
    final deletePermanently = permanent || SelectionController.isShiftPressed();
    final confirmed = await DialogBuilders.showDeleteDialog(
      context,
      entry,
      widget.host,
      deletePermanently,
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (deletePermanently) {
      await _deleteHandler.deletePermanently(
        context,
        entry,
        _currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _deleteHandler.moveToTrash(
        context,
        entry,
        _currentPath,
        _refreshCurrentPath,
      );
    }
  }


  Future<void> _handlePaste({required String targetDirectory}) async {
    await _fileOpsService.handlePaste(
      context: context,
      targetDirectory: targetDirectory,
      currentPath: _currentPath,
      joinPath: PathUtils.joinPath,
      normalizePath: (path) => PathUtils.normalizePath(path, currentPath: _currentPath),
      refreshCurrentPath: _refreshCurrentPath,
    );
  }




  List<RemoteFileEntry> _currentSortedEntries() {
    final sorted = [..._entries];
    sorted.sort((a, b) {
      if (a.isDirectory == b.isDirectory) {
        return a.name.compareTo(b.name);
      }
      return a.isDirectory ? -1 : 1;
    });
    return sorted;
  }




  Future<void> _handleMultiCopy(List<RemoteFileEntry> entries) async {
    _clipboardHandler.setClipboardEntries(context, entries, ExplorerClipboardOperation.copy);
  }

  Future<void> _handleMultiCut(List<RemoteFileEntry> entries) async {
    _clipboardHandler.setClipboardEntries(context, entries, ExplorerClipboardOperation.cut);
  }

  Future<void> _confirmMultiDelete(
    List<RemoteFileEntry> entries, {
    bool permanent = false,
  }) async {
    if (entries.isEmpty) {
      return;
    }
    final deletePermanently = permanent || SelectionController.isShiftPressed();
    final count = entries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          deletePermanently
              ? 'Delete $count items permanently?'
              : 'Move $count items to trash?',
        ),
        content: Text(
          deletePermanently
              ? 'This will permanently delete $count items from ${widget.host.name}.'
              : 'Backups will be stored locally so you can restore them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(deletePermanently ? 'Delete' : 'Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (deletePermanently) {
      await _deleteHandler.deleteMultiplePermanently(
        context,
        entries,
        _currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _deleteHandler.moveMultipleToTrash(
        context,
        entries,
        _currentPath,
        _refreshCurrentPath,
      );
    }
  }

  Future<void> _handleDownload(List<RemoteFileEntry> entries) async {
    await _fileOpsService.handleDownload(
      context: context,
      entries: entries,
      currentPath: _currentPath,
      joinPath: PathUtils.joinPath,
    );
  }

  Future<void> _handleUploadFiles(String targetDirectory) async {
    await _fileOpsService.handleUploadFiles(
      context: context,
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<void> _handleUploadFolder(String targetDirectory) async {
    await _fileOpsService.handleUploadFolder(
      context: context,
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<String?> _promptMergeDialog({
    required String remotePath,
    required String local,
    required String remote,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => MergeConflictDialog(
        remotePath: remotePath,
        local: local,
        remote: remote,
      ),
    );
  }

  Future<void> _showNavigateToSubdirectoryDialog() async {
    final selected = await DialogBuilders.showNavigateToSubdirectoryDialog(
      context,
      _entries,
    );
    if (selected != null && mounted) {
      final targetPath = PathUtils.joinPath(_currentPath, selected);
      _loadPath(targetPath);
    }
  }
}

class CancelledExplorerOperation implements Exception {
  const CancelledExplorerOperation();

  @override
  String toString() => 'CancelledExplorerOperation';
}
