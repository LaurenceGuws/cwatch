import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/controllers/terminal_session_controller.dart';
import 'package:cwatch/controller/core/workspace/persistent_workspace_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/wsl/models/wsl_tab_data.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/wsl_workspace_state.dart';

class WslWorkspaceController
    extends PersistentWorkspaceController<WslWorkspaceState> {
  WslWorkspaceController({
    required super.settingsController,
    required super.baseTabBuilder,
  });

  @override
  WslWorkspaceState? readFromSettings(AppSettings settings) {
    return settings.wslWorkspace;
  }

  @override
  AppSettings writeToSettings(
    AppSettings current,
    WslWorkspaceState workspace,
  ) {
    return current.copyWith(wslWorkspace: workspace);
  }

  @override
  WslWorkspaceState createWorkspaceState(
    List<TabState> tabs,
    int selectedIndex,
  ) {
    return WslWorkspaceState(tabs: tabs, selectedIndex: selectedIndex);
  }

  @override
  TabState? getTabState(Object? tabData) {
    if (tabData is WslTabData) {
      return tabData.persistedState;
    }
    return null;
  }

  @override
  Future<void> restoreState() async {
    // Handled by view.
  }

  Future<void> restore({
    required WorkspaceTab Function({required String id, Widget? body})
    buildPickerTab,
    required WorkspaceTab Function({
      required String id,
      required String title,
      required String label,
      required IconData icon,
      required String distroName,
      required TerminalSessionController sessionController,
      VoidCallback? onExit,
    })
    buildTerminalTab,
    required Widget Function(String tabId) pickerBodyBuilder,
    required WslTabBuilders callbacks,
  }) async {
    final workspace = settingsController.settings.wslWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) return;
    if (!workspacePersistence.shouldRestore(workspace)) return;

    final restoredTabs = <WorkspaceTab>[];
    for (final state in workspace.tabs) {
      final tab = _createTabFromState(
        state: state,
        buildPickerTab: buildPickerTab,
        buildTerminalTab: buildTerminalTab,
        pickerBodyBuilder: pickerBodyBuilder,
        callbacks: callbacks,
      );
      if (tab != null) {
        restoredTabs.add(tab);
      }
    }

    if (restoredTabs.isNotEmpty) {
      workspacePersistence.markRestored(workspace);
      replaceAll(restoredTabs, selectedIndex: workspace.selectedIndex);
    }
  }

  WorkspaceTab? _createTabFromState({
    required TabState state,
    required WorkspaceTab Function({required String id, Widget? body})
    buildPickerTab,
    required WorkspaceTab Function({
      required String id,
      required String title,
      required String label,
      required IconData icon,
      required String distroName,
      required TerminalSessionController sessionController,
      VoidCallback? onExit,
    })
    buildTerminalTab,
    required Widget Function(String tabId) pickerBodyBuilder,
    required WslTabBuilders callbacks,
  }) {
    final wslState = _wslStateFromTab(state);
    if (wslState == null) return null;

    switch (wslState.kind) {
      case WslTabKind.distroList:
        return buildPickerTab(
          id: wslState.id,
          body: pickerBodyBuilder(wslState.id),
        );
      case WslTabKind.terminal:
        if (wslState.distroName == null) return null;
        final title = wslState.title ?? wslState.distroName!;
        final sessionController = callbacks.sessionControllerForDistro(
          wslState.distroName!,
        );
        if (sessionController == null) return null;

        return buildTerminalTab(
          id: wslState.id,
          title: title,
          label: title,
          icon: callbacks.terminalIcon,
          distroName: wslState.distroName!,
          sessionController: sessionController,
          onExit: () => callbacks.closeTab(wslState.id),
        );
    }
  }

  WslTabState? _wslStateFromTab(TabState state) {
    final kind = _wslKindFromString(state.kind);
    if (kind == null) return null;
    return WslTabState(
      id: state.id,
      kind: kind,
      distroName: state.stringExtra('distroName'),
      title: state.title ?? state.label,
    );
  }

  WslTabKind? _wslKindFromString(String raw) {
    for (final value in WslTabKind.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}

class WslTabBuilders {
  const WslTabBuilders({
    required this.terminalIcon,
    required this.sessionControllerForDistro,
    required this.closeTab,
  });

  final IconData terminalIcon;
  final TerminalSessionController? Function(String distroName)
  sessionControllerForDistro;
  final void Function(String id) closeTab;
}
