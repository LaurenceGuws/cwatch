import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

import 'docker_tab_builder.dart';
import 'docker_workspace_controller.dart';

class DockerViewRuntime {
  const DockerViewRuntime({
    required this.docker,
    required this.viewController,
    required this.distroCacheController,
    required this.trashManager,
    required this.portForwardService,
    required this.tabBuilder,
    required this.workspaceController,
    required this.shellCallbacks,
  });

  final DockerClientService docker;
  final DockerViewController viewController;
  final DistroCacheController distroCacheController;
  final ExplorerTrashManager trashManager;
  final PortForwardService portForwardService;
  final DockerTabBuilder tabBuilder;
  final DockerWorkspaceController workspaceController;
  final DockerShellCallbacks shellCallbacks;

  static DockerViewController createController({
    required DockerClientService docker,
  }) {
    return DockerViewController(docker: docker);
  }

  static DockerViewRuntime create({
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    required SshShellFactory shellFactory,
    required Future<List<SshHost>> hostsFuture,
    required DockerClientService docker,
    required DockerViewController viewController,
    required DistroCacheController distroCacheController,
    required ExplorerTrashManager trashManager,
    required PortForwardService portForwardService,
    required DockerShellCallbacks shellCallbacks,
    required DockerTabBuilder tabBuilder,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    final workspaceController = DockerWorkspaceController(
      settingsController: settingsController,
      workspaceRootController: WorkspaceRootController(
        settingsController: settingsController,
      ),
      baseTabBuilder: baseTabBuilder,
    );

    return DockerViewRuntime(
      docker: docker,
      viewController: viewController,
      distroCacheController: distroCacheController,
      trashManager: trashManager,
      portForwardService: portForwardService,
      tabBuilder: tabBuilder,
      workspaceController: workspaceController,
      shellCallbacks: shellCallbacks,
    );
  }

  void dispose() {
    workspaceController.dispose();
    viewController.dispose();
    portForwardService.dispose();
  }
}
