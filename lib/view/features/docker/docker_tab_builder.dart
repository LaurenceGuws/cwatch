import 'package:flutter/material.dart';

import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/controller/controllers/remote_file_editor_controller.dart';
import 'package:cwatch/view/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/controller/di/bindings/file_explorer_binding.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/controller/di/bindings/trash_tab_binding.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/controller/di/bindings/docker_command_terminal_binding.dart';
import 'widgets/docker_command_terminal.dart';
import 'widgets/docker_overview.dart';
import 'package:cwatch/controller/di/bindings/docker_overview_binding.dart';
import 'package:cwatch/controller/di/bindings/docker_resources_binding.dart';
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
    final body = Builder(
      builder: (context) {
        final binding = const DockerOverviewBinding();
        final uiAdapter = binding.createUiAdapter(context: context);
        final overviewController = binding.createController(
          docker: docker,
          contextName: contextName,
          remoteHost: remoteHost,
          shellService: shellService,
        );
        final actions = binding.createActionsController(
          context: context,
          controller: overviewController,
          docker: docker,
          tabBuilder: this,
          onOpenTab: onOpenTab,
          onCloseTab: onCloseTab,
          settingsController: settingsController,
          portForwardService: portForwardService,
          keyService: keyService,
          uiAdapter: uiAdapter,
        );
        return DockerOverview(
          controller: overviewController,
          actions: actions,
          uiAdapter: uiAdapter,
          settingsController: settingsController,
          optionsController: controller,
        );
      },
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
      body: Builder(
        builder: (context) {
          final settingsUiAdapter = const SettingsBinding().createUiAdapter(
            context: context,
          );
          final explorerSettingsController = const SettingsBinding()
              .createController(
                settingsController: settingsController,
                keyService: keyService,
                hostsFuture: hostsFuture,
                uiAdapter: settingsUiAdapter,
              );
          final explorerController = const FileExplorerBinding().create(
            context: context,
            host: host,
            explorerContext: explorerContext,
            shellService: shellService,
            settingsController: settingsController,
            trashManager: trashManager,
            initialPath: initialPath,
            onPathChanged: onPathChanged,
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
          );
          return FileExplorerTab(
            controller: explorerController,
            settingsController: explorerSettingsController,
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
            onOpenTerminalTab: null,
            optionsController: controller,
          );
        },
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
        path: path,
        controllerBuilder: (uiAdapter) => RemoteFileEditorController(
          host: host,
          shellService: shellService,
          path: path,
          uiAdapter: uiAdapter,
        ),
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
      body: Builder(
        builder: (context) {
          final controller = const TrashTabBinding().create(
            context: context,
            manager: trashManager,
            shellService: shellService,
            keyService: keyService,
            explorerContext: explorerContext,
          );
          return TrashTab(controller: controller);
        },
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
