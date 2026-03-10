import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/di/bindings/docker_client_service_binding.dart';
import 'package:cwatch/controller/di/bindings/docker_shell_callbacks_binding.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_view_runtime.dart';
import 'package:cwatch/view/features/docker/docker_workspace_controller.dart';

class DockerViewBinding {
  const DockerViewBinding();

  DockerViewController createController({required DockerClientService docker}) {
    return DockerViewController(docker: docker);
  }

  DockerViewRuntime createRuntime({
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    required SshShellFactory shellFactory,
    required Future<List<SshHost>> hostsFuture,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    final workspaceRootController = WorkspaceRootController(
      settingsController: settingsController,
    );
    final docker = const DockerClientServiceBinding().create();
    final viewController = createController(docker: docker);
    final trashManager = ExplorerTrashManager();
    final portForwardService = PortForwardService()
      ..setAuthCoordinator(shellFactory.authCoordinator);
    final shellCallbacks = const DockerShellCallbacksBinding().create(
      shellFactory: shellFactory,
    );
    final tabBuilder = DockerTabBuilder(
      docker: docker,
      settingsController: settingsController,
      trashManager: trashManager,
      keyService: keyService,
      portForwardService: portForwardService,
      hostsFuture: hostsFuture,
    );
    final workspaceController = DockerWorkspaceController(
      settingsController: settingsController,
      workspaceRootController: workspaceRootController,
      baseTabBuilder: baseTabBuilder,
    );
    return DockerViewRuntime(
      docker: docker,
      viewController: viewController,
      trashManager: trashManager,
      portForwardService: portForwardService,
      tabBuilder: tabBuilder,
      workspaceController: workspaceController,
      shellCallbacks: shellCallbacks,
    );
  }
}
