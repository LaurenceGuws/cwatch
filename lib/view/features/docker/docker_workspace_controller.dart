import 'package:flutter/widgets.dart';

import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/controller/core/workspace/persistent_workspace_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/model/features/docker/models/remote_docker_status.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/core/services/remote_endpoint_cache.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/view/features/docker/docker_workspace_tab_restorer.dart';

class DockerWorkspaceController
    extends PersistentWorkspaceController<DockerWorkspaceState> {
  DockerWorkspaceController({
    required super.settingsController,
    required super.workspaceRootController,
    required super.baseTabBuilder,
  }) : endpointCache = RemoteEndpointCache(storage: CacheStorage());

  final RemoteEndpointCache endpointCache;
  final DockerWorkspaceTabRestorer _tabRestorer =
      const DockerWorkspaceTabRestorer();

  @override
  DockerWorkspaceState? readFromRoot(PersistedWorkspaces workspaces) {
    return workspaces.docker;
  }

  @override
  PersistedWorkspaces writeToRoot(
    PersistedWorkspaces current,
    DockerWorkspaceState workspace,
  ) {
    return current.copyWith(docker: workspace);
  }

  @override
  DockerWorkspaceState createWorkspaceState(
    List<TabState> tabs,
    int selectedIndex,
  ) {
    return DockerWorkspaceState(tabs: tabs, selectedIndex: selectedIndex);
  }

  @override
  TabState? getTabState(Object? tabData) {
    if (tabData is DockerTabData) {
      return tabData.persistedState;
    }
    return null;
  }

  @override
  Future<void> restoreState() async {
    // Handled by view
  }

  Future<void> restore({
    required DockerTabBuilder builder,
    required List<SshHost> hosts,
    required Widget Function(String tabId) pickerBuilder,
    required TabBuilders callbacks,
  }) async {
    final workspace = await workspacePersistence.load();
    if (workspace == null || workspace.tabs.isEmpty) return;
    if (!workspacePersistence.shouldRestore(workspace)) return;

    final restoredTabs = <WorkspaceTab>[];
    for (final state in workspace.tabs) {
      final tab = _tabRestorer.buildTab(
        state: state,
        hosts: hosts,
        builder: builder,
        pickerBuilder: pickerBuilder,
        callbacks: callbacks,
      );
      if (tab != null) {
        restoredTabs.add(tab);
      }
    }

    if (restoredTabs.isNotEmpty) {
      workspacePersistence.markRestored(workspace);
      replaceAll(restoredTabs, selectedIndex: workspace.selectedIndex);
    }
  }

  // Keep loadCachedReady, discoverRemoteStatuses, etc from original controller
  Future<List<RemoteDockerStatus>> loadCachedReady(
    Future<List<SshHost>> hostsFuture,
  ) async {
    final readyNames = (await endpointCache.read()).toSet();
    if (readyNames.isEmpty) return const [];
    List<SshHost> hosts = const [];
    try {
      hosts = await hostsFuture;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH hosts for cached docker endpoints',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final resolved = endpointCache.applyToHosts(readyNames.toList(), hosts);
    return resolved
        .map(
          (host) => RemoteDockerStatus(
            host: host,
            available: true,
            detail: 'Cached ready',
            lastScanDate: DateTime.now(),
          ),
        )
        .toList();
  }

  Future<List<RemoteDockerStatus>> discoverRemoteStatuses({
    required Future<List<SshHost>> hostsFuture,
    required Future<RemoteDockerStatus> Function(SshHost host) probeHost,
    Set<String> disabledHosts = const {},
    Set<String> disabledPaths = const {},
    bool manual = false,
    bool Function()? isCancelled,
    void Function(List<RemoteDockerStatus> statuses)? onProgress,
  }) async {
    const maxConcurrent = 3;
    List<SshHost> hosts;
    try {
      hosts = await hostsFuture;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH hosts for docker discovery',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load SSH hosts: $error');
    }
    final normalizedDisabled = disabledHosts
        .map((key) => key.toLowerCase())
        .toSet();
    bool isDisabled(SshHost host) {
      if (normalizedDisabled.any((key) => disabledKeyMatchesHost(key, host))) {
        return true;
      }
      if (normalizedDisabled.contains(host.hostname.toLowerCase())) {
        return true;
      }
      final source = host.source;
      if (source != null && disabledPaths.contains(source)) {
        return true;
      }
      return false;
    }

    final enabledHosts = hosts
        .where(
          (host) => host.available && !isDisabled(host) && !isNoShellHost(host),
        )
        .toList();
    if (enabledHosts.isEmpty) {
      return const [];
    }
    final results = List<RemoteDockerStatus?>.filled(
      enabledHosts.length,
      null,
      growable: false,
    );
    var nextIndex = 0;

    bool shouldCancel() => isCancelled?.call() ?? false;

    void reportProgress() {
      if (onProgress == null) return;
      onProgress(results.whereType<RemoteDockerStatus>().toList());
    }

    Future<void> runNext() async {
      if (shouldCancel()) return;
      final current = nextIndex++;
      if (current >= enabledHosts.length) return;
      final host = enabledHosts[current];
      try {
        results[current] = await probeHost(host);
      } catch (error) {
        AppLogger().warn(
          'Docker scan failed for ${host.name}: $error',
          tag: 'Docker',
        );
        results[current] = RemoteDockerStatus(
          host: host,
          available: false,
          detail: error.toString(),
          lastScanDate: DateTime.now(),
        );
      }
      reportProgress();
      if (shouldCancel()) return;
      await runNext();
    }

    final workers = List.generate(
      maxConcurrent < enabledHosts.length ? maxConcurrent : enabledHosts.length,
      (_) => runNext(),
    );
    await Future.wait(workers);
    final statuses = results.whereType<RemoteDockerStatus>().toList();
    final ready = statuses.where((s) => s.available).toList();
    if (manual && !shouldCancel() && ready.isNotEmpty) {
      await endpointCache.persist(ready.map((s) => s.host.name).toList());
    }
    return statuses;
  }
}
