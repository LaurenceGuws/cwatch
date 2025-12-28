import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../../../../shared/mixins/tab_options_mixin.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../widgets/dialog_keyboard_shortcuts.dart';
import 'context_menu_builder.dart';
import 'dialog_builders.dart';
import 'explorer_clipboard.dart';
import 'file_explorer_controller.dart';
import 'merge_conflict_dialog.dart';
import 'file_entry_list.dart';
import 'selection_controller.dart';
import 'path_navigator.dart';
import 'path_utils.dart';
import '../tab_chip.dart';

class FileExplorerTab extends StatefulWidget {
  FileExplorerTab({
    super.key,
    required this.host,
    required this.explorerContext,
    required this.shellService,
    required this.settingsController,
    required this.trashManager,
    required this.onOpenTrash,
    this.onOpenEditorTab,
    this.onOpenTerminalTab,
    this.optionsController,
    this.initialPath,
    this.onPathChanged,
  }) : assert(explorerContext.host == host);

  final SshHost host;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;
  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final ValueChanged<ExplorerContext> onOpenTrash;
  final Future<void> Function(String path, String initialContent)?
  onOpenEditorTab;
  final ValueChanged<String>? onOpenTerminalTab;
  final TabOptionsController? optionsController;
  final String? initialPath;
  final ValueChanged<String>? onPathChanged;

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab>
    with TabOptionsMixin {
  late final FileExplorerController _controller;
  late final VoidCallback _controllerListener;
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final ScrollController _scrollController = ScrollController();
  bool _dropHover = false;

  @override
  void initState() {
    super.initState();
    _controller = FileExplorerController(
      host: widget.host,
      explorerContext: widget.explorerContext,
      shellService: widget.shellService,
      settingsController: widget.settingsController,
      trashManager: widget.trashManager,
      onOpenEditorTab: widget.onOpenEditorTab,
      onPathChanged: widget.onPathChanged,
      initialPath: widget.initialPath,
      promptMergeDialog: _promptMergeDialog,
    );
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
      _updateTabOptions();
    };
    _controller.addListener(_controllerListener);
    unawaited(_controller.initialize(context));
  }

