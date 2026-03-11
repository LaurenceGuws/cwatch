import 'dart:convert';
import 'dart:io';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/features/docker/services/docker_container_shell_service.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/controller/controllers/docker_overview_tab_factory.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';

import '../adapters/docker_overview_ui_adapter.dart';
import 'docker_overview_display_controller.dart';
import 'docker_port_forward_controller.dart';

class DockerOverviewActionsController {
  DockerOverviewActionsController({
    required this.controller,
    required this.docker,
    required this.tabFactory,
    required this.onOpenTab,
    required this.onCloseTab,
    required this.settingsController,
    required this.portForwardService,
    required this.keyService,
    required this.uiAdapter,
  });

  final DockerOverviewController controller;
  final DockerClientService docker;
  final DockerOverviewTabFactory tabFactory;
  final void Function(WorkspaceTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final AppSettingsController settingsController;
  final PortForwardService portForwardService;
  final BuiltInSshKeyService keyService;
  final DockerOverviewUiAdapter uiAdapter;

  String? get _contextName => controller.contextName;
  SshHost? get _remoteHost => controller.remoteHost;
  RemoteShellService? get _shellService => controller.shellService;

  bool get _canOpenTabs => onOpenTab != null;
  bool get _isRemote => controller.isRemote;
  int get _tailLines => settingsController.settings.dockerLogsTailClamped;
  bool get _supportsForwarding =>
      _isRemote && _remoteHost != null && _shellService != null;

  DockerPortForwardController get _portForwardController =>
      DockerPortForwardController(
        portForwardService: portForwardService,
        settingsController: settingsController,
        keyService: keyService,
        ui: uiAdapter,
        remoteHost: _supportsForwarding ? _remoteHost : null,
        cachedContainers: () => controller.cachedContainers,
      );

  DockerOverviewDisplayController get _displayController =>
      DockerOverviewDisplayController(
        docker: docker,
        ui: uiAdapter,
        contextName: _contextName,
        remoteHost: _remoteHost,
        shellService: _shellService,
      );

  String logsBaseCommand(String containerId) {
    final contextFlag = _contextName != null && _contextName!.isNotEmpty
        ? '--context ${_contextName!} '
        : '';
    return 'docker ${contextFlag}logs $containerId';
  }

  String composeBaseCommand(String project) {
    final contextFlag = _contextName != null && _contextName!.isNotEmpty
        ? '--context ${_contextName!} '
        : '';
    return 'docker ${contextFlag}compose -p "$project"';
  }

  String followLogsCommand(String containerId) {
    final contextFlag = _contextName != null && _contextName!.isNotEmpty
        ? '--context ${_contextName!} '
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
        if (_isRemote && _shellService != null && _remoteHost != null) {
          final cmd = 'docker $action ${container.id}';
          await _shellService!.runCommand(_remoteHost!, cmd, timeout: timeout);
          return;
        }
        switch (action) {
          case 'start':
            await docker.startContainer(
              id: container.id,
              context: _contextName,
              timeout: timeout,
            );
            break;
          case 'stop':
            await docker.stopContainer(
              id: container.id,
              context: _contextName,
              timeout: timeout,
            );
            break;
          case 'restart':
            await docker.restartContainer(
              id: container.id,
              context: _contextName,
              timeout: timeout,
            );
            break;
          case 'remove':
            await docker.removeContainer(
              id: container.id,
              context: _contextName,
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
      if (_isRemote && _shellService != null && _remoteHost != null) {
        final cmd = '${composeBaseCommand(project)} ${args.join(' ')}';
        await _shellService!.runCommand(
          _remoteHost!,
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
      if (_remoteHost != null && _shellService != null) {
        final cmd = includeVolumes
            ? 'docker system prune -f --volumes'
            : 'docker system prune -f';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(seconds: 20),
        );
      } else {
        await docker.systemPrune(
          context: _contextName,
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

  Future<void> removeImages({
    required List<String> imageIds,
    bool force = false,
  }) async {
    // Mark images as busy
    for (final id in imageIds) {
      controller.markImageBusy(id, 'removing');
    }

    try {
      if (_remoteHost != null && _shellService != null) {
        final forceFlag = force ? '-f ' : '';
        final ids = imageIds.join(' ');
        final cmd = 'docker rmi $forceFlag$ids';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(seconds: 30),
        );
      } else {
        for (final id in imageIds) {
          await docker.removeImage(
            imageId: id,
            context: _contextName,
            force: force,
          );
        }
      }
      final count = imageIds.length;
      final plural = count == 1 ? '' : 's';
      
      // Clear busy state first
      for (final id in imageIds) {
        controller.clearImageAction(id);
      }
      
      // Hot reload to update data without full view rebuild
      await controller.hotReload();
      
      uiAdapter.showSnackBar(
        'Removed $count image$plural successfully.',
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to remove images',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to remove images: $error');
      
      // Clear busy state on error
      for (final id in imageIds) {
        controller.clearImageAction(id);
      }
    }
  }

  Future<void> pruneImages({bool all = false}) async {
    uiAdapter.showSnackBar('Pruning images...');
    
    try {
      if (_remoteHost != null && _shellService != null) {
        final allFlag = all ? '-a ' : '';
        final cmd = 'docker image prune $allFlag-f';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(minutes: 1),
        );
      } else {
        await docker.pruneImages(
          context: _contextName,
          all: all,
        );
      }
      await controller.hotReload();
      uiAdapter.showSnackBar('Image prune completed.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Image prune failed',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Image prune failed: $error');
    }
  }

  Future<void> pullImage(String imageName) async {
    uiAdapter.showSnackBar('Pulling image $imageName...');
    
    try {
      if (_remoteHost != null && _shellService != null) {
        final cmd = 'docker pull $imageName';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(minutes: 10),
        );
      } else {
        await docker.pullImage(
          imageName: imageName,
          context: _contextName,
        );
      }
      await controller.hotReload();
      uiAdapter.showSnackBar('Image $imageName pulled successfully.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to pull image $imageName',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to pull image: $error');
    }
  }

  Future<void> tagImage({
    required String sourceImage,
    required String targetImage,
    String? sourceImageId,
  }) async {
    if (sourceImageId != null) {
      controller.markImageBusy(sourceImageId, 'tagging');
    }
    
    try {
      if (_remoteHost != null && _shellService != null) {
        final cmd = 'docker tag $sourceImage $targetImage';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(seconds: 10),
        );
      } else {
        await docker.tagImage(
          sourceImage: sourceImage,
          targetImage: targetImage,
          context: _contextName,
        );
      }
      if (sourceImageId != null) {
        controller.clearImageAction(sourceImageId);
      }
      
      await controller.hotReload();
      uiAdapter.showSnackBar('Image tagged as $targetImage.');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to tag image',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to tag image: $error');
      
      if (sourceImageId != null) {
        controller.clearImageAction(sourceImageId);
      }
    }
  }

  Future<void> pushImage(String imageName, {String? imageId}) async {
    if (imageId != null) {
      controller.markImageBusy(imageId, 'pushing');
    }
    
    uiAdapter.showSnackBar('Pushing image $imageName...');
    
    try {
      if (_remoteHost != null && _shellService != null) {
        final cmd = 'docker push $imageName';
        await _shellService!.runCommand(
          _remoteHost!,
          cmd,
          timeout: const Duration(minutes: 10),
        );
      } else {
        await docker.pushImage(
          imageName: imageName,
          context: _contextName,
        );
      }
      uiAdapter.showSnackBar('Image $imageName pushed successfully.');
      
      if (imageId != null) {
        controller.clearImageAction(imageId);
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to push image $imageName',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to push image: $error');
      
      if (imageId != null) {
        controller.clearImageAction(imageId);
      }
    }
  }

  Future<void> inspectImage(String imageId) async {
    await _displayController.inspectImage(imageId);
  }

  Future<void> showImageHistory(String imageId) async {
    await _displayController.showImageHistory(imageId);
  }

  Future<void> forwardContainerPorts({
    required DockerContainer container,
  }) async {
    await _portForwardController.forwardContainerPorts(container: container);
  }

  Future<void> stopForwardsForHost() async {
    await _portForwardController.stopForwardsForHost();
  }

  Future<void> forwardComposePorts({required String project}) async {
    await _portForwardController.forwardComposePorts(project: project);
  }

  Future<void> openLogsTab({required DockerContainer container}) async {
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
        host: _remoteHost,
        shellService: _shellService,
        kind: DockerTabKind.containerLogs,
        containerId: container.id,
        containerName: name,
        contextName: _contextName,
        onExit: () => onCloseTab?.call(tabId),
      );
      onOpenTab!(tab);
      return;
    }
    await _displayController.showLogsDialog(
      container: container,
      command: baseCommand,
      tailLines: tailLines,
    );
  }

  Future<void> openComposeLogsTab({required String project}) async {
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
        host: _remoteHost,
        shellService: _shellService,
        contextName: _contextName,
        onExit: () => onCloseTab?.call(tabId),
        tailLines: tailLines,
      );
      onOpenTab!(tab);
      return;
    }
    await _displayController.showLogsDialog(
      container: DockerContainer(
        id: project,
        name: 'Compose $project',
        image: '',
        state: '',
        status: '',
        ports: '',
      ),
      command: '$base logs',
      tailLines: tailLines,
    );
  }

