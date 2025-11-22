import 'package:flutter/material.dart';

import '../../../../models/server_action.dart';
import '../../../../models/ssh_host.dart';
import '../../../theme/nerd_fonts.dart';
import 'server_models.dart';

/// Error state widget for displaying errors
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(NerdIcon.alert.data, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to read SSH config',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Servers menu widget
class ServersMenu extends StatelessWidget {
  const ServersMenu({
    super.key,
    required this.onOpenTrash,
  });

  final VoidCallback onOpenTrash;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ServersMenuAction>(
      tooltip: 'Server options',
      icon: const Icon(Icons.settings),
      onSelected: (value) {
        switch (value) {
          case ServersMenuAction.openTrash:
            onOpenTrash();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: ServersMenuAction.openTrash,
          child: Text('Open trash tab'),
        ),
      ],
    );
  }
}

/// Dialog for picking a server action
class ActionPickerDialog {
  /// Show dialog to pick an action for a host
  static Future<ServerAction?> show(
    BuildContext context,
    SshHost host,
  ) {
    return showDialog<ServerAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Actions for ${host.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(NerdIcon.folderOpen.data),
              title: const Text('Open File Explorer'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(ServerAction.fileExplorer),
            ),
            ListTile(
              leading: Icon(NerdIcon.accessPoint.data),
              title: const Text('Connectivity Dashboard'),
              subtitle: const Text('Latency, jitter & throughput'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(ServerAction.connectivity),
            ),
            ListTile(
              leading: Icon(Icons.memory),
              title: const Text('Resources Dashboard'),
              subtitle: const Text('CPU, memory, disks, processes'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(ServerAction.resources),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
