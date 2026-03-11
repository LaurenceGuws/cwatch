import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

import 'package:cwatch/view/shared/mixins/tab_options_mixin.dart';
import 'explorer_chrome_scaffold.dart';
import 'file_explorer_tab_actions.dart';
import 'file_explorer_tab_entry_interactions.dart';
import 'file_explorer_tab_presenter.dart';
import 'selection_controller.dart';
import 'package:cwatch/view/features/settings/settings/explorer_settings_controls.dart';
import 'path_navigator.dart';

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
  late FileExplorerTabPresenter _presenter;
  late FileExplorerTabActions _actions;
  late FileExplorerTabEntryInteractions _entryInteractions;
  late final VoidCallback _controllerListener;
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final ScrollController _scrollController = ScrollController();
  bool _dropHover = false;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController;
    _controller = widget.controller;
    _selectionController = SelectionController(state: _controller.selectionState);
    _presenter = FileExplorerTabPresenter(
      controller: _controller,
      settingsController: _settingsController,
    );
    _actions = FileExplorerTabActions(
      controller: _controller,
      selectionController: _selectionController,
      scrollController: _scrollController,
      isMounted: () => mounted,
      showSnackBar: _showSnackBar,
      openTerminalTab: widget.onOpenTerminalTab,
    );
    _entryInteractions = FileExplorerTabEntryInteractions(
      controller: _controller,
      selectionController: _selectionController,
      actions: _actions,
      listFocusNode: _listFocusNode,
      scrollController: _scrollController,
      markNeedsBuild: _controller.markNeedsBuild,
    );
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
      _selectionController = SelectionController(
        state: _controller.selectionState,
      );
      _presenter = FileExplorerTabPresenter(
        controller: _controller,
        settingsController: _settingsController,
      );
      _actions = FileExplorerTabActions(
        controller: _controller,
        selectionController: _selectionController,
        scrollController: _scrollController,
        isMounted: () => mounted,
        showSnackBar: _showSnackBar,
        openTerminalTab: widget.onOpenTerminalTab,
      );
      _entryInteractions = FileExplorerTabEntryInteractions(
        controller: _controller,
        selectionController: _selectionController,
        actions: _actions,
        listFocusNode: _listFocusNode,
        scrollController: _scrollController,
        markNeedsBuild: _controller.markNeedsBuild,
      );
      _controller.addListener(_controllerListener);
      unawaited(_controller.initialize());
    }
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.dispose();
      _settingsController = widget.settingsController;
      _presenter = FileExplorerTabPresenter(
        controller: _controller,
        settingsController: _settingsController,
      );
    }
    if (oldWidget.optionsController != widget.optionsController ||
        oldWidget.onOpenTerminalTab != widget.onOpenTerminalTab ||
        oldWidget.onOpenTrash != widget.onOpenTrash) {
      _actions = FileExplorerTabActions(
        controller: _controller,
        selectionController: _selectionController,
        scrollController: _scrollController,
        isMounted: () => mounted,
        showSnackBar: _showSnackBar,
        openTerminalTab: widget.onOpenTerminalTab,
      );
      _entryInteractions = FileExplorerTabEntryInteractions(
        controller: _controller,
        selectionController: _selectionController,
        actions: _actions,
        listFocusNode: _listFocusNode,
        scrollController: _scrollController,
        markNeedsBuild: _controller.markNeedsBuild,
      );
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
      _presenter.toggleSettings();
    });
    _updateTabOptions();
  }

  void _showSnackBar(String message) {
    _controller.uiAdapter.showSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _presenter.errorMessage;
    final timeoutNotification = _presenter.consumeTimeoutNotification();
    if (timeoutNotification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showSnackBar(timeoutNotification);
      });
    }
    final contentCard = Card(
      clipBehavior: Clip.antiAlias,
      child: errorMessage != null && !_presenter.isTimeoutError
          ? Center(child: Text(errorMessage))
          : _presenter.showStreamingResults
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
          : _presenter.showLoadingIndicator
          ? const Center(child: CircularProgressIndicator())
          : _buildEntriesList(),
    );

    final actions = Actions(
      actions: {
        ToggleSearchIntent: CallbackAction<ToggleSearchIntent>(
          onInvoke: (_) {
            unawaited(
              _controller.setSearchActive(!_controller.state.searchActive),
            );
            return null;
          },
        ),
        ZoomInIntent: CallbackAction<ZoomInIntent>(
          onInvoke: (_) {
            _adjustRowHeight(4);
            return null;
          },
        ),
        ZoomOutIntent: CallbackAction<ZoomOutIntent>(
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
          showSettings: _presenter.showSettings,
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

    final shortcuts = _presenter.buildShortcuts(_settingsController.settings);
    if (shortcuts.isEmpty) {
      return actions;
    }
    return Shortcuts(shortcuts: shortcuts, child: actions);
  }

  void _adjustRowHeight(double delta) {
    final next = _controller.state.rowHeight + delta;
    _controller.setRowHeight(next);
  }

  Widget _buildPathNavigator(BuildContext context) {
    return PathNavigator(
      currentPath: _controller.currentPath,
      pathHistory: _controller.state.pathHistory,
      onPathChanged: (path) => _actions.loadPath(path),
      showBreadcrumbs: _controller.state.showBreadcrumbs,
      onShowBreadcrumbsChanged: _controller.setShowBreadcrumbs,
      onNavigateToSubdirectory: _actions.showNavigateToSubdirectoryDialog,
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
    return _entryInteractions.build(context);
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
    await _actions.handleDropDone(details);
  }

  bool get _supportsDesktopDrop {
    if (kIsWeb) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
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
        onSelected: () => _actions.handleUploadFiles(_controller.currentPath),
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
        onSelected: () => _actions.handleUploadFolder(_controller.currentPath),
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
        label: _presenter.showSettings ? 'Hide settings' : 'Settings',
        icon: Icons.settings,
        onSelected: _toggleSettings,
      ),
    );
    queueTabOptions(controller, options, useBase: true);
  }
}
