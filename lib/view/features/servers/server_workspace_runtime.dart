import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

import 'server_tab_builder.dart';
import 'server_workspace_controller.dart';
import 'server_workspace_ui_adapter.dart';

class ServerWorkspaceRuntime {
  const ServerWorkspaceRuntime({
    required this.uiAdapter,
    required this.shellFactory,
    required this.distroManager,
    required this.portForwardService,
    required this.portForwardController,
    required this.settingsController,
    required this.tabBuilder,
    required this.workspaceController,
  });

  final ServerWorkspaceUiAdapter uiAdapter;
  final SshShellFactory shellFactory;
  final HostDistroManager distroManager;
  final PortForwardService portForwardService;
  final ServerPortForwardController portForwardController;
  final SettingsController settingsController;
  final ServerTabBuilder tabBuilder;
  final ServerWorkspaceController workspaceController;

  void dispose() {
    workspaceController.dispose();
    settingsController.dispose();
    portForwardService.dispose();
  }
}
