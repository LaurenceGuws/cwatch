import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/view/shared/widgets/input_help_dialog.dart';
import '../tabs/tab_bar_visibility.dart';
import 'command_palette_registry.dart';

class HomeShellCommandPalette {
  static List<CommandPaletteEntry> buildGlobalEntries({
    required BuildContext context,
    required AppSettingsController settingsController,
    required String moduleId,
    required bool sidebarCollapsed,
    required VoidCallback focusNextTab,
    required VoidCallback focusPreviousTab,
    required VoidCallback focusNextDestination,
    required VoidCallback focusPreviousDestination,
    required VoidCallback toggleSidebar,
    required VoidCallback showSidebar,
    required VoidCallback hideSidebar,
    bool showDeveloperEntries = false,
    Future<void> Function()? runZideFfiSmoke,
  }) {
    final entries = <CommandPaletteEntry>[
      CommandPaletteEntry(
        id: 'global:nextTab',
        label: 'Next tab',
        category: 'Navigation',
        onSelected: focusNextTab,
        icon: Icons.arrow_forward,
      ),
      CommandPaletteEntry(
        id: 'global:previousTab',
        label: 'Previous tab',
        category: 'Navigation',
        onSelected: focusPreviousTab,
        icon: Icons.arrow_back,
      ),
      CommandPaletteEntry(
        id: 'global:focusNextView',
        label: 'Focus next view',
        category: 'Navigation',
        onSelected: focusNextDestination,
        icon: Icons.arrow_downward,
      ),
      CommandPaletteEntry(
        id: 'global:focusPreviousView',
        label: 'Focus previous view',
        category: 'Navigation',
        onSelected: focusPreviousDestination,
        icon: Icons.arrow_upward,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:toggle',
        label: sidebarCollapsed ? 'Show sidebar' : 'Hide sidebar',
        category: 'Chrome',
        onSelected: toggleSidebar,
        icon: sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:show',
        label: 'Show sidebar',
        category: 'Chrome',
        onSelected: showSidebar,
        icon: Icons.chevron_right,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:hide',
        label: 'Hide sidebar',
        category: 'Chrome',
        onSelected: hideSidebar,
        icon: Icons.chevron_left,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:toggleBar',
        label: TabBarVisibilityController.instance.value
            ? 'Hide tab bar'
            : 'Show tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.toggle,
        icon: Icons.tab,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:showBar',
        label: 'Show tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.show,
        icon: Icons.visibility,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:hideBar',
        label: 'Hide tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.hide,
        icon: Icons.visibility_off,
      ),
      CommandPaletteEntry(
        id: 'global:help:input',
        label: 'Help: input & shortcuts',
        category: 'Help',
        description:
            'Show active shortcuts and gestures for the current context.',
        onSelected: () => showInputHelpDialog(
          context,
          settings: settingsController.settings,
          moduleId: moduleId,
        ),
        icon: Icons.info_outline,
      ),
    ];
    if (showDeveloperEntries && runZideFfiSmoke != null) {
      entries.add(
        CommandPaletteEntry(
          id: 'global:developer:zideSmoke',
          label: 'Developer: run Zide FFI smoke',
          category: 'Developer',
          description: 'Runs terminal/editor beta FFI smoke checks.',
          onSelected: runZideFfiSmoke,
          icon: Icons.science_outlined,
        ),
      );
    }
    return entries;
  }

  static Future<List<CommandPaletteEntry>> loadModuleEntries({
    required String moduleId,
  }) async {
    final handle = CommandPaletteRegistry.instance.forModule(moduleId);
    if (handle == null) {
      return const [];
    }

    return Future<List<CommandPaletteEntry>>.value(handle.loader());
  }
}
