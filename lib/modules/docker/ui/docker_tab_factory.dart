import 'package:flutter/material.dart';

import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'engine_tab.dart';
import 'widgets/docker_command_terminal.dart';
import 'widgets/docker_overview.dart';
import 'widgets/docker_resources.dart';

class DockerTabFactory {
  const DockerTabFactory({
    required this.docker,
    required this.settingsController,
    required this.trashManager,
    required this.keyService,
  });

  final DockerClientService docker;
  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final BuiltInSshKeyService keyService;

  EngineTab overview({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    required void Function(EngineTab tab) onOpenTab,
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
      tabFactory: this,
    );
    return EngineTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      body: body,
      canDrag: true,
      canRename: true,
      workspaceState: DockerTabState(
        id: id,
        kind: contextName != null
            ? DockerTabKind.contextOverview
            : DockerTabKind.hostOverview,
        contextName: contextName,
        hostName: remoteHost?.name,
      ),
      optionsController: controller,
    );
  }

  EngineTab resources({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
    required void Function(EngineTab tab) onOpenTab,
    required void Function(String id) onCloseTab,
  }) {
    final controller = TabOptionsController();
    final body = DockerResources(
      docker: docker,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      onOpenTab: onOpenTab,
      onCloseTab: onCloseTab,
      optionsController: controller,
      tabFactory: this,
    );
    return EngineTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      body: body,
      canDrag: true,
      canRename: true,
      workspaceState: DockerTabState(
        id: id,
        kind: contextName != null
            ? DockerTabKind.contextResources
            : DockerTabKind.hostResources,
        contextName: contextName,
        hostName: remoteHost?.name,
      ),
      optionsController: controller,
    );
  }

  EngineTab explorer({
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
  }) {
    final controller = CompositeTabOptionsController();
    return EngineTab(
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
        trashManager: trashManager,
        keyService: keyService,
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
      workspaceState: DockerTabState(
        id: id,
        kind: DockerTabKind.containerExplorer,
        hostName: host.name,
        containerId: containerId,
        containerName: containerName,
        contextName: dockerContextName,
      ),
      optionsController: controller,
    );
  }

  EngineTab containerEditor({
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
    return EngineTab(
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
        optionsController: controller,
        initialContent: initialContent,
      ),
      workspaceState: DockerTabState(
        id: id,
        kind: DockerTabKind.containerEditor,
        hostName: host.name,
        containerId: containerId,
        containerName: containerName,
        contextName: contextName,
        path: path,
      ),
      optionsController: controller,
    );
  }

  EngineTab commandTerminal({
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
  }) {
    final controller = CompositeTabOptionsController();
    return EngineTab(
      id: id,
      title: title,
      label: label,
      icon: icon,
      canDrag: true,
      canRename: true,
      body: DockerCommandTerminal(
        command: command,
        title: title,
        host: host,
        shellService: shellService,
        settingsController: settingsController,
        onExit: onExit,
        optionsController: controller,
      ),
      workspaceState: DockerTabState(
        id: id,
        kind: kind,
        hostName: host?.name,
        command: command,
        title: title,
        containerId: containerId,
        containerName: containerName,
        contextName: contextName,
      ),
      optionsController: controller,
    );
  }

  EngineTab composeLogs({
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
  }) {
    final controller = CompositeTabOptionsController();
    return EngineTab(
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
        host: host,
        shellService: shellService,
        onExit: onExit,
        optionsController: controller,
      ),
      workspaceState: DockerTabState(
        id: id,
        kind: DockerTabKind.composeLogs,
        hostName: host?.name,
        contextName: contextName,
        project: project,
        services: services,
        title: title,
        command: composeBase,
      ),
      optionsController: controller,
    );
  }

  EngineTab trash({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    required ExplorerContext explorerContext,
    required RemoteShellService shellService,
  }) {
    return EngineTab(
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
    );
  }
}
