import 'package:flutter/widgets.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/modules/docker/ui/engine_tab.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_command_terminal.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_overview.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_resources.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_engine_picker.dart';
import 'package:cwatch/core/services/remote_endpoint_cache.dart';

/// Small controller to centralise Docker workspace persistence and tab state
/// derivation, mirroring the server workspace controller pattern.
class DockerWorkspaceController {
  DockerWorkspaceController({required this.settingsController})
    : endpointCache = RemoteEndpointCache(
        settingsController: settingsController,
        readNames: (settings) => settings.dockerRemoteHosts,
        writeNames: (current, names) =>
            current.copyWith(dockerRemoteHosts: names),
      ) {
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: (settings) => settings.dockerWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(dockerWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  final RemoteEndpointCache endpointCache;
  late final WorkspacePersistence<DockerWorkspaceState> workspacePersistence;

  /// Result of rebuilding tabs from persisted workspace.
  RestoredDockerTabs buildTabsFromState({
    required DockerWorkspaceState workspace,
    required List<SshHost> hosts,
    required EngineTab? Function(TabState state) buildTab,
  }) {
    final tabs = <EngineTab>[];
    final states = <String, TabState>{};
    final usedIds = <String>{};

    for (final state in workspace.tabs) {
      if (usedIds.contains(state.id)) {
        continue;
      }
      final tab = buildTab(state);
      if (tab == null) continue;
      final tabId = tab.id;
      if (usedIds.contains(tabId)) {
        continue;
      }
      usedIds.add(tabId);
      tabs.add(tab);
      states[tabId] = _copyStateWithId(state, tabId);
    }

    return RestoredDockerTabs(tabs: tabs, states: states);
  }

  EngineTab? tabFromState({
    required TabState state,
    required List<SshHost> hosts,
    required TabBuilders builders,
  }) {
    final dockerState = _dockerStateFromTab(state);
    if (dockerState == null) return null;

    switch (dockerState.kind) {
      case DockerTabKind.placeholder:
        return builders.buildPlaceholder(id: dockerState.id);
      case DockerTabKind.picker:
        return builders.buildPicker(id: dockerState.id);
      case DockerTabKind.contextOverview:
        if (dockerState.contextName == null) return null;
        final title = dockerState.title ?? dockerState.contextName!;
        return builders.buildOverview(
          id: dockerState.id,
          title: title,
          label: title,
          icon: builders.cloudIcon,
          contextName: dockerState.contextName,
        );
      case DockerTabKind.contextResources:
        if (dockerState.contextName == null) return null;
        final title = dockerState.title ?? dockerState.contextName!;
        return builders.buildResources(
          id: dockerState.id,
          title: title,
          label: title,
          icon: builders.cloudIcon,
          contextName: dockerState.contextName,
        );
      case DockerTabKind.hostOverview:
      case DockerTabKind.hostResources:
        if (dockerState.hostName == null) return null;
        final host = _hostByName(hosts, dockerState.hostName);
        if (host == null || host.name.isEmpty) return null;
        final shell = builders.shellForHost(host);
        final title = dockerState.title ?? host.name;
        final builder = dockerState.kind == DockerTabKind.hostResources
            ? builders.buildResources
            : builders.buildOverview;
        return builder(
          id: dockerState.id,
          title: title,
          label: title,
          icon: builders.cloudOutlineIcon,
          remoteHost: host,
          shellService: shell,
        );
      case DockerTabKind.command:
        if (dockerState.command == null || dockerState.title == null) {
          return null;
        }
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = host != null ? builders.shellForHost(host) : null;
        final command = _sanitizeExec(dockerState.command!);
        final containerId = dockerState.containerId;
        final containerName = dockerState.containerName;
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builders.buildEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: builders.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              containerId: containerId,
              containerName: containerName,
              contextName: dockerState.contextName,
            );
            builders.onOpenTab(tab);
          };
        }
        return builders.buildCommand(
          id: dockerState.id,
          title: dockerState.title!,
          label: dockerState.title!,
          command: command,
          icon: builders.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => builders.closeTab(dockerState.id),
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
        final shell = host != null ? builders.shellForHost(host) : null;
        final command = _sanitizeExec(dockerState.command!);
        final containerId = dockerState.containerId;
        final containerName = dockerState.containerName;
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builders.buildEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: builders.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              containerId: containerId,
              containerName: containerName,
              contextName: dockerState.contextName,
            );
            builders.onOpenTab(tab);
          };
        }
        return builders.buildCommand(
          id: dockerState.id,
          title: dockerState.title!,
          label: dockerState.title!,
          command: command,
          icon: builders.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => builders.closeTab(dockerState.id),
          kind: dockerState.kind,
          containerId: containerId,
          containerName: containerName,
          contextName: dockerState.contextName,
          onOpenEditorTab: openEditorTab,
        );
      case DockerTabKind.composeLogs:
        if (dockerState.project == null) return null;
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = host != null ? builders.shellForHost(host) : null;
        final composeBase =
            dockerState.command ?? 'docker compose -p "${dockerState.project}"';
        final title =
            dockerState.title ?? 'Compose logs: ${dockerState.project}';
        Future<void> Function(String path, String content)? openEditorTab;
        if (host != null && shell != null) {
          openEditorTab = (path, content) async {
            final tab = builders.buildEditor(
              id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
              title: path,
              label: path,
              icon: builders.editorIcon,
              host: host,
              shellService: shell,
              path: path,
              initialContent: content,
              contextName: dockerState.contextName,
            );
            builders.onOpenTab(tab);
          };
        }
        return builders.buildComposeLogs(
          id: dockerState.id,
          title: title,
          label: title,
          icon: builders.composeIcon,
          composeBase: composeBase,
          project: dockerState.project!,
          services: dockerState.services,
          host: host,
          shellService: shell,
          contextName: dockerState.contextName,
          onExit: () => builders.closeTab(dockerState.id),
          tailLines: settingsController.settings.dockerLogsTailClamped,
          onOpenEditorTab: openEditorTab,
        );
      case DockerTabKind.containerExplorer:
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = builders.containerShell(
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
          dockerContextName: builders.dockerContextNameFor(
            explorerHost,
            dockerState.contextName,
          ),
        );
        return builders.buildExplorer(
          id: dockerState.id,
          title:
              'Explore ${dockerState.containerName ?? dockerState.containerId ?? explorerHost.name}',
          label: 'Explorer',
          icon: builders.explorerIcon,
          host: explorerHost,
          shellService: shell,
          explorerContext: explorerContext,
          containerId: containerId,
          containerName: dockerState.containerName,
          dockerContextName: dockerState.contextName,
          onOpenTab: builders.onOpenTab,
          initialPath: dockerState.path,
          onPathChanged: (path) =>
              builders.onExplorerPathChanged?.call(dockerState.id, path),
        );
      case DockerTabKind.containerEditor:
        if (dockerState.path == null || dockerState.containerId == null) {
          return null;
        }
        final host = _hostByName(hosts, dockerState.hostName);
        final shell = builders.containerShell(
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
        return builders.buildEditor(
          id: dockerState.id,
          title: 'Edit ${dockerState.path}',
          label: dockerState.path ?? 'Editor',
          icon: builders.editorIcon,
          host: editorHost,
          shellService: shell,
          path: dockerState.path!,
          containerId: dockerState.containerId,
          containerName: dockerState.containerName,
          contextName: dockerState.contextName,
        );
    }
  }

  Future<List<RemoteDockerStatus>> loadCachedReady(
    Future<List<SshHost>> hostsFuture,
  ) async {
    final readyNames = endpointCache.read().toSet();
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
          ),
        )
        .toList();
  }

  Future<List<RemoteDockerStatus>> discoverRemoteStatuses({
    required Future<List<SshHost>> hostsFuture,
    required Future<RemoteDockerStatus> Function(SshHost host) probeHost,
    bool manual = false,
    bool cancelled = false,
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
    if (hosts.isEmpty) {
      return const [];
    }
    final results = List<RemoteDockerStatus?>.filled(
      hosts.length,
      null,
      growable: false,
    );
    var nextIndex = 0;

    Future<void> runNext() async {
      if (cancelled) return;
      final current = nextIndex++;
      if (current >= hosts.length) return;
      final host = hosts[current];
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
        );
      }
      await runNext();
    }

    final workers = List.generate(
      maxConcurrent < hosts.length ? maxConcurrent : hosts.length,
      (_) => runNext(),
    );
    await Future.wait(workers);
    final statuses = results.whereType<RemoteDockerStatus>().toList();
    final ready = statuses.where((s) => s.available).toList();
    if (manual && !cancelled && ready.isNotEmpty) {
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

  /// Derives a [TabState] from a tab body or its existing workspaceState
  /// (if provided).
  TabState? tabStateFromBody(
    String id,
    Widget body, {
    TabState? workspaceState,
  }) {
    if (workspaceState != null) {
      return workspaceState;
    }
    if (body is EnginePicker) {
      return TabState(id: id, kind: DockerTabKind.picker.name);
    }
    if (body is DockerOverview) {
      if (body.remoteHost != null) {
        return TabState(
          id: id,
          kind: DockerTabKind.hostOverview.name,
          hostName: body.remoteHost!.name,
        );
      }
      return TabState(
        id: id,
        kind: DockerTabKind.contextOverview.name,
        contextName: body.contextName,
      );
    }
    if (body is DockerResources) {
      if (body.remoteHost != null) {
        return TabState(
          id: id,
          kind: DockerTabKind.hostResources.name,
          hostName: body.remoteHost!.name,
        );
      }
      return TabState(
        id: id,
        kind: DockerTabKind.contextResources.name,
        contextName: body.contextName,
      );
    }
    if (body is DockerCommandTerminal) {
      return TabState(
        id: id,
        kind: DockerTabKind.command.name,
        hostName: body.host?.name,
        command: body.command,
        title: body.title,
        label: body.title,
      );
    }
    if (body is ComposeLogsTerminal) {
      final base = workspaceState?.command ?? body.composeBase;
      final title = workspaceState?.title ?? 'Compose logs: ${body.project}';
      return TabState(
        id: id,
        kind: DockerTabKind.composeLogs.name,
        hostName: body.host?.name,
        contextName: workspaceState?.contextName,
        command: base,
        project: body.project,
        services: body.services,
        title: title,
        label: workspaceState?.label ?? title,
      );
    }
    if (body is FileExplorerTab) {
      return TabState(
        id: id,
        kind: DockerTabKind.containerExplorer.name,
        hostName: body.host.name,
        path: workspaceState?.path,
        extra: workspaceState?.extra,
      );
    }
    if (body is RemoteFileEditorLoader) {
      return TabState(
        id: id,
        kind: DockerTabKind.containerEditor.name,
        hostName: body.host.name,
        path: body.path,
        extra: workspaceState?.extra,
      );
    }
    return null;
  }

  DockerWorkspaceState currentWorkspaceState({
    required List<EngineTab> tabs,
    required int selectedIndex,
    required Map<String, TabState> explicitStates,
  }) {
    final persisted = <TabState>[];
    var selectedPersistedIndex = 0;
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      TabState? workspaceState;
      if (tab.workspaceState is TabState) {
        workspaceState = tab.workspaceState as TabState;
      }
      var state = explicitStates[tab.id] ?? workspaceState;
      state ??= tabStateFromBody(
        tab.id,
        tab.body,
        workspaceState: workspaceState,
      );
      if (state != null) {
        if (i == selectedIndex) {
          selectedPersistedIndex = persisted.length;
        }
        persisted.add(state);
      }
    }
    final clampedSelected = persisted.isEmpty
        ? 0
        : selectedPersistedIndex.clamp(0, persisted.length - 1);
    return DockerWorkspaceState(
      tabs: persisted,
      selectedIndex: clampedSelected,
    );
  }

  TabState copyStateWithId(TabState state, String id) {
    return _copyStateWithId(state, id);
  }

  TabState _copyStateWithId(TabState state, String id) {
    return state.copyWith(
      id: id,
      extra: state.extra == null
          ? null
          : Map<String, dynamic>.from(state.extra!),
    );
  }
}

