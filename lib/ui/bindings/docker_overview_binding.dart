import 'package:flutter/material.dart';

import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/modules/docker/ui/docker_tab_builder.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_overview_controller.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/models/ssh_host.dart';

import '../../app/adapters/docker_overview_ui_adapter.dart';
import '../../app/controllers/docker_overview_actions_controller.dart';

class DockerOverviewBinding {
  const DockerOverviewBinding();

  DockerOverviewUiAdapter createUiAdapter({required BuildContext context}) {
    return DockerOverviewUiAdapter(context: context);
  }

  DockerOverviewController createController({
    required DockerClientService docker,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
  }) {
    return DockerOverviewController(
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
    );
  }

  DockerOverviewActionsController createActionsController({
    required BuildContext context,
    required DockerOverviewController controller,
    required DockerClientService docker,
    required String? contextName,
    required SshHost? remoteHost,
    required RemoteShellService? shellService,
    required DockerTabBuilder tabBuilder,
    required void Function(WorkspaceTab tab)? onOpenTab,
    required void Function(String tabId)? onCloseTab,
    required AppSettingsController settingsController,
    required PortForwardService portForwardService,
    required BuiltInSshKeyService keyService,
    DockerOverviewUiAdapter? uiAdapter,
  }) {
    final adapter = uiAdapter ?? createUiAdapter(context: context);
    return DockerOverviewActionsController(
      controller: controller,
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      tabBuilder: tabBuilder,
      onOpenTab: onOpenTab,
      onCloseTab: onCloseTab,
      settingsController: settingsController,
      portForwardService: portForwardService,
      keyService: keyService,
      uiAdapter: adapter,
    );
  }
}
