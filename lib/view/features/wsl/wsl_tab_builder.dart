import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/terminal_session_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/wsl/models/wsl_tab_data.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/wsl_workspace_state.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/views/shared/tabs/terminal/terminal_tab.dart';

class WslTabBuilder {
  const WslTabBuilder({required this.settingsController});

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
    required TerminalSessionController sessionController,
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
          name: 'wsl',
          hostname: '',
          port: 0,
          available: true,
        ),
        sessionController: sessionController,
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
