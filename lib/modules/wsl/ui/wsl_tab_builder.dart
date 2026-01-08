import 'package:flutter/material.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/wsl_workspace_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/terminal/terminal_tab.dart';

import 'package:cwatch/shared/theme/nerd_fonts.dart';

class WslTabBuilder {
  const WslTabBuilder({
    required this.settingsController,
  });

  final AppSettingsController settingsController;

  WorkspaceTab picker({required String id, Widget? body}) {
    return WorkspaceTab(
      id: id,
      title: 'WSL',
      label: 'WSL',
      icon: NerdIcon.penguin.data,
      body: body ?? const SizedBox.shrink(),
      canDrag: false,
      canRename: false,
      workspaceState: WslTabData(
        kind: WslTabKind.distroList,
        persistedState: TabState(id: id, kind: WslTabKind.distroList.name),
      ),
    );
  }

  WorkspaceTab terminal({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required String distroName,
    required RemoteShellService shellService,
    VoidCallback? onExit,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  }) {
    final controller = TabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: TerminalTab(
        host: const SshHost(
            name: 'wsl', hostname: '', port: 0, available: true), // Placeholder
        shellService: shellService,
        settingsController: settingsController,
        onExit: onExit,
        optionsController: controller,
        onOpenEditorTab: onOpenEditorTab,
      ),
      workspaceState: WslTabData(
        kind: WslTabKind.terminal,
        persistedState: TabState(
          id: id,
          kind: WslTabKind.terminal.name,
          title: title,
          label: label,
          extra: {'distroName': distroName},
        ),
      ),
      optionsController: controller,
    );
  }
}

class WslTabData {
  const WslTabData({required this.kind, required this.persistedState});

  final WslTabKind kind;
  final TabState persistedState;
}
