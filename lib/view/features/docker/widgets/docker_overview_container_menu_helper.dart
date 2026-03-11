import 'dart:async';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/ssh_host.dart';

class DockerOverviewContainerMenuHelper {
  const DockerOverviewContainerMenuHelper();

  Future<void> handleAction({
    required String action,
    required List<DockerContainer> selection,
    required String Function(SshHost host) dockerContextNameFor,
    required SshHost? remoteHost,
    required Future<void> Function(DockerContainer container) openLogs,
    required Future<void> Function(DockerContainer container) openShell,
    required Future<void> Function(String containerId) copyExecCommand,
    required String Function(String containerId) execCommand,
    required Future<void> Function(String commands, int count) copyExecCommands,
    required Future<void> Function() stopForwards,
    required Future<void> Function(DockerContainer container) forwardPorts,
    required Future<void> Function(
      DockerContainer container,
      String dockerContextName,
    )
    openExplorer,
    required Future<void> Function(DockerContainer container, String action)
    runAction,
  }) async {
    switch (action) {
      case 'logs':
        for (final target in selection) {
          await openLogs(target);
        }
        break;
      case 'shell':
        for (final target in selection) {
          await openShell(target);
        }
        break;
      case 'copyExec':
        if (selection.length == 1) {
          await copyExecCommand(selection.first.id);
        } else {
          final commands = selection
              .map((item) => execCommand(item.id))
              .join('\n');
          await copyExecCommands(commands, selection.length);
        }
        break;
      case 'stopForward':
        await stopForwards();
        break;
      case 'forward':
        for (final target in selection) {
          await forwardPorts(target);
        }
        break;
      case 'explore':
        final contextName = dockerContextNameFor(
          remoteHost ??
              const SshHost(
                name: 'local',
                hostname: 'localhost',
                port: 22,
                available: true,
                user: null,
                identityFiles: <String>[],
                source: 'local',
              ),
        );
        for (final target in selection) {
          await openExplorer(target, contextName);
        }
        break;
      case 'start':
      case 'stop':
      case 'restart':
        await Future.wait(
          selection.map((target) => runAction(target, action)),
        );
        break;
      case 'remove':
        for (final target in selection) {
          await runAction(target, action);
        }
        break;
    }
  }
}
