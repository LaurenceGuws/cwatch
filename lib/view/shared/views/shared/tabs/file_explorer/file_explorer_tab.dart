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
import 'file_explorer_tab_actions.dart';
import 'file_explorer_tab_entry_interactions.dart';
import 'file_explorer_tab_presenter.dart';
import 'file_explorer_tab_surface.dart';
import 'file_explorer_tab_chrome_state.dart';
import 'selection_controller.dart';

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
  late FileExplorerTabChromeState _chromeState;
  late final VoidCallback _controllerListener;
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController;
    _controllerListener = () {
      _refreshView();
    };
    _bindController(widget.controller, initialize: true);
    _rebuildExplorerSeams();
  }

  @override
  void didUpdateWidget(covariant FileExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    var needsSeamRebuild = false;

    if (oldWidget.controller != widget.controller) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller, initialize: true);
      needsSeamRebuild = true;
    }
    if (oldWidget.settingsController != widget.settingsController) {
      _settingsController = widget.settingsController;
      needsSeamRebuild = true;
    }
    if (oldWidget.optionsController != widget.optionsController ||
        oldWidget.onOpenTerminalTab != widget.onOpenTerminalTab ||
        oldWidget.onOpenTrash != widget.onOpenTrash) {
      needsSeamRebuild = true;
    }

    if (needsSeamRebuild) {
      _rebuildExplorerSeams();
      _updateTabOptions();
    }
  }

  @override
  void dispose() {
    _unbindController(_controller);
    _listFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _bindController(
    FileExplorerController controller, {
    bool initialize = false,
  }) {
    _controller = controller;
    _controller.addListener(_controllerListener);
    if (initialize) {
      unawaited(_controller.initialize());
    }
  }

  void _unbindController(FileExplorerController controller) {
    controller.removeListener(_controllerListener);
  }

  void _rebuildExplorerSeams() {
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
    _chromeState = FileExplorerTabChromeState(
      controller: _controller,
      showSettings: () => _presenter.showSettings,
      onToggleSettings: _toggleSettings,
      onUploadFiles: _actions.handleUploadFiles,
      onUploadFolder: _actions.handleUploadFolder,
      onOpenTrash: () => widget.onOpenTrash(_controller.explorerContext),
      onOpenTerminalTab: widget.onOpenTerminalTab,
    );
  }

  void _toggleSettings() {
    setState(() {
      _presenter.toggleSettings();
    });
    _updateTabOptions();
  }

  void _refreshView({bool updateOptions = true}) {
    if (!mounted) return;
    setState(() {});
    if (updateOptions) {
      _updateTabOptions();
    }
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
        child: FileExplorerTabSurface(
          controller: _controller,
          settingsController: _settingsController,
          presenter: _presenter,
          content: contentCard,
          onToggleSettings: _toggleSettings,
          onLoadPath: (path) => _actions.loadPath(path),
          onNavigateToSubdirectory: _actions.showNavigateToSubdirectoryDialog,
          onShowMenu: (position, items, constraints) => _controller.uiAdapter.showMenuAt(
            position: position,
            items: items,
            constraints: constraints,
          ),
          supportsDesktopDrop: _supportsDesktopDrop,
          dropHover: _chromeState.dropHover,
          onDragEntered: (_) => _handleDropEntered(),
          onDragUpdated: (_) => _handleDropUpdated(),
          onDragExited: _handleDropExited,
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

  Widget _buildEntriesList() {
    return _entryInteractions.build(context);
  }

  void _handleDropEntered() {
    if (_chromeState.shouldIgnoreDropHover()) {
      return;
    }
    AppLogger().debug('Drop entered ${_controller.currentPath}', tag: 'Explorer');
    if (_chromeState.handleDropEntered()) {
      _refreshView(updateOptions: false);
    }
  }

  void _handleDropUpdated() {
    if (_chromeState.handleDropUpdated()) {
      _refreshView(updateOptions: false);
    }
  }

  void _handleDropExited() {
    if (_chromeState.shouldIgnoreDropHover()) {
      return;
    }
    AppLogger().debug('Drop exited ${_controller.currentPath}', tag: 'Explorer');
    if (_chromeState.handleDropExited()) {
      _refreshView(updateOptions: false);
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
    if (_chromeState.clearDropHover()) {
      _refreshView(updateOptions: false);
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
    _chromeState.updateTabOptions(controller);
  }
}
