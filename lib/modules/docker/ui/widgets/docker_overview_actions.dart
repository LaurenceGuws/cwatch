import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/modules/docker/services/docker_container_shell_service.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/modules/docker/ui/docker_tab_factory.dart';
import 'package:cwatch/modules/docker/ui/engine_tab.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'docker_overview_controller.dart';

class DockerOverviewActions {
  DockerOverviewActions({
    required this.controller,
    required this.docker,
    required this.contextName,
    required this.remoteHost,
    required this.shellService,
    required this.tabFactory,
    required this.onOpenTab,
    required this.onCloseTab,
  });

  final DockerOverviewController controller;
  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final DockerTabFactory tabFactory;
  final void Function(EngineTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;

  bool get _canOpenTabs => onOpenTab != null;
  bool get _isRemote => controller.isRemote;

  String logsBaseCommand(String containerId) {
    final contextFlag =
        contextName != null && contextName!.isNotEmpty
            ? '--context ${contextName!} '
            : '';
    return 'docker ${contextFlag}logs $containerId';
  }

  String composeBaseCommand(String project) {
    final contextFlag =
        contextName != null && contextName!.isNotEmpty
            ? '--context ${contextName!} '
            : '';
    return 'docker ${contextFlag}compose -p "$project"';
  }

  String followLogsCommand(String containerId) {
    final contextFlag =
        contextName != null && contextName!.isNotEmpty
            ? '--context ${contextName!} '
            : '';
    return '''
bash -lc '
trap "exit 130" INT
tail_arg="--tail 200"
since=""
while true; do
  docker ${contextFlag}logs --follow \$tail_arg \$since "$containerId"
  exit_code=\$?
  if ( \$exit_code -eq 130 ); then
    exit 130
  fi
  tail_arg="--tail 0"
  since="--since=\$(date -Iseconds)"
  echo "[logs] stream ended; waiting to reattach..."
  sleep 1
done'
''';
  }

  String autoCloseCommand(String command) {
    final trimmed = command.trimRight();
    if (trimmed.endsWith('exit') || trimmed.endsWith('exit;')) {
      return command;
    }
    return '$trimmed; exit';
  }

  Future<void> runContainerAction(
    BuildContext context, {
    required DockerContainer container,
    required String action,
    required Future<void> Function() onRestarted,
    required Future<void> Function() onStarted,
    required VoidCallback onStopped,
    required VoidCallback onRefresh,
    required Future<DateTime?> Function() loadStartTime,
  }) async {
    final Duration timeout = action == 'restart'
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);
    controller.markContainerAction(container.id, action);
    try {
      await controller.runWithRetry(
        () async {
          if (_isRemote && shellService != null && remoteHost != null) {
            final cmd = 'docker $action ${container.id}';
            await shellService!.runCommand(
              remoteHost!,
              cmd,
              timeout: timeout,
            );
            return;
          }
          switch (action) {
            case 'start':
              await docker.startContainer(
                id: container.id,
                context: contextName,
                timeout: timeout,
              );
              break;
            case 'stop':
              await docker.stopContainer(
                id: container.id,
                context: contextName,
                timeout: timeout,
              );
              break;
            case 'restart':
              await docker.restartContainer(
                id: container.id,
                context: contextName,
                timeout: timeout,
              );
              break;
            case 'remove':
              await docker.removeContainer(
                id: container.id,
                context: contextName,
                timeout: timeout,
              );
              break;
          }
        },
        retry: _isRemote,
      );
      if (action == 'restart') {
        await onRestarted();
      } else if (action == 'start') {
        await onStarted();
      } else if (action == 'stop') {
        onStopped();
      } else {
        onRefresh();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Container ${action}ed successfully.')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to $action: $error')));
    } finally {
      controller.clearContainerAction(container.id);
    }
  }

  Future<void> runComposeCommand(
    BuildContext context, {
    required String project,
    required String action,
    required Future<void> Function() onSynced,
  }) async {
    controller.markProjectBusy(project, action);
    final args = <String>[];
    switch (action) {
      case 'up':
        args.addAll(['up', '-d']);
        break;
      case 'down':
        args.add('down');
        break;
      case 'restart':
        args.add('restart');
        break;
      default:
        return;
    }
    if (_isRemote && shellService != null && remoteHost != null) {
      final cmd = '${composeBaseCommand(project)} ${args.join(' ')}';
      await shellService!.runCommand(
        remoteHost!,
        cmd,
        timeout: const Duration(seconds: 20),
      );
    } else {
      await docker.processRunner(
        'bash',
        ['-lc', '${composeBaseCommand(project)} ${args.join(' ')}'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compose $action executed for $project.')),
    );
    await onSynced();
    for (final id in controller.projectContainerIds(project)) {
      controller.clearContainerAction(id);
    }
  }

  Future<void> openLogsTab(
    DockerContainer container, {
    required BuildContext context,
  }) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final baseCommand = logsBaseCommand(container.id);
    final tailCommand = autoCloseCommand(followLogsCommand(container.id));

    if (_canOpenTabs) {
      final tabId =
          'logs-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
      final tab = tabFactory.commandTerminal(
        id: tabId,
        title: 'Logs • $name',
        label: 'Logs: $name',
        command: tailCommand,
        icon: NerdIcon.terminal.data,
        host: remoteHost,
        shellService: shellService,
        kind: DockerTabKind.containerLogs,
        containerId: container.id,
        containerName: name,
        contextName: contextName,
        onExit: () => onCloseTab?.call(tabId),
      );
      onOpenTab!(tab);
      return;
    }
    await _showLogsDialog(context, container, baseCommand);
  }

  Future<void> openComposeLogsTab(
    BuildContext context, {
    required String project,
  }) async {
    final base = composeBaseCommand(project);
    final services = controller.composeServices(project);
    if (_canOpenTabs) {
      final tabId = 'clogs-$project-${DateTime.now().microsecondsSinceEpoch}';
      final tab = tabFactory.composeLogs(
        id: tabId,
        title: 'Compose logs: $project',
        label: 'Compose logs: $project',
        icon: NerdIcon.terminal.data,
        composeBase: base,
        project: project,
        services: services,
        host: remoteHost,
        shellService: shellService,
        contextName: contextName,
        onExit: () => onCloseTab?.call(tabId),
      );
      onOpenTab!(tab);
      return;
    }
    await _showLogsDialog(
      context,
      DockerContainer(
        id: project,
        name: 'Compose $project',
        image: '',
        state: '',
        status: '',
        ports: '',
      ),
      '$base logs --tail 200',
    );
  }

  Future<void> openExecTerminal(
    BuildContext context,
    DockerContainer container,
  ) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final contextFlag =
        contextName != null && contextName!.isNotEmpty
            ? '--context ${contextName!} '
            : '';
    final command = autoCloseCommand(
      'docker ${contextFlag}exec -it ${container.id} /bin/sh',
    );
    if (!_canOpenTabs) {
      await copyExecCommand(context, container.id);
      return;
    }
    final tabId =
        'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
    final tab = tabFactory.commandTerminal(
      id: tabId,
      title: 'Shell: $name',
      label: 'Shell: $name',
      command: command,
      icon: NerdIcon.terminal.data,
      host: remoteHost,
      shellService: shellService,
      onExit: () => onCloseTab?.call(tabId),
      kind: DockerTabKind.containerShell,
      containerId: container.id,
      containerName: name,
      contextName: contextName,
    );
    onOpenTab!(tab);
  }

  Future<void> openContainerExplorer(
    BuildContext context,
    DockerContainer container, {
    required String dockerContextName,
  }) async {
    if (!_canOpenTabs) return;
    final isRemote = remoteHost != null && shellService != null;
    final shell = isRemote
        ? DockerContainerShellService(
            host: remoteHost!,
            containerId: container.id,
            baseShell: shellService!,
          )
        : LocalDockerContainerShellService(
            containerId: container.id,
            contextName: contextName,
          );
    final host =
        remoteHost ??
        const SshHost(
          name: 'local',
          hostname: 'localhost',
          port: 22,
          available: true,
          user: null,
          identityFiles: <String>[],
          source: 'local',
        );
    final explorerContext = ExplorerContext.dockerContainer(
      host: host,
      containerId: container.id,
      containerName: container.name,
      dockerContextName: dockerContextName,
    );
    final tab = tabFactory.explorer(
      id: 'explore-${container.id}-${DateTime.now().microsecondsSinceEpoch}',
      title:
          'Explore ${container.name.isNotEmpty ? container.name : container.id}',
      label: 'Explorer',
      icon: NerdIcon.folderOpen.data,
      host: host,
      shellService: shell,
      explorerContext: explorerContext,
      containerId: container.id,
      containerName: container.name,
      dockerContextName: dockerContextName,
      onOpenTab: onOpenTab!,
    );
    onOpenTab!(tab);
  }

  Future<void> copyExecCommand(
    BuildContext context,
    String containerId,
  ) async {
    final contextFlag =
        contextName != null && contextName!.isNotEmpty
            ? '--context ${contextName!} '
            : '';
    final command =
        'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
    await Clipboard.setData(ClipboardData(text: command));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exec command copied.')));
  }

  Future<String> loadLogsSnapshot(String command) async {
    if (_isRemote && shellService != null && remoteHost != null) {
      return shellService!.runCommand(
        remoteHost!,
        '$command --tail 200',
        timeout: const Duration(seconds: 8),
      );
    }

    final result = await docker.processRunner(
      'bash',
      ['-lc', '$command --tail 200'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker logs failed with exit code ${result.exitCode}',
      );
    }
    return (result.stdout as String?) ?? '';
  }

  Future<void> _showLogsDialog(
    BuildContext context,
    DockerContainer container,
    String command,
  ) async {
    try {
      final logs = await loadLogsSnapshot(command);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Logs: ${container.name.isNotEmpty ? container.name : container.id}',
            ),
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed to load logs'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}

class DockerOverviewMenus {
  DockerOverviewMenus({required this.icons});

  final AppIcons icons;

  PopupMenuItem<String> menuItem(
    BuildContext context,
    String value,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
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
    required BuildContext context,
    required Offset globalPosition,
    required String title,
    required Map<String, String> details,
    required String copyValue,
    required String copyLabel,
    List<PopupMenuEntry<String>> extraActions = const [],
    Future<void> Function(String action)? onAction,
  }) async {
    if (!context.mounted) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        menuItem(context, 'copy', 'Copy $copyLabel', icons.copy),
        menuItem(context, 'details', 'Details', Icons.info_outline),
        ...extraActions,
      ],
    );

    if (!context.mounted) return;
    if (selected == 'copy') {
      await Clipboard.setData(ClipboardData(text: copyValue));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('$copyLabel copied to clipboard.')),
        );
      }
    } else if (selected == 'details') {
      await _showDetailsDialog(context, title: title, details: details);
    } else if (selected != null && onAction != null) {
      await onAction(selected);
    }
  }

  Future<void> _showDetailsDialog(
    BuildContext context, {
    required String title,
    required Map<String, String> details,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodySmall,
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
