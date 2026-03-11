import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/model/features/docker/models/remote_docker_status.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/network/connectivity_probe.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';

import 'docker_workspace_controller.dart';
import 'local_docker_context_status.dart';

class DockerLocalStateController {
  DockerLocalStateController({
    required this.settingsController,
    required this.workspaceController,
    required this.viewController,
    required this.shellFactory,
    required this.hostsFuture,
    required this.requestRefresh,
    required this.refreshPickerTabs,
  });

  final AppSettingsController settingsController;
  final DockerWorkspaceController workspaceController;
  final DockerViewController viewController;
  final SshShellFactory shellFactory;
  final Future<List<SshHost>> hostsFuture;
  final VoidCallback requestRefresh;
  final VoidCallback refreshPickerTabs;

  Future<List<RemoteDockerStatus>>? remoteStatusFuture;
  bool remoteScanRequested = false;
  bool scanningRemotes = false;
  int scanToken = 0;
  final Set<int> cancelledScans = {};
  final ValueNotifier<List<SshHost>> scanHostsNotifier =
      ValueNotifier<List<SshHost>>(const []);
  final ValueNotifier<List<RemoteDockerStatus>> scanStatusesNotifier =
      ValueNotifier<List<RemoteDockerStatus>>(const []);
  final ValueNotifier<bool> scanningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<RemoteDockerStatus>> cachedReadyNotifier =
      ValueNotifier<List<RemoteDockerStatus>>(const []);
  List<RemoteDockerStatus> cachedReady = const [];
  Future<List<LocalDockerContextStatus>>? localContextsStatusFuture;

  void refreshContexts() {
    localContextsStatusFuture = null;
  }

  Future<List<LocalDockerContextStatus>> ensureLocalContextsStatusFuture() {
    return localContextsStatusFuture ??= loadLocalContextsStatus();
  }

  int beginRemoteScan() {
    final token = ++scanToken;
    scanningRemotes = true;
    scanningNotifier.value = true;
    remoteScanRequested = true;
    scanStatusesNotifier.value = const [];
    remoteStatusFuture = loadRemoteStatuses(manual: true, token: token);
    return token;
  }

  void cancelRemoteScan(int token) {
    cancelledScans.add(token);
    scanningRemotes = false;
    scanningNotifier.value = false;
    requestRefresh();
  }

  Future<void> completeRemoteScan(int token) async {
    await remoteStatusFuture;
    if (!isScanCancelled(token)) {
      scanningRemotes = false;
      scanningNotifier.value = false;
      requestRefresh();
    }
  }

  Future<void> loadCachedReady() async {
    final cached = await workspaceController.loadCachedReady(hostsFuture);
    cachedReady = cached;
    cachedReadyNotifier.value = cached;
    requestRefresh();
    refreshPickerTabs();
  }

  Future<List<RemoteDockerStatus>> loadRemoteStatuses({
    bool manual = false,
    int token = 0,
  }) async {
    List<SshHost> hosts;
    try {
      hosts = await hostsFuture;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH hosts for docker status scan',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load SSH hosts: $error');
    }
    if (hosts.isEmpty) {
      return const [];
    }
    final disabledKeys =
        settingsController.settings.sshPreferences.disabledServerHosts.toSet();
    final disabledPaths =
        settingsController.settings.sshPreferences.disabledConfigPaths.toSet();
    final enabledHosts = hosts
        .where((host) => isHostEnabled(host, disabledKeys, disabledPaths))
        .toList();
    if (enabledHosts.isEmpty) {
      scanHostsNotifier.value = const [];
      scanStatusesNotifier.value = const [];
      requestRefresh();
      return const [];
    }
    scanHostsNotifier.value = enabledHosts;
    requestRefresh();

    void updateScanStatuses(List<RemoteDockerStatus> statuses) {
      if (!manual) return;
      scanStatusesNotifier.value = statuses;
      requestRefresh();
    }

