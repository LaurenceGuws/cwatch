import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';

import 'package:cwatch/controller/adapters/docker_overview_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_overview_actions_controller.dart';

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
