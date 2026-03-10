import 'package:flutter/material.dart';

import 'package:cwatch/view/features/servers/server_workspace_ui_adapter.dart';
import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

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
}
