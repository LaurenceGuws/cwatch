import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/view/core/tabs/workspace_tab_chip_builder.dart';
import 'package:cwatch/view/features/servers/servers/server_models.dart';

import 'server_workspace_controller.dart';

class ServerWorkspaceTabSurface extends StatelessWidget {
  const ServerWorkspaceTabSurface({
    super.key,
    required this.controller,
    required this.registry,
    required this.leading,
    required this.useSystemDecorations,
    required this.selectedTabIndex,
    required this.showListSettings,
    required this.onSelectTab,
    required this.onAddTab,
    required this.onRenameTab,
    required this.onOpenAddServerDialog,
    required this.onReloadServerList,
    required this.onToggleListSettings,
    required this.closeWarningForTab,
  });

  final ServerWorkspaceController controller;
  final TabViewRegistry<WorkspaceTab> registry;
  final Widget? leading;
  final bool useSystemDecorations;
  final int selectedTabIndex;
  final bool showListSettings;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onAddTab;
  final ValueChanged<int> onRenameTab;
  final VoidCallback onOpenAddServerDialog;
  final VoidCallback onReloadServerList;
  final VoidCallback onToggleListSettings;
  final TabCloseWarning? Function(WorkspaceTab tab) closeWarningForTab;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return Column(
      children: [
        Expanded(
          child: Material(
            color: appTheme.section.toolbarBackground,
            child: TabbedWorkspaceShell<WorkspaceTab>(
              controller: controller,
              registry: registry,
              tabBarHeight: 36,
              showTabBar: TabBarVisibilityController.instance,
              enableWindowDrag: !useSystemDecorations,
              leading: leading,
              onReorder: controller.reorder,
              onAddTab: onAddTab,
              buildChip: (context, index, tab) => _buildChip(index, tab),
              buildBody: (tab) => tab.body,
            ),
          ),
        ),
        Padding(
          padding: appTheme.spacing.inset(horizontal: 2, vertical: 0),
          child: Divider(height: 1, color: appTheme.section.divider),
        ),
      ],
    );
  }

  Widget _buildChip(int index, WorkspaceTab tab) {
    return ValueListenableBuilder<List<TabChipOption>>(
      key: ValueKey(tab.id),
      valueListenable: tab.optionsController ?? ValueNotifier([]),
      builder: (context, options, _) {
        final data = tab.workspaceState as ServerTabData?;
        final host = data?.host ?? const PlaceholderHost();
        final chipOptions = [
          ...options,
          TabChipOption(
            label: 'Add server',
            icon: Icons.add,
            onSelected: onOpenAddServerDialog,
          ),
          TabChipOption(
            label: 'Reload server list',
            icon: NerdIcon.refresh.data,
            onSelected: onReloadServerList,
          ),
          TabChipOption(
            label: showListSettings ? 'Hide list settings' : 'List settings',
            icon: Icons.settings,
            onSelected: onToggleListSettings,
          ),
        ];

        return WorkspaceTabChipBuilder(
          tab: tab,
          selected: index == selectedTabIndex,
          host: host,
          onSelect: () => onSelectTab(index),
          onClose: () => controller.closeTab(index),
          onRename: () => onRenameTab(index),
          index: index,
          canRename: tab.canRename,
          canDrag: tab.canDrag,
          extraOptions: chipOptions,
          closeWarning: closeWarningForTab(tab),
        );
      },
    );
  }
}