  @override
  void didUpdateWidget(covariant FileExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shellChanged = oldWidget.shellService != widget.shellService;
    final hostChanged = oldWidget.host != widget.host;
    if (shellChanged || hostChanged) {
      _controller
        ..removeListener(_controllerListener)
        ..dispose();
      _controller = FileExplorerController(
        host: widget.host,
        explorerContext: widget.explorerContext,
        shellService: widget.shellService,
        settingsController: widget.settingsController,
        trashManager: widget.trashManager,
        onOpenEditorTab: widget.onOpenEditorTab,
        onPathChanged: widget.onPathChanged,
        initialPath: widget.initialPath,
        promptMergeDialog: _promptMergeDialog,
      );
      _controller.addListener(_controllerListener);
      unawaited(_controller.initialize(context));
      return;
    }
    if (oldWidget.optionsController != widget.optionsController ||
        oldWidget.onOpenTerminalTab != widget.onOpenTerminalTab ||
        oldWidget.onOpenTrash != widget.onOpenTrash) {
      _updateTabOptions();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final dropOverlayColor =
        context.appTheme.list.selectedBackground.withValues(alpha: 0.35);
    final contentCard = Card(
      clipBehavior: Clip.antiAlias,
      child: _controller.loading
          ? const Center(child: CircularProgressIndicator())
          : _controller.error != null
          ? Center(child: Text(_controller.error!))
          : _buildEntriesList(),
    );

    final dropWrapped = _supportsDesktopDrop
        ? DropTarget(
            enable: true,
            onDragEntered: (_) {
              if (_controller.isOsDragActive ||
                  _controller.isSelfDragTarget(_controller.currentPath)) {
                return;
              }
              AppLogger.d(
                'Drop entered ${_controller.currentPath}',
                tag: 'Explorer',
              );
              if (!_dropHover) {
                setState(() => _dropHover = true);
              }
            },
            onDragUpdated: (details) {
              if (_controller.isOsDragActive ||
                  _controller.isSelfDragTarget(_controller.currentPath)) {
                return;
              }
              if (!_dropHover) {
                setState(() => _dropHover = true);
              }
            },
            onDragExited: (_) {
              if (_controller.isOsDragActive ||
                  _controller.isSelfDragTarget(_controller.currentPath)) {
                return;
              }
              AppLogger.d(
                'Drop exited ${_controller.currentPath}',
                tag: 'Explorer',
              );
              if (_dropHover) {
                setState(() => _dropHover = false);
              }
            },
            onDragDone: (details) async {
              if (_controller.isSelfDragDrop(
                paths: details.files.map((file) => file.path).toList(),
                targetDirectory: _controller.currentPath,
              )) {
                AppLogger.d(
                  'Drop ignored: source and target match',
                  tag: 'Explorer',
                );
                return;
              }
              AppLogger.d(
                'Drop done ${details.files.length} files at '
                '${details.localPosition}',
                tag: 'Explorer',
              );
              if (_dropHover) {
                setState(() => _dropHover = false);
              }
              await _handleLocalDrop(details);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                contentCard,
                if (_dropHover)
                  Container(
                    color: dropOverlayColor,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_file, size: 48),
                        SizedBox(height: spacing.md),
                        const Text('Drop files or folders to upload'),
                      ],
                    ),
                  ),
              ],
            ),
          )
        : contentCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: spacing.md),
          child: _buildPathNavigator(context),
        ),
        SizedBox(height: spacing.lg),
        Expanded(child: dropWrapped),
      ],
    );
  }

  Widget _buildPathNavigator(BuildContext context) {
    return PathNavigator(
      currentPath: _controller.currentPath,
      pathHistory: _controller.pathHistory,
      onPathChanged: (path) => _loadPath(path),
      showBreadcrumbs: _controller.showBreadcrumbs,
      onShowBreadcrumbsChanged: _controller.setShowBreadcrumbs,
      onNavigateToSubdirectory: () => _showNavigateToSubdirectoryDialog(),
      onPrefetchPath: _controller.prefetchPath,
    );
  }

  Widget _buildEntriesList() {
    final sortedEntries = _controller.currentSortedEntries();
    final list = FileEntryList(
      entries: sortedEntries,
      currentPath: _controller.currentPath,
      selectedPaths: _controller.selectionController.selectedPaths,
      syncingPaths: _controller.syncingPaths,
      refreshingPaths: _controller.refreshingPaths,
      localEdits: _controller.localEdits,
      scrollController: _scrollController,
      focusNode: _listFocusNode,
      onEntryDoubleTap: _handleEntryDoubleTap,
      onEntryPointerDown: (event, entries, index, remotePath) {
        _controller.selectionController.handleEntryPointerDown(
          event,
          entries,
          index,
          remotePath,
          () => _listFocusNode.requestFocus(),
          _controller.markNeedsBuild,
        );
      },
      onDragHover: (event, index, remotePath) {
        _controller.selectionController.handleDragHover(
          event,
          index,
          remotePath,
          _controller.markNeedsBuild,
        );
      },
      onStopDragSelection: () =>
          _controller.selectionController.stopDragSelection(),
      onEntryContextMenu: _showEntryContextMenu,
      onBackgroundContextMenu: null,
      onKeyEvent: (node, event, entries) {
        return _controller.selectionController.handleListKeyEvent(
          node,
          event,
          entries,
          _controller.markNeedsBuild,
          () {
            final selectedEntries = _controller.selectionController
                .getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(_handleMultiCopy(selectedEntries));
              } else {
                _handleClipboardSet(
                  selectedEntries.first,
                  ExplorerClipboardOperation.copy,
                );
              }
            }
          },
          () {
            final selectedEntries = _controller.selectionController
                .getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(_handleMultiCut(selectedEntries));
              } else {
                _handleClipboardSet(
                  selectedEntries.first,
                  ExplorerClipboardOperation.cut,
                );
              }
            }
          },
          () => _handlePaste(targetDirectory: _controller.currentPath),
          () {
            final selectedEntries = _controller.selectionController
                .getSelectedEntries(entries);
            if (selectedEntries.isNotEmpty) {
              if (selectedEntries.length > 1) {
                unawaited(
                  _confirmMultiDelete(
                    selectedEntries,
                    permanent: SelectionController.isShiftPressed(),
                  ),
                );
              } else {
                unawaited(
                  _confirmDelete(
                    selectedEntries.first,
                    permanent: SelectionController.isShiftPressed(),
                  ),
                );
              }
            }
          },
          () {
            final entry = _controller.selectionController.primarySelectedEntry(
              entries,
            );
            if (entry != null) {
              unawaited(_promptRename(entry));
            }
          },
        );
      },
      onSyncLocalEdit: _syncLocalEdit,
      onRefreshCacheFromServer: _refreshCacheFromServer,
      onClearCachedCopy: _clearCachedCopy,
      onStartOsDrag: (position) async {
        final selected = _controller.selectionController.getSelectedEntries(
          sortedEntries,
        );
        if (selected.isEmpty) return;
        await _controller.startOsDrag(
          context: context,
          globalPosition: position,
          entriesToDrag: selected,
        );
      },
      joinPath: PathUtils.joinPath,
    );
    return list;
  }

  Future<void> _loadPath(String path, {bool forceReload = false}) async {
    await _controller.loadPath(path, forceReload: forceReload);
  }

  Future<void> _handleLocalDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) {
      AppLogger.d('Drop ignored: no files', tag: 'Explorer');
      return;
    }
    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty);
    AppLogger.d(
      'Handling drop of ${details.files.length} items to '
      '${_controller.currentPath}: ${paths.join(', ')}',
      tag: 'Explorer',
    );
    await _controller.fileOpsService.handleDroppedPaths(
      context: context,
      targetDirectory: _controller.currentPath,
      paths: paths.toList(),
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
    if (mounted) {
      final count = details.files.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploading $count dropped item${count == 1 ? '' : 's'} to ${_controller.currentPath}',
          ),
        ),
      );
    }
  }

  bool get _supportsDesktopDrop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<void> _refreshCurrentPath() async {
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    await _controller.refreshCurrentPath();
    if (_scrollController.hasClients && scrollOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(scrollOffset);
        }
      });
    }
  }

  Future<void> _showEntryContextMenu(
    RemoteFileEntry entry,
    Offset position,
  ) async {
    final sortedEntries = _controller.currentSortedEntries();
    final selectedEntries = _controller.selectionController.getSelectedEntries(
      sortedEntries,
    );
    final builder = ContextMenuBuilder(
      hostName: widget.host.name,
      currentPath: _controller.currentPath,
      selectedEntries: selectedEntries,
      clipboardAvailable: ExplorerClipboard.hasEntries,
      onOpen: (e) =>
          _loadPath(PathUtils.joinPath(_controller.currentPath, e.name)),
      onCopyPath: (e) async {
        final path = PathUtils.joinPath(_controller.currentPath, e.name);
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied $path')));
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
      onPaste: () => _handlePaste(targetDirectory: _controller.currentPath),
      onPasteInto: (e) => _handlePaste(
        targetDirectory: PathUtils.joinPath(_controller.currentPath, e.name),
      ),
      onMove: _promptMove,
      onDelete: (entries) async {
        if (entries.length > 1) {
          await _confirmMultiDelete(
            entries,
            permanent: SelectionController.isShiftPressed(),
          );
        } else {
          await _confirmDelete(
            entries.first,
            permanent: SelectionController.isShiftPressed(),
          );
        }
      },
      onDownload: _handleDownload,
      onUploadFiles: _handleUploadFiles,
      onUploadFolder: _handleUploadFolder,
      onOpenTerminal: widget.onOpenTerminalTab,
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
    final targetPath = PathUtils.joinPath(_controller.currentPath, entry.name);
    if (entry.isDirectory) {
      _loadPath(targetPath);
    } else {
      unawaited(_openLocally(entry));
    }
  }

  Future<void> _openEditor(RemoteFileEntry entry) async {
    await _controller.fileEditingService.openEditor(
      context,
      entry,
      _controller.currentPath,
    );
  }

  Future<void> _openLocally(RemoteFileEntry entry) async {
    final session = await _controller.fileEditingService.openLocally(
      context,
      entry,
      _controller.currentPath,
    );
    if (session != null && mounted) {
      _controller.updateLocalEdit(session);
    }
  }

  Future<void> _syncLocalEdit(LocalFileSession session) async {
    _controller.markSyncing(session.remotePath, syncing: true);
    await _controller.fileEditingService.syncLocalEdit(context, session, (s) {
      if (mounted) {
        _controller.updateLocalEdit(s);
      }
    });
    if (mounted) {
      _controller.markSyncing(session.remotePath, syncing: false);
    }
  }

  Future<void> _refreshCacheFromServer(LocalFileSession session) async {
    _controller.markRefreshing(session.remotePath, refreshing: true);
    await _controller.fileEditingService.refreshCacheFromServer(
      context,
      session,
    );
    if (mounted) {
      _controller.markRefreshing(session.remotePath, refreshing: false);
    }
  }

  Future<void> _clearCachedCopy(LocalFileSession session) async {
    await _controller.fileEditingService.clearCachedCopy(context, session);
    if (mounted) {
      _controller.removeLocalEdit(session);
    }
  }

  void _handleClipboardSet(
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    _controller.clipboardHandler.setClipboardEntry(context, entry, operation);
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
    final sourcePath = PathUtils.joinPath(_controller.currentPath, entry.name);
    final destinationPath = PathUtils.joinPath(
      _controller.currentPath,
      trimmed,
    );
    try {
      await _controller.runShell(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to rename: $error')));
    }
  }

  Future<void> _promptMove(RemoteFileEntry entry) async {
    final target = await DialogBuilders.showMoveDialog(
      context,
      entry,
      _controller.currentPath,
    );
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final normalized = PathUtils.normalizePath(
      target,
      currentPath: _controller.currentPath,
    );
    if (normalized == PathUtils.joinPath(_controller.currentPath, entry.name)) {
      return;
    }
    try {
      await _controller.runShell(
        () => widget.shellService.movePath(
          widget.host,
          PathUtils.joinPath(_controller.currentPath, entry.name),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to move: $error')));
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
      await _controller.deleteHandler.deletePermanently(
        context,
        entry,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _controller.deleteHandler.moveToTrash(
        context,
        entry,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    }
  }

  Future<void> _handlePaste({required String targetDirectory}) async {
    await _controller.fileOpsService.handlePaste(
      context: context,
      targetDirectory: targetDirectory,
      currentPath: _controller.currentPath,
      joinPath: PathUtils.joinPath,
      normalizePath: (path) =>
          PathUtils.normalizePath(path, currentPath: _controller.currentPath),
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<void> _handleMultiCopy(List<RemoteFileEntry> entries) async {
    _controller.clipboardHandler.setClipboardEntries(
      context,
      entries,
      ExplorerClipboardOperation.copy,
    );
  }

  Future<void> _handleMultiCut(List<RemoteFileEntry> entries) async {
    _controller.clipboardHandler.setClipboardEntries(
      context,
      entries,
      ExplorerClipboardOperation.cut,
    );
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
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
        child: AlertDialog(
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
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (deletePermanently) {
      await _controller.deleteHandler.deleteMultiplePermanently(
        context,
        entries,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _controller.deleteHandler.moveMultipleToTrash(
        context,
        entries,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    }
  }

  Future<void> _handleDownload(List<RemoteFileEntry> entries) async {
    await _controller.fileOpsService.handleDownload(
      context: context,
      entries: entries,
      currentPath: _controller.currentPath,
      joinPath: PathUtils.joinPath,
    );
  }

  Future<void> _handleUploadFiles(String targetDirectory) async {
    await _controller.fileOpsService.handleUploadFiles(
      context: context,
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<void> _handleUploadFolder(String targetDirectory) async {
    await _controller.fileOpsService.handleUploadFolder(
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
      _controller.entries,
    );
    if (selected != null && mounted) {
      final targetPath = PathUtils.joinPath(_controller.currentPath, selected);
      _loadPath(targetPath);
    }
  }

  void _updateTabOptions() {
    final controller = widget.optionsController;
    if (controller == null) {
      return;
    }
    final options = <TabChipOption>[];
    options.add(
      TabChipOption(
        label: 'Upload files…',
        icon: Icons.upload_file,
        onSelected: () => _handleUploadFiles(_controller.currentPath),
      ),
    );
    options.add(
      TabChipOption(
        label: 'Upload folder…',
        icon: Icons.folder,
        onSelected: () => _handleUploadFolder(_controller.currentPath),
      ),
    );
    options.add(
      TabChipOption(
        label: 'Open trash',
        icon: Icons.delete_outline,
        onSelected: () => widget.onOpenTrash(widget.explorerContext),
      ),
    );
    if (widget.onOpenTerminalTab != null) {
      options.add(
        TabChipOption(
          label: 'Open terminal here',
          icon: Icons.terminal,
          onSelected: () => widget.onOpenTerminalTab!(_controller.currentPath),
        ),
      );
    }
    queueTabOptions(controller, options, useBase: true);
  }
}
