import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/view/features/settings/settings/explorer_settings_controls.dart';

import 'explorer_chrome_scaffold.dart';
import 'file_explorer_tab_presenter.dart';
import 'path_navigator.dart';

class FileExplorerTabSurface extends StatelessWidget {
  const FileExplorerTabSurface({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.presenter,
    required this.content,
    required this.onToggleSettings,
    required this.onLoadPath,
    required this.onNavigateToSubdirectory,
    required this.onShowMenu,
    required this.onDragEntered,
    required this.onDragUpdated,
    required this.onDragExited,
    required this.onDragDone,
    required this.supportsDesktopDrop,
    required this.dropHover,
  });

  final FileExplorerController controller;
  final SettingsController settingsController;
  final FileExplorerTabPresenter presenter;
  final Widget content;
  final VoidCallback onToggleSettings;
  final ValueChanged<String> onLoadPath;
  final VoidCallback onNavigateToSubdirectory;
  final Future<String?> Function(
    RelativeRect position,
    List<PopupMenuEntry<String>> items,
    BoxConstraints constraints,
  )
  onShowMenu;
  final void Function(DropEventDetails) onDragEntered;
  final void Function(DropEventDetails) onDragUpdated;
  final void Function() onDragExited;
  final Future<void> Function(DropDoneDetails) onDragDone;
  final bool supportsDesktopDrop;
  final bool dropHover;

  Widget _buildPathNavigator(BuildContext context) {
    return PathNavigator(
      currentPath: controller.currentPath,
      pathHistory: controller.state.pathHistory,
      onPathChanged: onLoadPath,
      showBreadcrumbs: controller.state.showBreadcrumbs,
      onShowBreadcrumbsChanged: controller.setShowBreadcrumbs,
      onNavigateToSubdirectory: onNavigateToSubdirectory,
      onPrefetchPath: controller.prefetchPath,
      searchActive: controller.state.searchActive,
      searchQuery: controller.state.searchQuery,
      onSearchActiveChanged: (value) {
        controller.setSearchActive(value);
      },
      onSearchQueryChanged: controller.setSearchQuery,
      onSearchSubmitted: (query) {
        controller.searchCurrentPath(query);
      },
      searchInProgress:
          controller.state.loading &&
          controller.state.searchActive &&
          controller.state.searchQuery.trim().isNotEmpty,
      onSearchCancelled: controller.cancelSearch,
      searchInclude: controller.state.searchInclude,
      searchExclude: controller.state.searchExclude,
      searchMatchCase: controller.state.searchMatchCase,
      searchMatchWholeWord: controller.state.searchMatchWholeWord,
      onSearchIncludeChanged: controller.setSearchInclude,
      onSearchExcludeChanged: controller.setSearchExclude,
      onSearchMatchCaseChanged: controller.toggleSearchMatchCase,
      onSearchMatchWholeWordChanged: controller.toggleSearchMatchWholeWord,
      searchContents: controller.state.searchContents,
      onSearchContentsChanged: controller.setSearchContents,
      showRowHeightControl: controller.state.showRowHeightControl,
      rowHeight: controller.state.rowHeight,
      onRowHeightChanged: controller.setRowHeight,
      onShowMenu: onShowMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerChromeScaffold(
      pathNavigator: _buildPathNavigator(context),
      content: content,
      showSettings: presenter.showSettings,
      settings: ExplorerSettingsControls(
        settings: settingsController.settings,
        settingsController: settingsController,
      ),
      onCloseSettings: onToggleSettings,
      supportsDesktopDrop: supportsDesktopDrop,
      dropEnabled: true,
      dropHover: dropHover,
      onDragEntered: onDragEntered,
      onDragUpdated: onDragUpdated,
      onDragExited: (_) => onDragExited(),
      onDragDone: onDragDone,
    );
  }
}