    final statuses = await workspaceController.discoverRemoteStatuses(
      hostsFuture: Future.value(enabledHosts),
      probeHost: probeHost,
      disabledHosts: disabledKeys,
      disabledPaths: disabledPaths,
      manual: manual,
      isCancelled: () => isScanCancelled(token),
      onProgress: updateScanStatuses,
    );
    final ready = statuses.where((s) => s.available).toList();
    if (manual && !isScanCancelled(token)) {
      scanStatusesNotifier.value = statuses;
      cachedReady = ready;
      cachedReadyNotifier.value = ready;
      requestRefresh();
      refreshPickerTabs();
    }
    return statuses;
  }

  bool isScanCancelled(int token) => cancelledScans.contains(token);

  bool isHostEnabled(
    SshHost host,
    Set<String> disabledKeys,
    Set<String> disabledPaths,
  ) {
    if (!host.available) {
      return false;
    }
    if (isNoShellHost(host)) {
      return false;
    }
    final normalized = disabledKeys.map((key) => key.toLowerCase()).toSet();
    if (normalized.contains(host.hostname.toLowerCase())) {
      return false;
    }
    if (normalized.any((key) => disabledKeyMatchesHost(key, host))) {
      return false;
    }
    final source = host.source;
    if (source != null && disabledPaths.contains(source)) {
      return false;
    }
    return true;
  }

  Future<LocalDockerContextStatus> probeLocalContext(DockerContext context) async {
    try {
      final result = await Process.run(
        'docker',
        ['--context', context.name, 'ps'],
        runInShell: true,
      ).timeout(const Duration(seconds: 3));

      if (result.exitCode == 0) {
        return LocalDockerContextStatus(
          context: context,
          available: true,
          detail: 'Ready',
        );
      }
      final errorMsg = (result.stderr as String?)?.trim() ??
          'docker ps failed with exit code ${result.exitCode}';
      return LocalDockerContextStatus(
        context: context,
        available: false,
        detail: errorMsg.length > 100
            ? '${errorMsg.substring(0, 100)}...'
            : errorMsg,
      );
    } catch (error) {
      final errorMsg = error.toString();
      return LocalDockerContextStatus(
        context: context,
        available: false,
        detail: errorMsg.length > 100
            ? '${errorMsg.substring(0, 100)}...'
            : errorMsg,
      );
    }
  }

  Future<List<LocalDockerContextStatus>> loadLocalContextsStatus() async {
    List<DockerContext> contexts;
    try {
      contexts = await viewController.loadContexts();
    } catch (_) {
      return const [];
    }
    if (contexts.isEmpty) {
      return const [];
    }
    return Future.wait(contexts.map(probeLocalContext));
  }

  Future<RemoteDockerStatus> probeHost(SshHost host) async {
    if (isNoShellHost(host)) {
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: 'Shell access disabled',
        lastScanDate: DateTime.now(),
      );
    }
    final reachable = await isHostReachable(host);
    if (!reachable) {
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: 'Host unreachable',
        lastScanDate: DateTime.now(),
      );
    }
    final shell = shellFactory.forHost(
      host,
      connectTimeout: const Duration(seconds: 3),
    );
    const probeCommand = "bash --login -c 'docker -v'";
    try {
      final output = await shell.runCommand(
        host,
        probeCommand,
        timeout: const Duration(seconds: 3),
      );
      final trimmed = output.trim();
      final now = DateTime.now();
      if (trimmed.toLowerCase().contains('docker version')) {
        return RemoteDockerStatus(
          host: host,
          available: true,
          detail: 'Ready',
          lastScanDate: now,
        );
      }
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: trimmed.isEmpty ? 'Docker not accessible' : trimmed.split('\n').first,
        lastScanDate: now,
      );
    } catch (error, stack) {
      AppLogger().warn(
        'Docker probe failed for ${host.name}: $error',
        tag: 'Docker',
        stackTrace: stack,
      );
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: error.toString(),
        lastScanDate: DateTime.now(),
      );
    }
  }

  Future<bool> isHostReachable(SshHost host) {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 1),
      hostContext: host,
    );
  }

  void dispose() {
    scanHostsNotifier.dispose();
    scanStatusesNotifier.dispose();
    scanningNotifier.dispose();
    cachedReadyNotifier.dispose();
  }
}
