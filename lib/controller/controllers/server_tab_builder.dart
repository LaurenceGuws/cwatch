import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/remote_file_editor_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/di/bindings/file_explorer_binding.dart';
import 'package:cwatch/controller/di/bindings/resources_binding.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/controller/di/bindings/terminal_tab_binding.dart';
import 'package:cwatch/controller/di/bindings/trash_tab_binding.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/features/servers/servers/server_models.dart';
import 'package:cwatch/view/features/servers/widgets/connectivity_tab.dart';
import 'package:cwatch/view/features/servers/widgets/resources_tab.dart';
import 'package:cwatch/view/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/view/shared/views/shared/tabs/terminal/terminal_tab.dart';

class ServerTabBuilder {
  const ServerTabBuilder({
    required this.settingsController,
    required this.trashManager,
    required this.shellServiceForHost,
    required this.keyService,
    required this.hostsFuture,
  });

  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final RemoteShellService Function(SshHost host) shellServiceForHost;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;

  WorkspaceTab explorerTab({
    required String id,
    required SshHost host,
    required Function(String path, String content) onOpenEditor,
    required Function(SshHost host, String? dir) onOpenTerminal,
    required Function(ExplorerContext context) onOpenTrash,
    ExplorerContext? explorerContext,
    String? initialPath,
    String? customName,
  }) {
    final controller = CompositeTabOptionsController();
    final effectiveContext = explorerContext ?? ExplorerContext.server(host);
    final tab = WorkspaceTab(
      id: id,
      title: customName ?? host.name,
      label: customName ?? host.name,
      icon: NerdIcon.folder.data,
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
            explorerContext: effectiveContext,
            shellService: shellServiceForHost(host),
            settingsController: settingsController,
            trashManager: trashManager,
            initialPath: initialPath,
            onOpenEditorTab: (path, content) => onOpenEditor(path, content),
          );
          return FileExplorerTab(
            controller: explorerController,
            settingsController: explorerSettingsController,
            onOpenTrash: onOpenTrash,
            onOpenTerminalTab: (path) => onOpenTerminal(host, path),
            optionsController: controller,
          );
        },
      ),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.fileExplorer,
        persistedState: TabState(
          id: id,
          kind: ServerAction.fileExplorer.name,
          hostName: host.name,
          title: customName,
          label: customName,
          path: initialPath,
        ),
      ),
    );
    return tab;
  }

  WorkspaceTab editorTab({
    required String id,
    required SshHost host,
    required String path,
    String? initialContent,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: path,
      label: path,
      icon: Icons.edit_note,
      body: Builder(
        builder: (context) {
          final cache = RemoteEditorCache();
          final shellService = shellServiceForHost(host);
          return RemoteFileEditorLoader(
            path: path,
            controllerBuilder: (uiAdapter) => RemoteFileEditorController(
              host: host,
              shellService: shellService,
              path: path,
              uiAdapter: uiAdapter,
              onSave: (content) async {
                await shellService.writeFile(host, path, content);
                await cache.materialize(
                  host: host.name,
                  remotePath: path,
                  contents: content,
                );
              },
            ),
            settingsController: settingsController,
            keyService: keyService,
            hostsFuture: hostsFuture,
            initialContent: initialContent,
            optionsController: controller,
          );
        },
      ),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.editor,
        persistedState: TabState(
          id: id,
          kind: ServerAction.editor.name,
          hostName: host.name,
          title: path,
          label: path,
        ),
      ),
    );
  }

  WorkspaceTab terminalTab({
    required String id,
    required SshHost host,
    required VoidCallback onClose,
    required Function(String path, String content) onOpenEditor,
    String? initialDirectory,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: initialDirectory ?? host.name,
      label: initialDirectory ?? host.name,
      icon: NerdIcon.terminal.data,
      body: TerminalTab(
        host: host,
        initialDirectory: initialDirectory,
        sessionController: const TerminalTabBinding().createSessionController(
          host: host,
          shellService: shellServiceForHost(host),
        ),
        settingsController: settingsController,
        onOpenEditorTab: (path, content) => onOpenEditor(path, content),
        onExit: onClose,
        optionsController: controller,
      ),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.terminal,
        persistedState: TabState(
          id: id,
          kind: ServerAction.terminal.name,
          hostName: host.name,
          title: initialDirectory,
          label: initialDirectory,
        ),
      ),
    );
  }

  WorkspaceTab resourcesTab({
    required String id,
    required SshHost host,
    String? customName,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: customName ?? host.name,
      label: customName ?? host.name,
      icon: NerdIcon.database.data,
      body: ResourcesTab(
        controller: const ResourcesBinding().create(
          host: host,
          shellService: shellServiceForHost(host),
        ),
      ),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.resources,
        persistedState: TabState(
          id: id,
          kind: ServerAction.resources.name,
          hostName: host.name,
          title: customName,
          label: customName,
        ),
      ),
    );
  }

  WorkspaceTab connectivityTab({
    required String id,
    required SshHost host,
    String? customName,
  }) {
    final controller = CompositeTabOptionsController();
    return WorkspaceTab(
      id: id,
      title: customName ?? host.name,
      label: customName ?? host.name,
      icon: NerdIcon.accessPoint.data,
      body: ConnectivityTab(host: host),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.connectivity,
        persistedState: TabState(
          id: id,
          kind: ServerAction.connectivity.name,
          hostName: host.name,
          title: customName,
          label: customName,
        ),
      ),
    );
  }

  WorkspaceTab trashTab({
    required String id,
    required SshHost host,
    ExplorerContext? explorerContext,
    String? customName,
  }) {
    final controller = CompositeTabOptionsController();
    final effectiveContext = explorerContext ?? ExplorerContext.server(host);
    return WorkspaceTab(
      id: id,
      title: customName ?? 'Trash • ${host.name}',
      label: customName ?? 'Trash',
      icon: Icons.delete_outline,
      body: Builder(
        builder: (context) {
          final controller = const TrashTabBinding().create(
            context: context,
            manager: trashManager,
            shellService: shellServiceForHost(host),
            keyService: keyService,
            explorerContext: effectiveContext,
          );
          return TrashTab(controller: controller);
        },
      ),
      canDrag: true,
      canRename: true,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.trash,
        persistedState: TabState(
          id: id,
          kind: ServerAction.trash.name,
          hostName: host.name,
          title: customName,
          label: customName,
        ),
      ),
    );
  }

  WorkspaceTab emptyTab({required String id, required Widget body}) {
    final controller = CompositeTabOptionsController();
    const host = PlaceholderHost();
    return WorkspaceTab(
      id: id,
      title: host.name,
      label: host.name,
      icon: NerdIcon.folderOpen.data,
      body: body,
      canDrag: false,
      canRename: false,
      optionsController: controller,
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.empty,
        persistedState: TabState(
          id: id,
          kind: ServerAction.empty.name,
          hostName: host.name,
        ),
      ),
    );
  }
}

class ServerTabData {
  const ServerTabData({
    required this.host,
    required this.action,
    required this.persistedState,
  });

  final SshHost host;
  final ServerAction action;
  final TabState persistedState;
}
