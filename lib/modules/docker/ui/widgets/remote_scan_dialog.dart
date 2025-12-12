import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'docker_engine_picker.dart';
import 'package:cwatch/models/ssh_host.dart';

class RemoteScanDialog extends StatelessWidget {
  const RemoteScanDialog({
    super.key,
    required this.onCancel,
    required this.hostsListenable,
    required this.statusesListenable,
    required this.scanningListenable,
  });

  final VoidCallback onCancel;
  final ValueListenable<List<SshHost>> hostsListenable;
  final ValueListenable<List<RemoteDockerStatus>> statusesListenable;
  final ValueListenable<bool> scanningListenable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scanning servers for Docker'),
      content: ValueListenableBuilder<bool>(
        valueListenable: scanningListenable,
        builder: (context, scanning, _) {
          return ValueListenableBuilder<List<SshHost>>(
            valueListenable: hostsListenable,
            builder: (context, hosts, _) {
              return ValueListenableBuilder<List<RemoteDockerStatus>>(
                valueListenable: statusesListenable,
                builder: (context, statuses, _) {
                  final statusByHost = {
                    for (final s in statuses) s.host.name: s,
                  };
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            if (scanning) const CircularProgressIndicator(),
                            if (scanning) const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Checking remote hosts for Docker availability...',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        height: 320,
                        child: ListView.builder(
                          itemCount: hosts.length,
                          itemBuilder: (context, index) {
                            final host = hosts[index];
                            final status = statusByHost[host.name];
                            final state = status == null
                                ? 'Pending'
                                : status.available
                                ? 'Ready'
                                : 'Not ready';
                            final color = status == null
                                ? Theme.of(context).colorScheme.outline
                                : status.available
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                status == null
                                    ? Icons.hourglass_bottom
                                    : status.available
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: color,
                                size: 18,
                              ),
                              title: Text(host.name),
                              subtitle: Text(status?.detail ?? 'Waiting…'),
                              trailing: Text(
                                state,
                                style: TextStyle(color: color),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}
