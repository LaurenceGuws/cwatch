import 'package:flutter/widgets.dart';

import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/controller/core/workspace/persistent_workspace_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/remote_docker_status.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/core/services/remote_endpoint_cache.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';

class DockerWorkspaceController
    extends PersistentWorkspaceController<DockerWorkspaceState> {
  DockerWorkspaceController({
    required super.settingsController,
    required super.baseTabBuilder,
  }) : endpointCache = RemoteEndpointCache(storage: CacheStorage());

  final RemoteEndpointCache endpointCache;

  @override
  DockerWorkspaceState? readFromSettings(AppSettings settings) {
    return settings.dockerWorkspace;
  }

  @override
  AppSettings writeToSettings(
    AppSettings current,
    DockerWorkspaceState workspace,
  ) {
    return current.copyWith(dockerWorkspace: workspace);
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
    final workspace = settingsController.settings.dockerWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) return;
    if (!workspacePersistence.shouldRestore(workspace)) return;

    final restoredTabs = <WorkspaceTab>[];
    for (final state in workspace.tabs) {
      final tab = _createTabFromState(
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

  WorkspaceTab? _createTabFromState({
    required TabState state,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required Widget Function(String tabId) pickerBuilder,
    required TabBuilders callbacks,
  }) {
    final dockerState = _dockerStateFromTab(state);
    if (dockerState == null) return null;

    switch (dockerState.kind) {
      case DockerTabKind.placeholder:
        return builder.placeholder(
          id: dockerState.id,
          body: pickerBuilder(dockerState.id),
        );
      case DockerTabKind.picker:
        return builder.picker(
          id: dockerState.id,
          body: pickerBuilder(dockerState.id),
        );

      case DockerTabKind.contextOverview:
        if (dockerState.contextName == null) return null;
        final title = dockerState.title ?? dockerState.contextName!;
        return builder.overview(
          id: dockerState.id,
          title: title,
          label: title,
          icon: callbacks.cloudIcon,
          contextName: dockerState.contextName,
          onOpenTab: callbacks.onOpenTab,
          onCloseTab: callbacks.closeTab,
        );
      case DockerTabKind.contextResources:
        if (dockerState.contextName == null) return null;
        final title = dockerState.title ?? dockerState.contextName!;
        return builder.resources(
          id: dockerState.id,
          title: title,
          label: title,
          icon: callbacks.cloudIcon,
          contextName: dockerState.contextName,
          onOpenTab: callbacks.onOpenTab,
          onCloseTab: callbacks.closeTab,
        );
      case DockerTabKind.hostOverview:
      case DockerTabKind.hostResources:
        if (dockerState.hostName == null) return null;
        final host = _hostByName(hosts, dockerState.hostName);
        if (host == null || host.name.isEmpty) return null;
        final shell = callbacks.shellForHost(host);
        final title = dockerState.title ?? host.name;
        if (dockerState.kind == DockerTabKind.hostResources) {
          return builder.resources(
            id: dockerState.id,
            title: title,
            label: title,
            icon: callbacks.cloudOutlineIcon,
            remoteHost: host,
            shellService: shell,
            onOpenTab: callbacks.onOpenTab,
            onCloseTab: callbacks.closeTab,
          );
        }
        return builder.overview(
          id: dockerState.id,
          title: title,
          label: title,
          icon: callbacks.cloudOutlineIcon,
          remoteHost: host,
          shellService: shell,
          onOpenTab: callbacks.onOpenTab,
          onCloseTab: callbacks.closeTab,
        );
      case DockerTabKind.command:
        if (dockerState.command == null || dockerState.title == null) {
          return null;
        }
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = host != null ? callbacks.shellForHost(host) : null;
        final command = _sanitizeExec(dockerState.command!);
        final containerId = dockerState.containerId;
        final containerName = dockerState.containerName;
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builder.containerEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: callbacks.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              containerId: containerId,
              containerName: containerName,
              contextName: dockerState.contextName,
            );
            callbacks.onOpenTab(tab);
          };
        }
        return builder.commandTerminal(
          id: dockerState.id,
          title: dockerState.title!,
          label: dockerState.title!,
          command: command,
          icon: callbacks.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => callbacks.closeTab(dockerState.id),
          kind: DockerTabKind.command,
          containerId: containerId,
          containerName: containerName,
          contextName: dockerState.contextName,
          onOpenEditorTab: openEditorTab,
        );
      case DockerTabKind.containerShell:
      case DockerTabKind.containerLogs:
        if (dockerState.command == null || dockerState.title == null) {
          return null;
        }
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = host != null ? callbacks.shellForHost(host) : null;
        final command = _sanitizeExec(dockerState.command!);
        final containerId = dockerState.containerId;
        final containerName = dockerState.containerName;
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builder.containerEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: callbacks.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              containerId: containerId,
              containerName: containerName,
              contextName: dockerState.contextName,
            );
            callbacks.onOpenTab(tab);
          };
        }
        return builder.commandTerminal(
          id: dockerState.id,
          title: dockerState.title!,
          label: dockerState.title!,
          command: command,
          icon: callbacks.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => callbacks.closeTab(dockerState.id),
          kind: dockerState.kind,
          containerId: containerId,
          containerName: containerName,
          contextName: dockerState.contextName,
          onOpenEditorTab: openEditorTab,
        );
      case DockerTabKind.composeLogs:
        if (dockerState.project == null) return null;
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = host != null ? callbacks.shellForHost(host) : null;
        final composeBase =
            dockerState.command ?? 'docker compose -p "${dockerState.project}"';
        final title =
            dockerState.title ?? 'Compose logs: ${dockerState.project}';
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builder.containerEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: callbacks.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              contextName: dockerState.contextName,
            );
            callbacks.onOpenTab(tab);
          };
        }
        return builder.composeLogs(
          id: dockerState.id,
          title: title,
          label: title,
          icon: callbacks.composeIcon,
          composeBase: composeBase,
          project: dockerState.project!,
          services: dockerState.services,
          host: host,
          shellService: shell,
          contextName: dockerState.contextName,
          onExit: () => callbacks.closeTab(dockerState.id),
          tailLines: settingsController.settings.dockerLogsTailClamped,
          onOpenEditorTab: openEditorTab,
        );
      case DockerTabKind.containerExplorer:
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = callbacks.containerShell(
          host,
          dockerState.containerId,
          contextName: dockerState.contextName,
        );
        if (shell == null) return null;
        final explorerHost =
            host ??
            const SshHost(
              name: 'local',
              hostname: 'localhost',
              port: 22,
              available: true,
              user: null,
              identityFiles: <String>[],
              source: 'local',
            );
        final containerId = dockerState.containerId ?? '';
        final explorerContext = ExplorerContext.dockerContainer(
          host: explorerHost,
          containerId: containerId,
          containerName: dockerState.containerName,
          dockerContextName: callbacks.dockerContextNameFor(
            explorerHost,
            dockerState.contextName,
          ),
        );
        return builder.explorer(
          id: dockerState.id,
          title:
              'Explore ${dockerState.containerName ?? dockerState.containerId ?? explorerHost.name}',
          label: 'Explorer',
          icon: callbacks.explorerIcon,
          host: explorerHost,
          shellService: shell,
          explorerContext: explorerContext,
          containerId: containerId,
          containerName: dockerState.containerName,
          dockerContextName: dockerState.contextName,
          onOpenTab: callbacks.onOpenTab,
          initialPath: dockerState.path,
          onPathChanged: (path) =>
              callbacks.onExplorerPathChanged?.call(dockerState.id, path),
        );
      case DockerTabKind.containerEditor:
        if (dockerState.path == null || dockerState.containerId == null) {
          return null;
        }
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = callbacks.containerShell(
          host,
          dockerState.containerId,
          contextName: dockerState.contextName,
        );
        if (shell == null) return null;
        final editorHost =
            host ??
            const SshHost(
              name: 'local',
              hostname: 'localhost',
              port: 22,
              available: true,
              user: null,
              identityFiles: <String>[],
              source: 'local',
            );
        return builder.containerEditor(
          id: dockerState.id,
          title: 'Edit ${dockerState.path}',
          label: dockerState.path ?? 'Editor',
          icon: callbacks.editorIcon,
          host: editorHost,
          shellService: shell,
          path: dockerState.path!,
          containerId: dockerState.containerId,
          containerName: dockerState.containerName,
          contextName: dockerState.contextName,
        );
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

  SshHost? _hostByName(List<SshHost> hosts, String? name) {
    if (name == null) return null;
    for (final host in hosts) {
      if (host.name == name) return host;
    }
    return null;
  }

  String _sanitizeExec(String command) {
    const suffix = '; exit';
    final trimmed = command.trimRight();
    if (trimmed.endsWith(suffix)) {
      return trimmed.substring(0, trimmed.length - suffix.length).trimRight();
    }
    return command;
  }

  DockerTabState? _dockerStateFromTab(TabState state) {
    final kind = _dockerKindFromString(state.kind);
    if (kind == null) return null;
    return DockerTabState(
      id: state.id,
      kind: kind,
      contextName: state.contextName,
      hostName: state.hostName,
      containerId: state.stringExtra('containerId'),
      containerName: state.stringExtra('containerName'),
      command: state.command,
      title: state.title ?? state.label,
      path: state.path,
      project: state.project,
      services: state.services,
    );
  }

  DockerTabKind? _dockerKindFromString(String raw) {
    for (final value in DockerTabKind.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}

class TabBuilders {
  const TabBuilders({
    required this.cloudIcon,
    required this.cloudOutlineIcon,
    required this.commandIcon,
    required this.composeIcon,
    required this.explorerIcon,
    required this.editorIcon,
    required this.shellForHost,
    required this.containerShell,
    required this.dockerContextNameFor,
    required this.closeTab,
    required this.onOpenTab,
    this.onExplorerPathChanged,
  });

  final IconData cloudIcon;
  final IconData cloudOutlineIcon;
  final IconData commandIcon;
  final IconData composeIcon;
  final IconData explorerIcon;
  final IconData editorIcon;
  final RemoteShellService? Function(SshHost host) shellForHost;
  final RemoteShellService? Function(
    SshHost? host,
    String? containerId, {
    String? contextName,
  })
  containerShell;
  final String Function(SshHost host, String? contextName) dockerContextNameFor;
  final void Function(String id) closeTab;
  final void Function(WorkspaceTab tab) onOpenTab;
  final void Function(String tabId, String path)? onExplorerPathChanged;
}
