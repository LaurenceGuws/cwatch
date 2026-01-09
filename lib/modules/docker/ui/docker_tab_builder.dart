import 'package:flutter/material.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/ui/bindings/docker_command_terminal_binding.dart';
import 'widgets/docker_command_terminal.dart';
import 'widgets/docker_overview.dart';
import 'package:cwatch/ui/bindings/docker_resources_binding.dart';
import 'widgets/docker_resources.dart';

class DockerTabBuilder {
  const DockerTabBuilder({
    required this.docker,
    required this.settingsController,
    required this.trashManager,
    required this.keyService,
    required this.portForwardService,
    required this.hostsFuture,
  });

  final DockerClientService docker;
  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final BuiltInSshKeyService keyService;
  final PortForwardService portForwardService;
  final Future<List<SshHost>> hostsFuture;

  WorkspaceTab overview({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    required void Function(WorkspaceTab tab) onOpenTab,
    required void Function(String id) onCloseTab,
  }) {
    final controller = TabOptionsController();
    final body = DockerOverview(
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      trashManager: trashManager,
      keyService: keyService,
      settingsController: settingsController,
      onOpenTab: onOpenTab,
      onCloseTab: onCloseTab,
      optionsController: controller,
      tabBuilder: this,
      portForwardService: portForwardService,
    );
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      body: body,
      canDrag: true,
      canRename: true,
      workspaceState: DockerTabData(
        kind: contextName != null
            ? DockerTabKind.contextOverview
            : DockerTabKind.hostOverview,
        persistedState: TabState(
          id: id,
          kind: contextName != null
              ? DockerTabKind.contextOverview.name
              : DockerTabKind.hostOverview.name,
          contextName: contextName,
          hostName: remoteHost?.name,
          title: title,
          label: label,
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab resources({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    required void Function(WorkspaceTab tab) onOpenTab,
    required void Function(String id) onCloseTab,
  }) {
    final controller = TabOptionsController();
    final resourcesController = const DockerResourcesBinding().create(
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
    );
    final body = DockerResources(
      controller: resourcesController,
      onOpenTab: onOpenTab,
      onCloseTab: onCloseTab,
      optionsController: controller,
      tabBuilder: this,
    );
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      body: body,
      canDrag: true,
      canRename: true,
      workspaceState: DockerTabData(
        kind: contextName != null
            ? DockerTabKind.contextResources
            : DockerTabKind.hostResources,
        persistedState: TabState(
          id: id,
          kind: contextName != null
              ? DockerTabKind.contextResources.name
              : DockerTabKind.hostResources.name,
          contextName: contextName,
          hostName: remoteHost?.name,
          title: title,
          label: label,
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab explorer({
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
    required void Function(WorkspaceTab tab) onOpenTab,
    String? initialPath,
    void Function(String path)? onPathChanged,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: FileExplorerTab(
        host: host,
        explorerContext: explorerContext,
        shellService: shellService,
        settingsController: settingsController,
        keyService: keyService,
        hostsFuture: hostsFuture,
        trashManager: trashManager,
        initialPath: initialPath,
        onPathChanged: onPathChanged,
        onOpenTrash: (ctx) => onOpenTab(
          trash(
            id: 'trash-${ctx.host.name}-${DateTime.now().microsecondsSinceEpoch}',
            title: 'Trash • ${ctx.host.name}',
            label: 'Trash',
            icon: Icons.delete,
            explorerContext: ctx,
            shellService: shellService,
          ),
        ),
        onOpenEditorTab: (path, content) async {
          final editorTab = containerEditor(
            id: 'editor-${path.hashCode}-${DateTime.now().microsecondsSinceEpoch}',
            title: 'Edit $path',
            label: path,
            icon: Icons.edit,
            host: host,
            shellService: shellService,
            path: path,
            initialContent: content,
            containerId: containerId,
            containerName: containerName,
            contextName: dockerContextName,
          );
          onOpenTab(editorTab);
        },
        onOpenTerminalTab: null,
        optionsController: controller,
      ),
      workspaceState: DockerTabData(
        kind: DockerTabKind.containerExplorer,
        persistedState: TabState(
          id: id,
          kind: DockerTabKind.containerExplorer.name,
          hostName: host.name,
          contextName: dockerContextName,
          title: title,
          label: label,
          extra: {
            if (containerId.isNotEmpty) 'containerId': containerId,
            if (containerName != null && containerName.isNotEmpty)
              'containerName': containerName,
          },
          path: initialPath,
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab containerEditor({
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
  }) {
    final controller = TabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: RemoteFileEditorLoader(
        host: host,
        shellService: shellService,
        path: path,
        settingsController: settingsController,
        keyService: keyService,
        hostsFuture: hostsFuture,
        optionsController: controller,
        initialContent: initialContent,
      ),
      workspaceState: DockerTabData(
        kind: DockerTabKind.containerEditor,
        persistedState: TabState(
          id: id,
          kind: DockerTabKind.containerEditor.name,
          hostName: host.name,
          contextName: contextName,
          path: path,
          title: title,
          label: label,
          extra: {
            if (containerId != null && containerId.isNotEmpty)
              'containerId': containerId,
            if (containerName != null && containerName.isNotEmpty)
              'containerName': containerName,
          },
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab commandTerminal({
    required String id,
    required String title,
    required String label,
    required String command,
    required IconData icon,
    required SshHost? host,
    required RemoteShellService? shellService,
    VoidCallback? onExit,
    DockerTabKind kind = DockerTabKind.command,
    String? containerId,
    String? containerName,
    String? contextName,
    Future<void> Function(String path, String content)? onOpenEditorTab,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: DockerCommandTerminal(
        controller: const DockerCommandTerminalBinding().create(
          command: command,
          host: host,
          shellService: shellService,
        ),
        title: title,
        settingsController: settingsController,
        onExit: onExit,
        optionsController: controller,
        onOpenEditorTab: onOpenEditorTab,
      ),

      workspaceState: DockerTabData(
        kind: kind,
        persistedState: TabState(
          id: id,
          kind: kind.name,
          hostName: host?.name,
          command: command,
          title: title,
          label: label,
          contextName: contextName,
          extra: {
            if (containerId != null && containerId.isNotEmpty)
              'containerId': containerId,
            if (containerName != null && containerName.isNotEmpty)
              'containerName': containerName,
          },
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab composeLogs({
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
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: ComposeLogsTerminal(
        composeBase: composeBase,
        project: project,
        services: services,
        controllerBuilder: (command) => const DockerCommandTerminalBinding()
            .create(command: command, host: host, shellService: shellService),
        onExit: onExit,
        optionsController: controller,
        tailLines: tailLines,
        settingsController: settingsController,
        onOpenEditorTab: onOpenEditorTab,
      ),
      workspaceState: DockerTabData(
        kind: DockerTabKind.composeLogs,
        persistedState: TabState(
          id: id,
          kind: DockerTabKind.composeLogs.name,
          hostName: host?.name,
          contextName: contextName,
          project: project,
          services: services,
          title: title,
          command: composeBase,
          label: label,
        ),
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab trash({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required ExplorerContext explorerContext,
    required RemoteShellService shellService,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canRename: true,
      body: TrashTab(
        manager: trashManager,
        shellService: shellService,
        keyService: keyService,
        context: explorerContext,
      ),
      optionsController: controller,
    );
  }

  WorkspaceTab placeholder({required String id, Widget? body}) {
    return WorkspaceTab(
      id: id,
      title: 'Docker',
      label: 'Docker',
      icon: Icons.list,
      body: body ?? const SizedBox.shrink(),
      canDrag: false,
      canRename: false,
      workspaceState: DockerTabData(
        kind: DockerTabKind.placeholder,
        persistedState: TabState(id: id, kind: DockerTabKind.placeholder.name),
      ),
    );
  }

  WorkspaceTab picker({required String id, Widget? body}) {
    return WorkspaceTab(
      id: id,
      title: 'Docker',
      label: 'Docker',
      icon: Icons.list,
      body: body ?? const SizedBox.shrink(),
      canDrag: false,
      canRename: false,
      workspaceState: DockerTabData(
        kind: DockerTabKind.picker,
        persistedState: TabState(id: id, kind: DockerTabKind.picker.name),
      ),
    );
  }
}

class DockerTabData {
  const DockerTabData({required this.kind, required this.persistedState});

  final DockerTabKind kind;
  final TabState persistedState;
}
