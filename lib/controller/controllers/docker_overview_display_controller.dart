import 'dart:convert';

import 'package:cwatch/controller/adapters/docker_overview_display_ui.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';

class DockerOverviewDisplayController {
  DockerOverviewDisplayController({
    required this.docker,
    required this.ui,
    required this.contextName,
    required this.remoteHost,
    required this.shellService,
  });

  final DockerClientService docker;
  final DockerOverviewDisplayUi ui;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;

  bool get _isRemote => remoteHost != null && shellService != null;

  Future<void> inspectImage(String imageId) async {
    try {
      final output = await docker.inspectImage(
        imageId: imageId,
        context: contextName,
      );
      await ui.showInspectDialog(
        title: 'Image Inspect: $imageId',
        content: output,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to inspect image $imageId',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Failed to inspect image: $error');
    }
  }

  Future<void> showImageHistory(String imageId) async {
    try {
      final output = await docker.imageHistory(
        imageId: imageId,
        context: contextName,
      );
      await ui.showInspectDialog(
        title: 'Image History: $imageId',
        content: output,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to get image history for $imageId',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Failed to get image history: $error');
    }
  }

  Future<void> copyExecCommand(String containerId) async {
    final command = execCommand(containerId);
    await ui.copyToClipboard(
      command,
      successMessage: 'Exec command copied.',
    );
  }

  String execCommand(String containerId) {
    final contextFlag = contextName != null && contextName!.isNotEmpty
        ? '--context ${contextName!} '
        : '';
    return 'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
  }

  Future<void> showLogsDialog({
    required DockerContainer container,
    required String command,
    required int tailLines,
  }) async {
    try {
      final logs = await loadLogsSnapshot(command, tailLines: tailLines);
      await ui.showLogsDialog(
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
      await ui.showErrorDialog(
        title: 'Failed to load logs',
        message: error.toString(),
      );
    }
  }

  Future<String> loadLogsSnapshot(
    String command, {
    required int tailLines,
  }) async {
    if (_isRemote) {
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
}
