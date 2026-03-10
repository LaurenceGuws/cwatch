import 'dart:async';

import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/generic_tab_command_entries.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_view_runtime.dart';

class DockerViewShell {
  DockerViewShell({
    required this.moduleId,
    required this.runtime,
    required this.viewController,
    required List<WorkspaceTab> Function() tabs,
    required int Function() selectedIndex,
    required WorkspaceTab Function({String? id}) buildPickerTab,
    required void Function(String tabId, WorkspaceTab tab) replaceTab,
    required void Function() addPickerTab,
    required void Function(int index) closeTab,
    required void Function(int index) renameTab,
  }) : _tabs = tabs,
       _selectedIndex = selectedIndex,
       _buildPickerTab = buildPickerTab,
       _replaceTab = replaceTab,
       _addPickerTab = addPickerTab,
       _closeTab = closeTab,
       _renameTab = renameTab;

  final String moduleId;
  final DockerViewRuntime runtime;
  final DockerViewController viewController;
  final List<WorkspaceTab> Function() _tabs;
  final int Function() _selectedIndex;
  final WorkspaceTab Function({String? id}) _buildPickerTab;
  final void Function(String tabId, WorkspaceTab tab) _replaceTab;
  final void Function() _addPickerTab;
  final void Function(int index) _closeTab;
  final void Function(int index) _renameTab;

  late final TabNavigationHandle tabNavigator = TabNavigationHandle(
    next: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      final next = (_selectedIndex() + 1) % length;
      runtime.workspaceController.select(next);
      return true;
    },
    previous: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      final prev = (_selectedIndex() - 1 + length) % length;
      runtime.workspaceController.select(prev);
      return true;
    },
  );

  late final CommandPaletteHandle commandPaletteHandle = CommandPaletteHandle(
    loader: buildCommandPaletteEntries,
  );

  Future<void> initialize() async {
    TabNavigationRegistry.instance.register(moduleId, tabNavigator);
    CommandPaletteRegistry.instance.register(moduleId, commandPaletteHandle);
    unawaited(
      viewController.loadContexts().catchError(
        (_) => const <DockerContext>[],
      ),
    );
  }

  void dispose() {
    TabNavigationRegistry.instance.unregister(moduleId, tabNavigator);
    CommandPaletteRegistry.instance.unregister(moduleId, commandPaletteHandle);
  }

  void refreshContexts() {
    viewController.refreshContexts();
    final pickerIds = _tabs()
        .where(
          (t) =>
              (t.workspaceState as DockerTabData?)?.kind == DockerTabKind.picker,
        )
        .map((t) => t.id)
        .toList();

    runtime.workspaceController.runWithoutPersist(() {
      for (final id in pickerIds) {
        _replaceTab(id, _buildPickerTab(id: id));
      }
    });

    unawaited(runtime.workspaceController.persistState());
  }

  List<CommandPaletteEntry> buildCommandPaletteEntries() {
    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    return buildGenericTabCommandEntries(
      moduleId: moduleId,
      selectedTab: tabs.isNotEmpty ? tabs[selectedIndex] : null,
      onNewTab: _addPickerTab,
      onCloseTab: () => _closeTab(selectedIndex),
      onRenameTab: () => _renameTab(selectedIndex),
    );
  }

  void addEnginePickerTab() {
    _addPickerTab();
  }
}
