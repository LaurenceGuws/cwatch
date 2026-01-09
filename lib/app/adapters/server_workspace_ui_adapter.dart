import 'package:flutter/material.dart';

import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/shared/widgets/port_forward_dialog.dart' as port_forward;

import 'ssh_auth_prompter.dart';

class ServerWorkspaceUiAdapter {
  ServerWorkspaceUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<List<PortForwardRequest>?> promptPortForwardDialog({
    required String title,
    required List<PortForwardRequest> requests,
    required Future<bool> Function(int port) portValidator,
    required List<ActivePortForward> active,
  }) {
    if (!context.mounted) return Future.value(null);
    return port_forward.showPortForwardDialog(
      context: context,
      title: title,
      requests: requests,
      portValidator: portValidator,
      active: active,
    );
  }

  SshAuthCoordinator buildSshAuthCoordinator({
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthPrompter.forContext(context: context, keyService: keyService);
  }
}
