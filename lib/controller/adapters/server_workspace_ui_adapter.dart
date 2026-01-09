import 'package:flutter/material.dart';

import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/view/features/servers/servers/add_server_dialog.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/view/shared/widgets/port_forward_dialog.dart'
    as port_forward;

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

  Future<CustomSshHost?> showAddServerDialog({
    required BuiltInSshKeyService keyService,
    required List<String> existingNames,
  }) {
    if (!context.mounted) return Future.value(null);
    return showDialog<CustomSshHost>(
      context: context,
      builder: (dialogContext) =>
          AddServerDialog(keyService: keyService, existingNames: existingNames),
    );
  }

  Future<String?> showRenameTabDialog({required String initialName}) async {
    if (!context.mounted) return null;
    final controller = TextEditingController(text: initialName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: AlertDialog(
            title: const Text('Rename tab'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tab name'),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }

  SshAuthCoordinator buildSshAuthCoordinator({
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthPrompter.forContext(context: context, keyService: keyService);
  }
}
