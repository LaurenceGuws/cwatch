import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/core/tabs/tab_host_view.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';

/// Reusable shell that wires up a tab host with a shared tab view registry.
class TabbedWorkspaceShell<T> extends StatelessWidget {
  const TabbedWorkspaceShell({
    super.key,
    required this.controller,
    required this.registry,
    required this.buildChip,
    required this.buildBody,
    this.tabBarHeight = 36,
    this.leading,
    this.onAddTab,
    this.onReorder,
    this.showTabBar,
    this.enableWindowDrag = true,
  });

  final TabHostController<T> controller;
  final TabViewRegistry<T> registry;
  final double tabBarHeight;
  final Widget? leading;
  final void Function()? onAddTab;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final ValueListenable<bool>? showTabBar;
  final Widget Function(BuildContext context, int index, T tab) buildChip;
  final Widget Function(T tab) buildBody;
  final bool enableWindowDrag;

  @override
  Widget build(BuildContext context) {
    return TabHostView<T>(
      controller: controller,
      tabBarHeight: tabBarHeight,
      leading: leading,
      onAddTab: onAddTab,
      onReorder: onReorder,
      showTabBar: showTabBar,
      enableWindowDrag: enableWindowDrag,
      buildChip: buildChip,
      buildBody: (tab) => registry.widgetFor(tab, () => buildBody(tab)),
      tabId: registry.tabId,
    );
  }
}
