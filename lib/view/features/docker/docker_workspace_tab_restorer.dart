import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';

class DockerWorkspaceTabRestorer {
  const DockerWorkspaceTabRestorer();

  WorkspaceTab? buildTab({
    required TabState state,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required Widget Function(String tabId) pickerBuilder,
    required TabBuilders callbacks,
  }) {
    final dockerState = decodeState(state);
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
        return _buildHostDashboardTab(
          dockerState: dockerState,
          hosts: hosts,
          builder: builder,
          callbacks: callbacks,
        );
      case DockerTabKind.command:
      case DockerTabKind.containerShell:
      case DockerTabKind.containerLogs:
        return _buildCommandTab(
          dockerState: dockerState,
          hosts: hosts,
          builder: builder,
          callbacks: callbacks,
        );
      case DockerTabKind.composeLogs:
        return _buildComposeLogsTab(
          dockerState: dockerState,
          hosts: hosts,
          builder: builder,
          callbacks: callbacks,
        );
      case DockerTabKind.containerExplorer:
        return _buildExplorerTab(
          dockerState: dockerState,
          hosts: hosts,
          builder: builder,
          callbacks: callbacks,
        );
      case DockerTabKind.containerEditor:
        return _buildEditorTab(
          dockerState: dockerState,
          hosts: hosts,
          builder: builder,
          callbacks: callbacks,
        );
    }
  }

  DockerTabState? decodeState(TabState state) {
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

  WorkspaceTab? _buildHostDashboardTab({
    required DockerTabState dockerState,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
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
  }

  WorkspaceTab? _buildCommandTab({
    required DockerTabState dockerState,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
    if (dockerState.command == null || dockerState.title == null) return null;
    final host = _hostByName(hosts, dockerState.hostName);
    final shell = host != null ? callbacks.shellForHost(host) : null;
    final containerId = dockerState.containerId;
    final containerName = dockerState.containerName;

    return builder.commandTerminal(
      id: dockerState.id,
      title: dockerState.title!,
      label: dockerState.title!,
      command: _sanitizeExec(dockerState.command!),
      icon: callbacks.commandIcon,
      host: host,
      shellService: shell,
      onExit: () => callbacks.closeTab(dockerState.id),
      kind: dockerState.kind,
      containerId: containerId,
      containerName: containerName,
      contextName: dockerState.contextName,
      onOpenEditorTab: _editorTabOpener(
        dockerState: dockerState,
        host: host,
        shellService: shell,
        builder: builder,
        callbacks: callbacks,
      ),
    );
  }

  WorkspaceTab? _buildComposeLogsTab({
    required DockerTabState dockerState,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
    if (dockerState.project == null) return null;
    final host = _hostByName(hosts, dockerState.hostName);
    final shell = host != null ? callbacks.shellForHost(host) : null;
    final composeBase =
        dockerState.command ?? 'docker compose -p "${dockerState.project}"';
    final title = dockerState.title ?? 'Compose logs: ${dockerState.project}';

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
      tailLines: builder.settingsController.settings.dockerLogsTailClamped,
      onOpenEditorTab: _editorTabOpener(
        dockerState: dockerState,
        host: host,
        shellService: shell,
        builder: builder,
        callbacks: callbacks,
      ),
    );
  }

  WorkspaceTab? _buildExplorerTab({
    required DockerTabState dockerState,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
    final host = _hostByName(hosts, dockerState.hostName);
    final shell = callbacks.containerShell(
      host,
      dockerState.containerId,
      contextName: dockerState.contextName,
    );
    if (shell == null) return null;
    final explorerHost = _resolvedDockerHost(host);
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
  }

  WorkspaceTab? _buildEditorTab({
    required DockerTabState dockerState,
    required List<SshHost> hosts,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
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
    final editorHost = _resolvedDockerHost(host);
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

  Future<void> Function(String path, String content)? _editorTabOpener({
    required DockerTabState dockerState,
    required SshHost? host,
    required RemoteShellService? shellService,
    required DockerTabBuilder builder,
    required TabBuilders callbacks,
  }) {
    if (host == null || shellService == null) {
      return null;
    }
    return (path, content) async {
      final tab = builder.containerEditor(
        id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
        title: path,
        label: path,
        icon: callbacks.editorIcon,
        host: host,
        shellService: shellService,
        path: path,
        initialContent: content,
        containerId: dockerState.containerId,
        containerName: dockerState.containerName,
        contextName: dockerState.contextName,
      );
      callbacks.onOpenTab(tab);
    };
  }

  SshHost _resolvedDockerHost(SshHost? host) {
    return host ??
        const SshHost(
          name: 'local',
          hostname: 'localhost',
          port: 22,
          available: true,
          user: null,
          identityFiles: <String>[],
          source: 'local',
        );
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
