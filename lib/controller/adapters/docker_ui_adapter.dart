import 'package:flutter/material.dart';

import 'package:cwatch/view/features/docker/widgets/remote_scan_dialog.dart';
import 'package:cwatch/view/features/docker/remote_docker_status.dart';
import 'package:cwatch/model/models/ssh_host.dart';

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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return RemoteScanDialog(
          onCancel: () {
            onCancel();
            dialogOpen = false;
            Navigator.of(dialogContext).pop();
          },
          hostsListenable: hostsListenable,
          statusesListenable: statusesListenable,
          scanningListenable: scanningListenable,
        );
      },
    );
    await onComplete();
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
