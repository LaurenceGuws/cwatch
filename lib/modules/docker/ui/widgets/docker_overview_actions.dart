import 'dart:convert';
import 'dart:io';

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
import 'package:cwatch/shared/widgets/port_forward_dialog.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/ssh_auth_prompter.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/services/logging/app_logger.dart';
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
    required this.settingsController,
    required this.portForwardService,
    required this.keyService,
  });

  final DockerOverviewController controller;
  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final DockerTabFactory tabFactory;
  final void Function(EngineTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final AppSettingsController settingsController;
  final PortForwardService portForwardService;
  final BuiltInSshKeyService keyService;

  bool get _canOpenTabs => onOpenTab != null;
  bool get _isRemote => controller.isRemote;
  int get _tailLines => settingsController.settings.dockerLogsTailClamped;
  bool get _supportsForwarding =>
      _isRemote && remoteHost != null && shellService != null;

  String logsBaseCommand(String containerId) {
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    return 'docker ${contextFlag}logs $containerId';
  }

  String composeBaseCommand(String project) {
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    return 'docker ${contextFlag}compose -p "$project"';
  }

  String followLogsCommand(String containerId) {
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    final tailArg = '--tail $_tailLines';
    return '''
bash -lc '
trap "exit 130" INT
tail_arg="$tailArg"
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
    const historyPrefix =
        'HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 HISTCONTROL=ignorespace';
    final trimmed = command.trimRight();
    final suffixed = (trimmed.endsWith('exit') || trimmed.endsWith('exit;'))
        ? trimmed
        : '$trimmed; exit';
    if (Platform.isWindows) {
      // PowerShell doesn't understand the bash-specific history mangling; just
      // send the command with a trailing exit.
      return suffixed;
    }
    if (suffixed.startsWith(historyPrefix)) {
      return suffixed;
    }
    return '$historyPrefix; clear; $suffixed';
  }

  List<int> _extractPorts(String raw) {
    final parts = raw
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final ports = <int>{};
    for (final part in parts) {
      final arrowIndex = part.indexOf('->');
      if (arrowIndex != -1) {
        final hostSide = part.substring(0, arrowIndex);
        final segments = hostSide.split(':');
        final candidate = segments.isNotEmpty ? segments.last : hostSide;
        final parsed = int.tryParse(
          RegExp(r'([0-9]+)').stringMatch(candidate) ?? '',
        );
        if (parsed != null) {
          ports.add(parsed);
          continue;
        }
      }
      final startMatch = RegExp(r'^([0-9]+)').firstMatch(part);
      if (startMatch != null) {
        ports.add(int.parse(startMatch.group(1)!));
      }
    }
    final list = ports.toList()..sort();
    return list;
  }

  Future<int> _pickLocalPort(Set<int> reserved, int preferred) async {
    var candidate = preferred;
    while (candidate < 65535) {
      if (!reserved.contains(candidate) &&
          await portForwardService.isPortAvailable(candidate)) {
        return candidate;
      }
      candidate += 1;
    }
    throw Exception('No free local ports available for $preferred');
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
      await controller.runWithRetry(() async {
        if (_isRemote && shellService != null && remoteHost != null) {
          final cmd = 'docker $action ${container.id}';
          await shellService!.runCommand(remoteHost!, cmd, timeout: timeout);
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
      }, retry: _isRemote);
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
    final affectedIds = controller.projectContainerIds(project);
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
    try {
      if (_isRemote && shellService != null && remoteHost != null) {
        final cmd = '${composeBaseCommand(project)} ${args.join(' ')}';
        await shellService!.runCommand(
          remoteHost!,
          cmd,
          timeout: const Duration(minutes: 5),
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
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Compose $action failed: $error')));
    } finally {
      for (final id in affectedIds) {
        controller.clearContainerAction(id);
      }
    }
  }

  Future<void> forwardContainerPorts(
    BuildContext context, {
    required DockerContainer container,
  }) async {
    final hostKeyBindings =
        settingsController.settings.builtinSshHostKeyBindings;
    if (!_supportsForwarding) {
      return;
    }
    final detected = _extractPorts(container.ports);
    final activeForwards = remoteHost != null
        ? portForwardService.forwardsForHost(remoteHost!).toList()
        : const <ActivePortForward>[];
    if (detected.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No published ports detected.')),
        );
      }
      return;
    }
    final requests = <PortForwardRequest>[];
    for (final port in detected) {
      final existing = activeForwards
          .expand((f) => f.requests)
          .firstWhere(
            (r) => r.remotePort == port,
            orElse: () => PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
            ),
          );
      final local = existing.remotePort == port && existing.localPort > 0
          ? existing.localPort
          : await portForwardService.suggestLocalPort(port);
      AppLogger.d(
        'Forward default for ${container.id}: remote=$port local=$local '
        '(existingMatch=${existing.remotePort == port && existing.localPort > 0})',
        tag: 'PortForward',
      );
      requests.add(
        PortForwardRequest(
          remoteHost: '127.0.0.1',
          remotePort: port,
          localPort: local,
          label: container.name.isNotEmpty ? container.name : container.id,
        ),
      );
    }
    if (!context.mounted) return;
    final result = await showPortForwardDialog(
      context: context,
      title:
          'Forward ports (${container.name.isNotEmpty ? container.name : container.id})',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (!context.mounted || result == null || result.isEmpty) return;
    try {
      await portForwardService.startForward(
        host: remoteHost!,
        requests: result,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: SshAuthPrompter.forContext(
          context: context,
          keyService: keyService,
        ),
      );
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Forwarding $summary via SSH.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Port forward failed: $error')));
    }
  }

  Future<void> stopForwardsForHost(BuildContext context) async {
    if (!_supportsForwarding || remoteHost == null) return;
    final forwards = portForwardService.forwardsForHost(remoteHost!).toList();
    if (forwards.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No active forwards.')));
      }
      return;
    }
    for (final forward in forwards) {
      await portForwardService.stopForward(forward.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped active port forwards.')),
      );
    }
  }

  Future<void> forwardComposePorts(
    BuildContext context, {
    required String project,
  }) async {
    final hostKeyBindings =
        settingsController.settings.builtinSshHostKeyBindings;
    if (!_supportsForwarding) return;
    final ports = <int>{};
    for (final container in controller.cachedContainers) {
      if (container.composeProject == project) {
        ports.addAll(_extractPorts(container.ports));
      }
    }
    final sorted = ports.toList()..sort();
    if (sorted.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No published ports detected.')),
        );
      }
      return;
    }
    final portServices = <int, Set<String>>{};
    for (final container in controller.cachedContainers) {
      if (container.composeProject != project) continue;
      final serviceName = (container.composeService?.isNotEmpty ?? false)
          ? container.composeService!
          : (container.name.isNotEmpty ? container.name : project);
      final containerPorts = _extractPorts(container.ports);
      for (final p in containerPorts) {
        portServices.putIfAbsent(p, () => <String>{}).add(serviceName);
      }
    }

    final activeForwards = remoteHost != null
        ? portForwardService.forwardsForHost(remoteHost!).toList()
        : const <ActivePortForward>[];
    final requests = <PortForwardRequest>[];
    final reservedLocals = activeForwards
        .expand((f) => f.requests.map((r) => r.localPort))
        .where((p) => p > 0)
        .toSet();
    for (final port in sorted) {
      final existing = activeForwards
          .expand((f) => f.requests)
          .firstWhere(
            (r) => r.remotePort == port,
            orElse: () => PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
            ),
          );
      final local = existing.remotePort == port && existing.localPort > 0
          ? existing.localPort
          : await _pickLocalPort(reservedLocals, port);
      reservedLocals.add(local);
      AppLogger.d(
        'Compose $project forward default: remote=$port local=$local '
        '(existingMatch=${existing.remotePort == port && existing.localPort > 0})',
        tag: 'PortForward',
      );
      final services = portServices[port];
      final label = (services != null && services.isNotEmpty)
          ? services.join(', ')
          : project;
      requests.add(
        PortForwardRequest(
          remoteHost: '127.0.0.1',
          remotePort: port,
          localPort: local,
          label: label,
        ),
      );
    }
    if (!context.mounted) return;
    final result = await showPortForwardDialog(
      context: context,
      title: 'Forward ports (Compose $project)',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (!context.mounted || result == null || result.isEmpty) return;
    try {
      await portForwardService.startForward(
        host: remoteHost!,
        requests: result,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: SshAuthPrompter.forContext(
          context: context,
          keyService: keyService,
        ),
      );
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarding $summary for $project.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Port forward failed: $error')));
    }
  }

  Future<void> openLogsTab(
    DockerContainer container, {
    required BuildContext context,
  }) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final baseCommand = logsBaseCommand(container.id);
    final tailLines = _tailLines;
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
    await _showLogsDialog(context, container, baseCommand, tailLines);
  }

  Future<void> openComposeLogsTab(
    BuildContext context, {
    required String project,
  }) async {
    final base = composeBaseCommand(project);
    final tailLines = _tailLines;
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
        tailLines: tailLines,
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
      '$base logs',
      tailLines,
    );
  }

  Future<void> openExecTerminal(
    BuildContext context,
    DockerContainer container,
  ) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final contextFlag = contextName != null && contextName!.isNotEmpty
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

  String execCommand(String containerId) {
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    return 'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
  }

  Future<void> copyExecCommand(BuildContext context, String containerId) async {
    final command = execCommand(containerId);
    await Clipboard.setData(ClipboardData(text: command));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exec command copied.')));
  }

  Future<String> loadLogsSnapshot(
    String command, {
    required int tailLines,
  }) async {
    if (_isRemote && shellService != null && remoteHost != null) {
      return shellService!.runCommand(
        remoteHost!,
        '$command --tail $tailLines',
        timeout: const Duration(seconds: 8),
      );
    }

    final result = await docker.processRunner(
      'bash',
      ['-lc', '$command --tail $tailLines'],
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
    int tailLines,
  ) async {
    try {
      final logs = await loadLogsSnapshot(command, tailLines: tailLines);
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
        ScaffoldMessenger.of(context).showSnackBar(
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
