import 'package:flutter/material.dart';

import 'home_shell_state.dart';

enum SidebarOption { hide, pinLeft, pinRight, pinBottom, dynamicPlacement }

class HomeShellSidebarMenu {
  static Future<SidebarOption?> show({
    required BuildContext context,
    required Offset position,
    required bool sidebarCollapsed,
    required SidebarPlacement sidebarPlacement,
  }) {
    return showMenu<SidebarOption>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        CheckedPopupMenuItem(
          value: SidebarOption.hide,
          checked: sidebarCollapsed,
          child: const Text('Hide sidebar'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: SidebarOption.pinLeft,
          checked:
              !sidebarCollapsed && sidebarPlacement == SidebarPlacement.left,
          child: const Text('Pin to left'),
        ),
        CheckedPopupMenuItem(
          value: SidebarOption.pinRight,
          checked:
              !sidebarCollapsed && sidebarPlacement == SidebarPlacement.right,
          child: const Text('Pin to right'),
        ),
        CheckedPopupMenuItem(
          value: SidebarOption.pinBottom,
          checked:
              !sidebarCollapsed && sidebarPlacement == SidebarPlacement.bottom,
          child: const Text('Pin to bottom'),
        ),
        CheckedPopupMenuItem(
          value: SidebarOption.dynamicPlacement,
          checked:
              !sidebarCollapsed && sidebarPlacement == SidebarPlacement.dynamic,
          child: const Text('Dynamic placement'),
        ),
      ],
    );
  }
}
