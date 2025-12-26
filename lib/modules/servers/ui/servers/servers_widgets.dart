import 'package:flutter/material.dart';

import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/action_picker.dart';

/// Error state widget for displaying errors
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(NerdIcon.alert.data, color: scheme.error, size: 48),
          SizedBox(height: spacing.xl),
          Text(
            'Failed to read SSH config',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.md),
          Text(error, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Dialog for picking a server action
class ActionPickerDialog {
  /// Show dialog to pick an action for a host
  static Future<ServerAction?> show(BuildContext context, SshHost host) {
    return ActionPicker.show<ServerAction>(
      context: context,
      title: 'Actions for ${host.name}',
      options: [
        ActionOption(
          title: 'Open File Explorer',
          value: ServerAction.fileExplorer,
          icon: NerdIcon.folderOpen.data,
        ),
        ActionOption(
          title: 'Connectivity Dashboard',
          subtitle: 'Latency, jitter & throughput',
          value: ServerAction.connectivity,
          icon: NerdIcon.accessPoint.data,
        ),
        ActionOption(
          title: 'Resources Dashboard',
          subtitle: 'CPU, memory, disks, processes',
          value: ServerAction.resources,
          icon: Icons.memory,
        ),
        ActionOption(
          title: 'Terminal',
          subtitle: 'Interactive shell for this server',
          value: ServerAction.terminal,
          icon: NerdIcon.terminal.data,
        ),
        ActionOption(
          title: 'Port forwarding',
          subtitle: 'Forward remote ports over SSH',
          value: ServerAction.portForward,
          icon: Icons.link,
        ),
      ],
    );
  }
}
