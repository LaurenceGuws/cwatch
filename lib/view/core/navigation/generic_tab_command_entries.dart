import 'package:flutter/foundation.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';

import 'command_palette_registry.dart';

List<CommandPaletteEntry> buildGenericTabCommandEntries({
  required String moduleId,
  required WorkspaceTab? selectedTab,
  required VoidCallback onNewTab,
  required VoidCallback onCloseTab,
  VoidCallback? onRenameTab,
}) {
  final entries = <CommandPaletteEntry>[];

  if (selectedTab != null) {
    final options = selectedTab.optionsController?.value ?? const <TabChipOption>[];
    entries.addAll(
      options.map(
        (option) => CommandPaletteEntry(
          id: '$moduleId:tabOption:${option.label}',
          label: option.label,
          category: 'Tab options',
          onSelected: option.onSelected,
          icon: option.icon,
        ),
      ),
    );

    if (onRenameTab != null) {
      entries.add(
        CommandPaletteEntry(
          id: '$moduleId:renameTab',
          label: 'Rename tab',
          category: 'Tabs',
          onSelected: onRenameTab,
        ),
      );
    }

    entries.add(
      CommandPaletteEntry(
        id: '$moduleId:closeTab',
        label: 'Close tab',
        category: 'Tabs',
        onSelected: onCloseTab,
      ),
    );
  }

  entries.add(
    CommandPaletteEntry(
      id: '$moduleId:newTab',
      label: 'New tab',
      category: 'Tabs',
      onSelected: onNewTab,
    ),
  );

  return entries;
}
