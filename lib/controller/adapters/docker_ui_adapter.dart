import 'package:flutter/material.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/features/docker/models/remote_docker_status.dart';
import 'package:cwatch/view/shared/widgets/operation_progress_popup.dart';

class DockerUiAdapter {
  DockerUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  Future<void> showRemoteScanDialog({
    required void Function() onCancel,
    required ValueNotifier<List<SshHost>> hostsListenable,
    required ValueNotifier<List<RemoteDockerStatus>> statusesListenable,
    required ValueNotifier<bool> scanningListenable,
    required Future<void> Function() onComplete,
  }) async {
    if (!context.mounted) return;
    bool dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final spacing = context.appTheme.spacing;
        return Stack(
          children: [
            // Transparent barrier that doesn't block interaction
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  // Allow dismissing by tapping outside
                  if (dialogOpen) {
                    onCancel();
                    dialogOpen = false;
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
            // Floating widget in bottom right corner
            Positioned(
              bottom: spacing.lg,
              right: spacing.lg,
              child: Material(
                color: Colors.transparent,
                child: ValueListenableBuilder<bool>(
                  valueListenable: scanningListenable,
                  builder: (context, scanning, _) {
                    return ValueListenableBuilder<List<SshHost>>(
                      valueListenable: hostsListenable,
                      builder: (context, hosts, _) {
                        return ValueListenableBuilder<List<RemoteDockerStatus>>(
                          valueListenable: statusesListenable,
                          builder: (context, statuses, _) {
                            final statusByHost = {
                              for (final status in statuses) status.host.name: status,
                            };
                            SshHost? pendingHost;
                            for (final host in hosts) {
                              if (!statusByHost.containsKey(host.name)) {
                                pendingHost = host;
                                break;
                              }
                            }
                            final completed = statuses.length.clamp(0, hosts.length);
                            final progress = hosts.isEmpty
                                ? 0.0
                                : completed / hosts.length.toDouble();
                            final subtitle = scanning
                                ? 'Checking remote hosts for Docker availability...'
                                : 'Scan complete';
                            final currentItem = scanning
                                ? (pendingHost != null
                                      ? 'Scanning ${pendingHost.name}…'
                                      : (hosts.isEmpty ? null : 'Finalizing…'))
                                : null;
                            return OperationProgressPopup(
                              title: 'Scanning servers for Docker',
                              subtitle: subtitle,
                              completed: completed,
                              total: hosts.length,
                              progress: progress,
                              currentItem: currentItem,
                              icon: Icons.storage,
                              onCancel: () {
                                onCancel();
                                dialogOpen = false;
                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    await onComplete();
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
