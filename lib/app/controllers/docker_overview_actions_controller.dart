import 'dart:convert';
import 'dart:io';

import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/modules/docker/services/docker_container_shell_service.dart';
import 'package:cwatch/modules/docker/ui/docker_tab_builder.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_overview_controller.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';

import '../adapters/docker_overview_ui_adapter.dart';

class DockerOverviewActionsController {
  DockerOverviewActionsController({
    required this.controller,
    required this.docker,
    required this.contextName,
    required this.remoteHost,
    required this.shellService,
    required this.tabBuilder,
    required this.onOpenTab,
    required this.onCloseTab,
    required this.settingsController,
    required this.portForwardService,
    required this.keyService,
    required this.uiAdapter,
  });

  final DockerOverviewController controller;
  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final DockerTabBuilder tabBuilder;
  final void Function(WorkspaceTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final AppSettingsController settingsController;
  final PortForwardService portForwardService;
  final BuiltInSshKeyService keyService;
  final DockerOverviewUiAdapter uiAdapter;

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

  Future<void> runContainerAction({
    required DockerContainer container,
    required String action,
    required Future<void> Function() onRestarted,
    required Future<void> Function() onStarted,
    required void Function() onStopped,
    required void Function() onRefresh,
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
      uiAdapter.showSnackBar('Container ${action}ed successfully.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to $action container ${container.name}',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to $action: $error');
    } finally {
      controller.clearContainerAction(container.id);
    }
  }

  Future<void> runComposeCommand({
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
      uiAdapter.showSnackBar('Compose $action executed for $project.');
      await onSynced();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to run compose $action for $project',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Compose $action failed: $error');
    } finally {
      for (final id in affectedIds) {
        controller.clearContainerAction(id);
      }
    }
  }

  Future<void> runPrune({required bool includeVolumes}) async {
    try {
      if (remoteHost != null && shellService != null) {
        final cmd = includeVolumes
            ? 'docker system prune -f --volumes'
            : 'docker system prune -f';
        await shellService!.runCommand(
          remoteHost!,
          cmd,
          timeout: const Duration(seconds: 20),
        );
      } else {
        await docker.systemPrune(
          context: contextName,
          includeVolumes: includeVolumes,
        );
      }
      uiAdapter.showSnackBar('Prune completed.');
      controller.refresh();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Docker prune failed',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Prune failed: $error');
    }
  }

  Future<void> forwardContainerPorts({
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
      uiAdapter.showSnackBar('No published ports detected.');
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
      AppLogger().debug(
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
    final result = await uiAdapter.showPortForwardDialog(
      title:
          'Forward ports (${container.name.isNotEmpty ? container.name : container.id})',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (result == null || result.isEmpty) return;
    try {
      await portForwardService.startForward(
        host: remoteHost!,
        requests: result,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: uiAdapter.buildSshAuthCoordinator(
          keyService: keyService,
        ),
      );
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      uiAdapter.showSnackBar('Forwarding $summary via SSH.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to create port forward for ${container.name}',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Port forward failed: $error');
    }
  }

  Future<void> stopForwardsForHost() async {
    if (!_supportsForwarding || remoteHost == null) return;
    final forwards = portForwardService.forwardsForHost(remoteHost!).toList();
    if (forwards.isEmpty) {
      uiAdapter.showSnackBar('No active forwards.');
      return;
    }
    for (final forward in forwards) {
      await portForwardService.stopForward(forward.id);
    }
    uiAdapter.showSnackBar('Stopped active port forwards.');
  }

  Future<void> forwardComposePorts({required String project}) async {
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
      uiAdapter.showSnackBar('No published ports detected.');
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
      AppLogger().debug(
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
    final result = await uiAdapter.showPortForwardDialog(
      title: 'Forward ports (Compose $project)',
      requests: requests,
      portValidator: portForwardService.isPortAvailable,
      active: activeForwards,
    );
    if (result == null || result.isEmpty) return;
    try {
      await portForwardService.startForward(
        host: remoteHost!,
        requests: result,
        settingsController: settingsController,
        builtInKeyService: keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: uiAdapter.buildSshAuthCoordinator(
          keyService: keyService,
        ),
      );
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      uiAdapter.showSnackBar('Forwarding $summary for $project.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to create compose port forward for $project',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Port forward failed: $error');
    }
  }

  Future<void> openLogsTab({required DockerContainer container}) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final baseCommand = logsBaseCommand(container.id);
    final tailLines = _tailLines;
    final tailCommand = autoCloseCommand(followLogsCommand(container.id));

    if (_canOpenTabs) {
      final tabId =
          'logs-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
      final tab = tabBuilder.commandTerminal(
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
    await _showLogsDialog(container, baseCommand, tailLines);
  }

  Future<void> openComposeLogsTab({required String project}) async {
    final base = composeBaseCommand(project);
    final tailLines = _tailLines;
    final services = controller.composeServices(project);
    if (_canOpenTabs) {
      final tabId = 'clogs-$project-${DateTime.now().microsecondsSinceEpoch}';
      final tab = tabBuilder.composeLogs(
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

  Future<void> openExecTerminal(DockerContainer container) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    final command = autoCloseCommand(
      'docker ${contextFlag}exec -it ${container.id} /bin/sh',
    );
    if (!_canOpenTabs) {
      await copyExecCommand(container.id);
      return;
    }
    final tabId =
        'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
    final tab = tabBuilder.commandTerminal(
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

  Future<void> openContainerExplorer({
    required DockerContainer container,
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
    final tab = tabBuilder.explorer(
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

  Future<void> copyExecCommand(String containerId) async {
    final command = execCommand(containerId);
    await uiAdapter.copyToClipboard(
      command,
      successMessage: 'Exec command copied.',
    );
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
    DockerContainer container,
    String command,
    int tailLines,
  ) async {
    try {
      final logs = await loadLogsSnapshot(command, tailLines: tailLines);
      await uiAdapter.showLogsDialog(
        title:
            'Logs: ${container.name.isNotEmpty ? container.name : container.id}',
        logs: logs,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load docker logs for ${container.name.isNotEmpty ? container.name : container.id}',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      await uiAdapter.showErrorDialog(
        title: 'Failed to load logs',
        message: error.toString(),
      );
    }
  }
}
