import 'package:flutter/material.dart';

import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/controller/di/bindings/ssh_shell_factory_binding.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/view/features/servers/server_workspace_ui_adapter.dart';
import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/view/features/servers/server_tab_builder.dart';
import 'package:cwatch/view/features/servers/server_workspace_controller.dart';
import 'package:cwatch/view/features/servers/server_workspace_runtime.dart';

class ServerWorkspaceBinding {
  const ServerWorkspaceBinding();

  ServerWorkspaceUiAdapter createUiAdapter({required BuildContext context}) {
    return ServerWorkspaceUiAdapter(context: context);
  }

  ServerPortForwardController createPortForwardController({
    required BuildContext context,
    required PortForwardService portForwardService,
    required AppSettingsController settingsController,
    required BuiltInSshKeyService keyService,
    ServerWorkspaceUiAdapter? uiAdapter,
  }) {
    final adapter = uiAdapter ?? createUiAdapter(context: context);
    return ServerPortForwardController(
      portForwardService: portForwardService,
      settingsController: settingsController,
      keyService: keyService,
      uiAdapter: adapter,
    );
  }

  ServerWorkspaceRuntime createRuntime({
    required BuildContext context,
    required AppSettingsController appSettingsController,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
    required Future<List<SshHost>> Function() hostsLoader,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    final uiAdapter = createUiAdapter(context: context);
    final authCoordinator = uiAdapter.buildSshAuthCoordinator(
      keyService: keyService,
    );
    final shellFactory = const SshShellFactoryBinding().create(
      settingsController: appSettingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
    final distroManager = HostDistroManager(
      settingsController: appSettingsController,
      shellFactory: shellFactory,
    );
    final portForwardService = PortForwardService()
      ..setAuthCoordinator(shellFactory.authCoordinator);
    final portForwardController = createPortForwardController(
      context: context,
      portForwardService: portForwardService,
      settingsController: appSettingsController,
      keyService: keyService,
      uiAdapter: uiAdapter,
    );
    final settingsController = const SettingsBinding().createController(
      settingsController: appSettingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      uiAdapter: const SettingsBinding().createUiAdapter(context: context),
    );
    final tabBuilder = ServerTabBuilder(
      settingsController: appSettingsController,
      trashManager: ExplorerTrashManager(),
      shellServiceForHost: (host) => shellFactory.forHost(host),
      keyService: keyService,
      hostsFuture: hostsFuture,
    );
    final workspaceController = ServerWorkspaceController(
      settingsController: appSettingsController,
      hostsLoader: hostsLoader,
      baseTabBuilder: baseTabBuilder,
    );
    return ServerWorkspaceRuntime(
      uiAdapter: uiAdapter,
      shellFactory: shellFactory,
      distroManager: distroManager,
      portForwardService: portForwardService,
      portForwardController: portForwardController,
      settingsController: settingsController,
      tabBuilder: tabBuilder,
      workspaceController: workspaceController,
    );
  }
}
