import 'package:flutter/widgets.dart';

import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/modules/docker/ui/engine_tab.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_command_terminal.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_engine_picker.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_overview.dart';
import 'package:cwatch/modules/docker/ui/widgets/docker_resources.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/models/explorer_context.dart';

/// Small controller to centralise Docker workspace persistence and tab state
/// derivation, mirroring the server workspace controller pattern.
class DockerWorkspaceController {
  DockerWorkspaceController({required this.settingsController}) {
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: (settings) => settings.dockerWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(dockerWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  late final WorkspacePersistence<DockerWorkspaceState> workspacePersistence;

  /// Result of rebuilding tabs from persisted workspace.
  RestoredDockerTabs buildTabsFromState({
    required DockerWorkspaceState workspace,
    required List<SshHost> hosts,
    required EngineTab? Function(DockerTabState state) buildTab,
  }) {
    final tabs = <EngineTab>[];
    final states = <String, DockerTabState>{};
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
    required DockerTabState state,
    required List<SshHost> hosts,
    required TabBuilders builders,
  }) {
    switch (state.kind) {
      case DockerTabKind.placeholder:
        return builders.buildPlaceholder(id: state.id);
      case DockerTabKind.picker:
        return builders.buildPicker(id: state.id);
      case DockerTabKind.contextOverview:
        if (state.contextName == null) return null;
        final title = state.title ?? state.contextName!;
        return builders.buildOverview(
          id: state.id,
          title: title,
          label: title,
          icon: builders.cloudIcon,
          contextName: state.contextName,
        );
      case DockerTabKind.contextResources:
        if (state.contextName == null) return null;
        final title = state.title ?? state.contextName!;
        return builders.buildResources(
          id: state.id,
          title: title,
          label: title,
          icon: builders.cloudIcon,
          contextName: state.contextName,
        );
      case DockerTabKind.hostOverview:
      case DockerTabKind.hostResources:
        if (state.hostName == null) return null;
        final host = _hostByName(hosts, state.hostName);
        if (host == null || host.name.isEmpty) return null;
        final shell = builders.shellForHost(host);
        final title = state.title ?? host.name;
        final builder =
            state.kind == DockerTabKind.hostResources ? builders.buildResources : builders.buildOverview;
        return builder(
          id: state.id,
          title: title,
          label: title,
          icon: builders.cloudOutlineIcon,
          remoteHost: host,
          shellService: shell,
        );
      case DockerTabKind.command:
        if (state.command == null || state.title == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? builders.shellForHost(host) : null;
        final command = _sanitizeExec(state.command!);
        return builders.buildCommand(
          id: state.id,
          title: state.title!,
          label: state.title!,
          command: command,
          icon: builders.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => builders.closeTab(state.id),
          kind: DockerTabKind.command,
        );
      case DockerTabKind.containerShell:
      case DockerTabKind.containerLogs:
        if (state.command == null || state.title == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? builders.shellForHost(host) : null;
        final command = _sanitizeExec(state.command!);
        return builders.buildCommand(
          id: state.id,
          title: state.title!,
          label: state.title!,
          command: command,
          icon: builders.commandIcon,
          host: host,
          shellService: shell,
          onExit: () => builders.closeTab(state.id),
          kind: state.kind,
        );
      case DockerTabKind.composeLogs:
        if (state.project == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? builders.shellForHost(host) : null;
        final composeBase = state.command ?? 'docker compose -p "${state.project}"';
        final title = state.title ?? 'Compose logs: ${state.project}';
        return builders.buildComposeLogs(
          id: state.id,
          title: title,
          label: title,
          icon: builders.composeIcon,
          composeBase: composeBase,
          project: state.project!,
          services: state.services,
          host: host,
          shellService: shell,
          contextName: state.contextName,
          onExit: () => builders.closeTab(state.id),
        );
      case DockerTabKind.containerExplorer:
        final host = _hostByName(hosts, state.hostName);
        final shell = builders.containerShell(
          host,
          state.containerId,
          contextName: state.contextName,
        );
        if (shell == null) return null;
        final explorerHost = host ??
            const SshHost(
              name: 'local',
              hostname: 'localhost',
              port: 22,
              available: true,
              user: null,
              identityFiles: <String>[],
              source: 'local',
            );
        final containerId = state.containerId ?? '';
        final explorerContext = ExplorerContext.dockerContainer(
          host: explorerHost,
          containerId: containerId,
          containerName: state.containerName,
          dockerContextName: builders.dockerContextNameFor(
            explorerHost,
            state.contextName,
          ),
        );
        return builders.buildExplorer(
          id: state.id,
          title: 'Explore ${state.containerName ?? state.containerId ?? explorerHost.name}',
          label: 'Explorer',
          icon: builders.explorerIcon,
          host: explorerHost,
          shellService: shell,
          explorerContext: explorerContext,
          containerId: containerId,
          containerName: state.containerName,
          dockerContextName: state.contextName,
          onOpenTab: builders.onOpenTab,
        );
      case DockerTabKind.containerEditor:
        if (state.path == null || state.containerId == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = builders.containerShell(
          host,
          state.containerId,
          contextName: state.contextName,
        );
        if (shell == null) return null;
        final editorHost = host ??
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
          id: state.id,
          title: 'Edit ${state.path}',
          label: state.path ?? 'Editor',
          icon: builders.editorIcon,
          host: editorHost,
          shellService: shell,
          path: state.path!,
          containerId: state.containerId,
          containerName: state.containerName,
          contextName: state.contextName,
        );
    }
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


  /// Derives a [DockerTabState] from a tab body or its existing workspaceState
  /// (if provided).
  DockerTabState? tabStateFromBody(
    String id,
    Widget body, {
    DockerTabState? workspaceState,
  }) {
    if (workspaceState != null) {
      return workspaceState;
    }
    if (body is EnginePicker) {
      return DockerTabState(id: id, kind: DockerTabKind.picker);
    }
    if (body is DockerOverview) {
      if (body.remoteHost != null) {
        return DockerTabState(
          id: id,
          kind: DockerTabKind.hostOverview,
          hostName: body.remoteHost!.name,
        );
      }
      return DockerTabState(
        id: id,
        kind: DockerTabKind.contextOverview,
        contextName: body.contextName,
      );
    }
    if (body is DockerResources) {
      if (body.remoteHost != null) {
        return DockerTabState(
          id: id,
          kind: DockerTabKind.hostResources,
          hostName: body.remoteHost!.name,
        );
      }
      return DockerTabState(
        id: id,
        kind: DockerTabKind.contextResources,
        contextName: body.contextName,
      );
    }
    if (body is DockerCommandTerminal) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.command,
        hostName: body.host?.name,
        command: body.command,
        title: body.title,
      );
    }
    if (body is ComposeLogsTerminal) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.composeLogs,
        hostName: body.host?.name,
        contextName: workspaceState?.contextName,
        command: workspaceState?.command ?? body.composeBase,
        project: body.project,
        services: body.services,
      );
    }
    if (body is FileExplorerTab) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.containerExplorer,
        hostName: body.host.name,
      );
    }
    if (body is RemoteFileEditorLoader) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.containerEditor,
        hostName: body.host.name,
        path: body.path,
      );
    }
    return null;
  }

  DockerWorkspaceState currentWorkspaceState({
    required List<EngineTab> tabs,
    required int selectedIndex,
    required Map<String, DockerTabState> explicitStates,
  }) {
    final persisted = <DockerTabState>[];
    var selectedPersistedIndex = 0;
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final workspaceState = tab.workspaceState is DockerTabState
          ? tab.workspaceState as DockerTabState
          : null;
      var state = explicitStates[tab.id] ?? workspaceState;
      state ??= tabStateFromBody(tab.id, tab.body, workspaceState: workspaceState);
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

  DockerTabState copyStateWithId(DockerTabState state, String id) {
    return _copyStateWithId(state, id);
  }

  DockerTabState _copyStateWithId(DockerTabState state, String id) {
    return DockerTabState(
      id: id,
      kind: state.kind,
      contextName: state.contextName,
      hostName: state.hostName,
      containerId: state.containerId,
      containerName: state.containerName,
      command: state.command,
      title: state.title,
      path: state.path,
      project: state.project,
      services: state.services,
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
  });

  final EngineTab Function({required String id}) buildPlaceholder;
  final EngineTab Function({required String id}) buildPicker;
  final EngineTab Function({required String id, required String title, required String label, required IconData icon, String? contextName, SshHost? remoteHost, RemoteShellService? shellService}) buildOverview;
  final EngineTab Function({required String id, required String title, required String label, required IconData icon, String? contextName, SshHost? remoteHost, RemoteShellService? shellService}) buildResources;
  final EngineTab Function({required String id, required String title, required String label, required String command, required IconData icon, required SshHost? host, required RemoteShellService? shellService, VoidCallback? onExit, DockerTabKind kind, String? containerId, String? containerName, String? contextName}) buildCommand;
  final EngineTab Function({required String id, required String title, required String label, required IconData icon, required String composeBase, required String project, required List<String> services, required SshHost? host, required RemoteShellService? shellService, String? contextName, VoidCallback? onExit}) buildComposeLogs;
  final EngineTab Function({required String id, required String title, required String label, required IconData icon, required SshHost host, required RemoteShellService shellService, required ExplorerContext explorerContext, required String containerId, String? containerName, String? dockerContextName, required void Function(EngineTab tab) onOpenTab}) buildExplorer;
  final EngineTab Function({required String id, required String title, required String label, required IconData icon, required SshHost host, required RemoteShellService shellService, required String path, String? initialContent, String? containerId, String? containerName, String? contextName}) buildEditor;
  final IconData cloudIcon;
  final IconData cloudOutlineIcon;
  final IconData commandIcon;
  final IconData composeIcon;
  final IconData explorerIcon;
  final IconData editorIcon;
  final RemoteShellService? Function(SshHost host) shellForHost;
  final RemoteShellService? Function(SshHost? host, String? containerId, {String? contextName}) containerShell;
  final String Function(SshHost host, String? contextName) dockerContextNameFor;
  final void Function(String id) closeTab;
  final void Function(EngineTab tab) onOpenTab;
}

class RestoredDockerTabs {
  const RestoredDockerTabs({required this.tabs, required this.states});

  final List<EngineTab> tabs;
  final Map<String, DockerTabState> states;
}
