import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/port_forward_dialog.dart' as port_forward;

import 'ssh_auth_prompter.dart';

class DockerOverviewUiAdapter {
  DockerOverviewUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> showLogsDialog({
    required String title,
    required String logs,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(
                logs.isNotEmpty ? logs : 'No logs available.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showErrorDialog({
    required String title,
    required String message,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<PortForwardRequest>?> showPortForwardDialog({
    required String title,
    required List<PortForwardRequest> requests,
    required Future<bool> Function(int port) portValidator,
    required List<ActivePortForward> active,
  }) async {
    if (!context.mounted) return null;
    return port_forward.showPortForwardDialog(
      context: context,
      title: title,
      requests: requests,
      portValidator: portValidator,
      active: active,
    );
  }

  Future<void> copyToClipboard(
    String value, {
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    showSnackBar(successMessage);
  }

  SshAuthCoordinator buildSshAuthCoordinator({
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthPrompter.forContext(context: context, keyService: keyService);
  }
}

class DockerOverviewMenus {
  DockerOverviewMenus({required this.icons, required this.uiAdapter});

  final AppIcons icons;
  final DockerOverviewUiAdapter uiAdapter;

  PopupMenuItem<String> menuItem(
    String value,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final scheme = Theme.of(uiAdapter.context).colorScheme;
    final resolved = color ?? scheme.primary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: resolved),
          const SizedBox(width: 8),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }

  Future<void> showItemMenu({
    required Offset globalPosition,
    required String title,
    required Map<String, String> details,
    required String copyValue,
    required String copyLabel,
    List<PopupMenuEntry<String>> extraActions = const [],
    Future<void> Function(String action)? onAction,
  }) async {
    if (!uiAdapter.mounted) return;
    final context = uiAdapter.context;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        menuItem('copy', 'Copy $copyLabel', icons.copy),
        menuItem('details', 'Details', Icons.info_outline),
        ...extraActions,
      ],
    );

    if (!uiAdapter.mounted) return;
    if (selected == 'copy') {
      await uiAdapter.copyToClipboard(
        copyValue,
        successMessage: '$copyLabel copied to clipboard.',
      );
    } else if (selected == 'details') {
      await _showDetailsDialog(title: title, details: details);
    } else if (selected != null && onAction != null) {
      await onAction(selected);
    }
  }

  Future<void> _showDetailsDialog({
    required String title,
    required Map<String, String> details,
  }) async {
    if (!uiAdapter.mounted) return;
    final context = uiAdapter.context;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final spacing = dialogContext.appTheme.spacing;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(bottom: spacing.md),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: Theme.of(dialogContext).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