class TabBuilders {
  const TabBuilders({
    required this.buildPlaceholder,
    required this.buildPicker,
    required this.buildOverview,
    required this.buildResources,
    required this.buildCommand,
    required this.buildComposeLogs,
    required this.buildExplorer,
    required this.buildEditor,
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

  final EngineTab Function({required String id}) buildPlaceholder;
  final EngineTab Function({required String id}) buildPicker;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
  })
  buildOverview;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
  })
  buildResources;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required String command,
    required IconData icon,
    required SshHost? host,
    required RemoteShellService? shellService,
    VoidCallback? onExit,
    DockerTabKind kind,
    String? containerId,
    String? containerName,
    String? contextName,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  })
  buildCommand;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required String composeBase,
    required String project,
    required List<String> services,
    required SshHost? host,
    required RemoteShellService? shellService,
    String? contextName,
    VoidCallback? onExit,
    required int tailLines,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  })
  buildComposeLogs;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required SshHost host,
    required RemoteShellService shellService,
    required ExplorerContext explorerContext,
    required String containerId,
    String? containerName,
    String? dockerContextName,
    required void Function(EngineTab tab) onOpenTab,
    String? initialPath,
    void Function(String path)? onPathChanged,
  })
  buildExplorer;
  final EngineTab Function({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required SshHost host,
    required RemoteShellService shellService,
    required String path,
    String? initialContent,
    String? containerId,
    String? containerName,
    String? contextName,
  })
  buildEditor;
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
  final void Function(EngineTab tab) onOpenTab;
  final void Function(String tabId, String path)? onExplorerPathChanged;
}

class RestoredDockerTabs {
  const RestoredDockerTabs({required this.tabs, required this.states});

  final List<EngineTab> tabs;
  final Map<String, TabState> states;
}
