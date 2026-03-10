import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

import 'package:cwatch/view/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/model/shared/shortcuts/input_mode_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_resolver.dart';
import 'context_menu_builder.dart';
import 'explorer_chrome_scaffold.dart';
import 'file_entry_list.dart';
import 'selection_controller.dart';
import 'package:cwatch/view/features/settings/settings/explorer_settings_controls.dart';
import 'path_navigator.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.onOpenTrash,
    this.onOpenTerminalTab,
    this.optionsController,
  });

  final FileExplorerController controller;
  final SettingsController settingsController;
  final ValueChanged<ExplorerContext> onOpenTrash;
  final ValueChanged<String>? onOpenTerminalTab;
  final TabOptionsController? optionsController;

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab>
    with TabOptionsMixin {
  late FileExplorerController _controller;
  late SelectionController _selectionController;
  late SettingsController _settingsController;
  late final VoidCallback _controllerListener;
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final ScrollController _scrollController = ScrollController();
  bool _dropHover = false;
  String? _lastTimeoutNotification;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController;
    _controller = widget.controller;
    _selectionController = SelectionController(state: _controller.selectionState);
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
      _updateTabOptions();
    };
    _controller.addListener(_controllerListener);
    unawaited(_controller.initialize());
  }

  @override
  void didUpdateWidget(covariant FileExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_controllerListener);
      oldWidget.controller.dispose();
      _controller = widget.controller;
      _selectionController = SelectionController(state: _controller.selectionState);
      _controller.addListener(_controllerListener);
      unawaited(_controller.initialize());
    }
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.dispose();
      _settingsController = widget.settingsController;
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
    _settingsController.dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });
    _updateTabOptions();
  }

  void _showSnackBar(String message) {
    _controller.uiAdapter.showSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _controller.state.error;
    final isTimeoutError = _isTimeoutError(errorMessage);
    if (isTimeoutError &&
        errorMessage != null &&
        errorMessage != _lastTimeoutNotification) {
      _lastTimeoutNotification = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showSnackBar(errorMessage);
      });
    }
    final showStreamingResults =
        _controller.state.loading &&
        _controller.state.searchActive &&
        _controller.state.searchQuery.trim().isNotEmpty;
    final contentCard = Card(
      clipBehavior: Clip.antiAlias,
      child: errorMessage != null && !isTimeoutError
          ? Center(child: Text(errorMessage))
          : showStreamingResults
          ? Stack(
              fit: StackFit.expand,
              children: [
                _buildEntriesList(),
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(),
                ),
              ],
            )
          : _controller.state.loading
          ? const Center(child: CircularProgressIndicator())
          : _buildEntriesList(),
    );

    final actions = Actions(
      actions: {
        _ToggleSearchIntent: CallbackAction<_ToggleSearchIntent>(
          onInvoke: (_) {
            unawaited(
              _controller.setSearchActive(!_controller.state.searchActive),
            );
            return null;
          },
        ),
        _ZoomInIntent: CallbackAction<_ZoomInIntent>(
          onInvoke: (_) {
            _adjustRowHeight(4);
            return null;
          },
        ),
        _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
          onInvoke: (_) {
            _adjustRowHeight(-4);
            return null;
          },
        ),
      },
      child: Focus(
        autofocus: true,
        child: ExplorerChromeScaffold(
          pathNavigator: _buildPathNavigator(context),
          content: contentCard,
          showSettings: _showSettings,
          settings: ExplorerSettingsControls(
            settings: _settingsController.settings,
            settingsController: _settingsController,
          ),
          onCloseSettings: _toggleSettings,
          supportsDesktopDrop: _supportsDesktopDrop,
          dropEnabled: true,
          dropHover: _dropHover,
          onDragEntered: (_) => _handleDropEntered(),
          onDragUpdated: (_) => _handleDropUpdated(),
          onDragExited: (_) => _handleDropExited(),
          onDragDone: _handleDropDone,
        ),
      ),
    );

    final shortcuts = _explorerShortcuts(_settingsController.settings);
    if (shortcuts.isEmpty) {
      return actions;
    }
    return Shortcuts(shortcuts: shortcuts, child: actions);
  }

  void _adjustRowHeight(double delta) {
    final next = _controller.state.rowHeight + delta;
    _controller.setRowHeight(next);
  }

  Map<ShortcutActivator, Intent> _explorerShortcuts(AppSettings settings) {
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    if (!inputMode.enableShortcuts) {
      return const {};
    }
    final resolver = ShortcutResolver(settings);
    final map = <ShortcutActivator, Intent>{};

    void add(String id, Intent intent) {
      final binding = resolver.bindingFor(id);
      if (binding == null) return;
      map[binding.toActivator()] = intent;
    }

    add(ShortcutActions.explorerSearch, const _ToggleSearchIntent());
    add(ShortcutActions.explorerZoomIn, const _ZoomInIntent());
    add(ShortcutActions.explorerZoomOut, const _ZoomOutIntent());

    return map;
  }

  Widget _buildPathNavigator(BuildContext context) {
    return PathNavigator(
      currentPath: _controller.currentPath,
      pathHistory: _controller.state.pathHistory,
      onPathChanged: (path) => _loadPath(path),
      showBreadcrumbs: _controller.state.showBreadcrumbs,
      onShowBreadcrumbsChanged: _controller.setShowBreadcrumbs,
      onNavigateToSubdirectory: () => _showNavigateToSubdirectoryDialog(),
      onPrefetchPath: _controller.prefetchPath,
      searchActive: _controller.state.searchActive,
      searchQuery: _controller.state.searchQuery,
      onSearchActiveChanged: (value) {
        unawaited(_controller.setSearchActive(value));
      },
      onSearchQueryChanged: _controller.setSearchQuery,
      onSearchSubmitted: (query) {
        unawaited(_controller.searchCurrentPath(query));
      },
      searchInProgress:
          _controller.state.loading &&
          _controller.state.searchActive &&
          _controller.state.searchQuery.trim().isNotEmpty,
      onSearchCancelled: _controller.cancelSearch,
      searchInclude: _controller.state.searchInclude,
      searchExclude: _controller.state.searchExclude,
      searchMatchCase: _controller.state.searchMatchCase,
      searchMatchWholeWord: _controller.state.searchMatchWholeWord,
      onSearchIncludeChanged: _controller.setSearchInclude,
      onSearchExcludeChanged: _controller.setSearchExclude,
      onSearchMatchCaseChanged: _controller.toggleSearchMatchCase,
      onSearchMatchWholeWordChanged: _controller.toggleSearchMatchWholeWord,
      searchContents: _controller.state.searchContents,
      onSearchContentsChanged: _controller.setSearchContents,
      showRowHeightControl: _controller.state.showRowHeightControl,
      rowHeight: _controller.state.rowHeight,
      onRowHeightChanged: _controller.setRowHeight,
      onShowMenu: (position, items, constraints) =>
          _controller.uiAdapter.showMenuAt(
            position: position,
            items: items,
            constraints: constraints,
          ),
    );
  }

  Widget _buildEntriesList() {
    final sortedEntries = _controller.currentSortedEntries();
    final list = FileEntryList(
      entries: sortedEntries,
      currentPath: _controller.currentPath,
      selectedPaths: _selectionController.selectedPaths,
      syncingPaths: _controller.state.syncingPaths,
      refreshingPaths: _controller.state.refreshingPaths,
      localEdits: _controller.state.localEdits,
      rowHeight: _controller.state.rowHeight,
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
          _controller.markNeedsBuild,
        );
      },
      onDragHover: (event, index, remotePath) {
        _selectionController.handleDragHover(
          event,
          index,
          remotePath,
          _controller.markNeedsBuild,
        );
      },
      onStopDragSelection: () =>
          _selectionController.stopDragSelection(),
      onEntryContextMenu: _showEntryContextMenu,
      onBackgroundContextMenu: null,
      onKeyEvent: (node, event, entries) {
        return _selectionController.handleListKeyEvent(
          node,
          event,
          entries,
          _controller.markNeedsBuild,
          () {
            final selectedEntries = _selectionController.getSelectedEntries(
              entries,
            );
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
            final selectedEntries = _selectionController.getSelectedEntries(
              entries,
            );
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
            final selectedEntries = _selectionController.getSelectedEntries(
              entries,
            );
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
            final entry = _selectionController.primarySelectedEntry(
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
        final selected = _selectionController.getSelectedEntries(
          sortedEntries,
        );
        if (selected.isEmpty) return;
        await _controller.startOsDrag(
          globalPosition: position,
          entriesToDrag: selected,
        );
      },
      joinPath: PathUtils.joinPath,
    );
    return list;
  }

  bool _isTimeoutError(String? message) {
    if (message == null || message.isEmpty) {
      return false;
    }
    return message.contains('TimeoutException') ||
        message.toLowerCase().contains('timed out');
  }

  Future<void> _loadPath(String path, {bool forceReload = false}) async {
    await _controller.loadPath(path, forceReload: forceReload);
  }

  Future<void> _handleLocalDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) {
      AppLogger().debug('Drop ignored: no files', tag: 'Explorer');
      return;
    }
    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty);
    AppLogger().debug(
      'Handling drop of ${details.files.length} items to '
      '${_controller.currentPath}: ${paths.join(', ')}',
      tag: 'Explorer',
    );
    await _controller.fileOpsUiHandler.handleDroppedPaths(
      targetDirectory: _controller.currentPath,
      paths: paths.toList(),
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
    if (mounted) {
      final count = details.files.length;
      _showSnackBar(
        'Uploading $count dropped item${count == 1 ? '' : 's'} to ${_controller.currentPath}',
      );
    }
  }

  void _handleDropEntered() {
    if (_controller.isOsDragActive ||
        _controller.isSelfDragTarget(_controller.currentPath)) {
      return;
    }
    AppLogger().debug('Drop entered ${_controller.currentPath}', tag: 'Explorer');
    if (!_dropHover) {
      setState(() => _dropHover = true);
    }
  }

  void _handleDropUpdated() {
    if (_controller.isOsDragActive ||
        _controller.isSelfDragTarget(_controller.currentPath)) {
      return;
    }
    if (!_dropHover) {
      setState(() => _dropHover = true);
    }
  }

  void _handleDropExited() {
    if (_controller.isOsDragActive ||
        _controller.isSelfDragTarget(_controller.currentPath)) {
      return;
    }
    AppLogger().debug('Drop exited ${_controller.currentPath}', tag: 'Explorer');
    if (_dropHover) {
      setState(() => _dropHover = false);
    }
  }

  Future<void> _handleDropDone(DropDoneDetails details) async {
    if (_controller.isSelfDragDrop(
      paths: details.files.map((file) => file.path).toList(),
      targetDirectory: _controller.currentPath,
    )) {
      AppLogger().debug(
        'Drop ignored: source and target match',
        tag: 'Explorer',
      );
      return;
    }
    AppLogger().debug(
      'Drop done ${details.files.length} files at ${details.localPosition}',
      tag: 'Explorer',
    );
    if (_dropHover) {
      setState(() => _dropHover = false);
    }
    await _handleLocalDrop(details);
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
    final selectedEntries = _selectionController.getSelectedEntries(
      sortedEntries,
    );
    final builder = ContextMenuBuilder(
      hostName: _controller.host.name,
      currentPath: _controller.currentPath,
      selectedEntries: selectedEntries,
      clipboardAvailable: ExplorerClipboard.hasEntries,
      onOpen: (e) =>
          _loadPath(PathUtils.joinPath(_controller.currentPath, e.name)),
      onCopyPath: (e) async {
        final path = PathUtils.joinPath(_controller.currentPath, e.name);
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          _showSnackBar('Copied $path');
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
      onMessage: _showSnackBar,
      joinPath: PathUtils.joinPath,
    );

    final menuItems = builder.buildEntryMenuItems(entry);
    final action = await _controller.uiAdapter
        .showContextMenu<ExplorerContextAction>(
          position: position,
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
      entry,
      _controller.currentPath,
    );
  }

  Future<void> _openLocally(RemoteFileEntry entry) async {
    final session = await _controller.fileEditingService.openLocally(
      entry,
      _controller.currentPath,
    );
    if (session != null && mounted) {
      _controller.updateLocalEdit(session);
    }
  }

  Future<void> _syncLocalEdit(LocalFileSession session) async {
    _controller.markSyncing(session.remotePath, syncing: true);
    await _controller.fileEditingService.syncLocalEdit(session, (s) {
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
    await _controller.fileEditingService.refreshCacheFromServer(session);
    if (mounted) {
      _controller.markRefreshing(session.remotePath, refreshing: false);
    }
  }

  Future<void> _clearCachedCopy(LocalFileSession session) async {
    await _controller.fileEditingService.clearCachedCopy(session);
    if (mounted) {
      _controller.removeLocalEdit(session);
    }
  }

  void _handleClipboardSet(
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    _controller.clipboardHandler.setClipboardEntry(entry, operation);
  }

  Future<void> _promptRename(RemoteFileEntry entry) async {
    final newName = await _controller.uiAdapter.showRenameDialog(entry);
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
        () => _controller.shellService.movePath(
          _controller.host,
          sourcePath,
          destinationPath,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      _showSnackBar('Renamed ${entry.name} to $trimmed');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to rename ${entry.name}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is CancelledExplorerOperation) return;
      if (!mounted) return;
      _showSnackBar('Failed to rename: $error');
    }
  }

  Future<void> _promptMove(RemoteFileEntry entry) async {
    final target = await _controller.uiAdapter.showMoveDialog(
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
        () => _controller.shellService.movePath(
          _controller.host,
          PathUtils.joinPath(_controller.currentPath, entry.name),
          normalized,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      _showSnackBar('Moved ${entry.name} to $normalized');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to move ${entry.name}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is CancelledExplorerOperation) return;
      if (!mounted) return;
      _showSnackBar('Failed to move: $error');
    }
  }

  Future<void> _confirmDelete(
    RemoteFileEntry entry, {
    bool permanent = false,
  }) async {
    final deletePermanently = permanent || SelectionController.isShiftPressed();
    final confirmed = await _controller.uiAdapter.showDeleteDialog(
      entry,
      _controller.host,
      deletePermanently,
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (deletePermanently) {
      await _controller.deleteHandler.deletePermanently(
        entry,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _controller.deleteHandler.moveToTrash(
        entry,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    }
  }

  Future<void> _handlePaste({required String targetDirectory}) async {
    await _controller.fileOpsUiHandler.handlePaste(
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
      entries,
      ExplorerClipboardOperation.copy,
    );
  }

  Future<void> _handleMultiCut(List<RemoteFileEntry> entries) async {
    _controller.clipboardHandler.setClipboardEntries(
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
    final confirmed = await _controller.uiAdapter.showMultiDeleteDialog(
      count: count,
      hostName: _controller.host.name,
      deletePermanently: deletePermanently,
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) return;
    if (deletePermanently) {
      await _controller.deleteHandler.deleteMultiplePermanently(
        entries,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    } else {
      await _controller.deleteHandler.moveMultipleToTrash(
        entries,
        _controller.currentPath,
        _refreshCurrentPath,
      );
    }
  }

  Future<void> _handleDownload(List<RemoteFileEntry> entries) async {
    await _controller.fileOpsUiHandler.handleDownload(
      entries: entries,
      currentPath: _controller.currentPath,
      joinPath: PathUtils.joinPath,
    );
  }

  Future<void> _handleUploadFiles(String targetDirectory) async {
    await _controller.fileOpsUiHandler.handleUploadFiles(
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<void> _handleUploadFolder(String targetDirectory) async {
    await _controller.fileOpsUiHandler.handleUploadFolder(
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: _refreshCurrentPath,
    );
  }

  Future<void> _showNavigateToSubdirectoryDialog() async {
    final selected = await _controller.uiAdapter
        .showNavigateToSubdirectoryDialog(_controller.state.entries);
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
        label: _controller.state.searchActive ? 'Hide search' : 'Show search',
        icon: _controller.state.searchActive ? Icons.search_off : Icons.search,
        onSelected: () {
          unawaited(
            _controller.setSearchActive(!_controller.state.searchActive),
          );
        },
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
        onSelected: () => widget.onOpenTrash(_controller.explorerContext),
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
    options.add(
      TabChipOption(
        label: _showSettings ? 'Hide settings' : 'Settings',
        icon: Icons.settings,
        onSelected: _toggleSettings,
      ),
    );
    queueTabOptions(controller, options, useBase: true);
  }
}

class _ToggleSearchIntent extends Intent {
  const _ToggleSearchIntent();
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}