  Future<void> openExecTerminal(DockerContainer container) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final contextFlag = _contextName != null && _contextName!.isNotEmpty
        ? '--context ${_contextName!} '
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
    final tab = tabFactory.commandTerminal(
      id: tabId,
      title: 'Shell: $name',
      label: 'Shell: $name',
      command: command,
      icon: NerdIcon.terminal.data,
      host: _remoteHost,
      shellService: _shellService,
      onExit: () => onCloseTab?.call(tabId),
      kind: DockerTabKind.containerShell,
      containerId: container.id,
      containerName: name,
      contextName: _contextName,
    );
    onOpenTab!(tab);
  }

  Future<void> openContainerExplorer({
    required DockerContainer container,
    required String dockerContextName,
  }) async {
    if (!_canOpenTabs) return;
    final isRemote = _remoteHost != null && _shellService != null;
    final shell = isRemote
        ? DockerContainerShellService(
            host: _remoteHost!,
            containerId: container.id,
            baseShell: _shellService!,
          )
        : LocalDockerContainerShellService(
            containerId: container.id,
            contextName: _contextName,
          );
    final host =
        _remoteHost ??
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
    final contextFlag = _contextName != null && _contextName!.isNotEmpty
        ? '--context ${_contextName!} '
        : '';
    return 'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
  }

  Future<void> copyExecCommand(String containerId) async {
    await _displayController.copyExecCommand(containerId);
  }
}
