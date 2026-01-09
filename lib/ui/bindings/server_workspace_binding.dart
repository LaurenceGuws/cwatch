import 'package:flutter/material.dart';

import 'package:cwatch/app/adapters/server_workspace_ui_adapter.dart';
import 'package:cwatch/app/controllers/server_port_forward_controller.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';

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
