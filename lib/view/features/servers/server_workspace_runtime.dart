import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/ssh_auth_prompter.dart';
import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';

import 'server_tab_builder.dart';
import 'server_workspace_controller.dart';
import 'server_workspace_ui_adapter.dart';

class ServerWorkspaceRuntime {
  const ServerWorkspaceRuntime({
    required this.uiAdapter,
    required this.shellFactory,
    required this.distroCacheController,
    required this.distroManager,
    required this.portForwardService,
    required this.portForwardController,
    required this.settingsController,
    required this.tabBuilder,
    required this.workspaceController,
  });

  final ServerWorkspaceUiAdapter uiAdapter;
  final SshShellFactory shellFactory;
  final DistroCacheController distroCacheController;
  final HostDistroManager distroManager;
  final PortForwardService portForwardService;
  final ServerPortForwardController portForwardController;
  final SettingsController settingsController;
  final ServerTabBuilder tabBuilder;
  final ServerWorkspaceController workspaceController;

  static ServerWorkspaceRuntime create({
    required BuildContext context,
    required AppSettingsController appSettingsController,
    required BuiltInSshKeyService keyService,
    required Future<List<SshHost>> hostsFuture,
    required Future<List<SshHost>> Function() hostsLoader,
    required ServerTabBuilder tabBuilder,
    required WorkspaceTab Function() baseTabBuilder,
  }) {
    final workspaceRootController = WorkspaceRootController(
      settingsController: appSettingsController,
    );
    final uiAdapter = ServerWorkspaceUiAdapter(context: context);
    final authCoordinator = SshAuthPrompter.forContext(
      context: context,
      keyService: keyService,
    );
    final shellFactory = SshShellFactory(
      settingsController: appSettingsController,
      keyService: keyService,
      authCoordinator: authCoordinator,
    );
    final distroCacheController = DistroCacheController(
      initialServerCache: appSettingsController.settings.serverDistroMap,
      initialDockerCache: appSettingsController.settings.dockerDistroMap,
    );
    final distroManager = HostDistroManager(
      distroCacheController: distroCacheController,
      disabledHostKeys: () => appSettingsController
          .settings
          .sshPreferences
          .disabledServerHosts
          .toSet(),
      shellFactory: shellFactory,
    );
    final portForwardService = PortForwardService()
      ..setAuthCoordinator(shellFactory.authCoordinator);
    final portForwardController = ServerPortForwardController(
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
    final workspaceController = ServerWorkspaceController(
      settingsController: appSettingsController,
      workspaceRootController: workspaceRootController,
      hostsLoader: hostsLoader,
      baseTabBuilder: baseTabBuilder,
    );

    return ServerWorkspaceRuntime(
      uiAdapter: uiAdapter,
      shellFactory: shellFactory,
      distroCacheController: distroCacheController,
      distroManager: distroManager,
      portForwardService: portForwardService,
      portForwardController: portForwardController,
      settingsController: settingsController,
      tabBuilder: tabBuilder,
      workspaceController: workspaceController,
    );
  }

  void dispose() {
    workspaceController.dispose();
    settingsController.dispose();
    portForwardService.dispose();
  }
}
