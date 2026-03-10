import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
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
    required DockerClientService docker,
    required DockerViewController viewController,
    required DistroCacheController distroCacheController,
    required ExplorerTrashManager trashManager,
    required PortForwardService portForwardService,
    required DockerShellCallbacks shellCallbacks,
    required DockerTabBuilder tabBuilder,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    final workspaceRootController = WorkspaceRootController(
      settingsController: settingsController,
    );
    final workspaceController = DockerWorkspaceController(
      settingsController: settingsController,
      workspaceRootController: workspaceRootController,
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
}
