import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';

import 'docker_tab_builder.dart';
import 'docker_workspace_controller.dart';

class DockerViewRuntime {
  const DockerViewRuntime({
    required this.docker,
    required this.viewController,
    required this.trashManager,
    required this.portForwardService,
    required this.tabBuilder,
    required this.workspaceController,
    required this.shellCallbacks,
  });

  final DockerClientService docker;
  final DockerViewController viewController;
  final ExplorerTrashManager trashManager;
  final PortForwardService portForwardService;
  final DockerTabBuilder tabBuilder;
  final DockerWorkspaceController workspaceController;
  final DockerShellCallbacks shellCallbacks;

  void dispose() {
    workspaceController.dispose();
    viewController.dispose();
    portForwardService.dispose();
  }
}
