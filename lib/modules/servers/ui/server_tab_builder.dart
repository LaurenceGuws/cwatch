import 'package:flutter/material.dart';

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/terminal/terminal_tab.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/services/ssh/remote_editor_cache.dart';

import 'widgets/connectivity_tab.dart';
import 'widgets/resources_tab.dart';
import 'servers/server_models.dart';

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
      body: FileExplorerTab(
        host: host,
        explorerContext: effectiveContext,
        shellService: shellServiceForHost(host),
        settingsController: settingsController,
        keyService: keyService,
        hostsFuture: hostsFuture,
        trashManager: trashManager,
        initialPath: initialPath,
        onPathChanged: (path) {
          // We might need to update the tab state here, but that requires
          // access to the controller. For now, we rely on internal state
          // or we can pass a callback that updates the tab state.
        },
        onOpenTrash: onOpenTrash,
        onOpenEditorTab: (path, content) async => onOpenEditor(path, content),
        onOpenTerminalTab: (path) => onOpenTerminal(host, path),
        optionsController: controller,
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
      body: _EditorTabLoader(
        host: host,
        shellService: shellServiceForHost(host),
        path: path,
        settingsController: settingsController,
        keyService: keyService,
        hostsFuture: hostsFuture,
        initialContent: initialContent,
        optionsController: controller,
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
        shellService: shellServiceForHost(host),
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
      body: ResourcesTab(host: host, shellService: shellServiceForHost(host)),
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
      body: TrashTab(
        manager: trashManager,
        shellService: shellServiceForHost(host),
        keyService: keyService,
        context: effectiveContext,
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

class _EditorTabLoader extends StatelessWidget {
  const _EditorTabLoader({
    required this.host,
    required this.shellService,
    required this.path,
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    this.initialContent,
    this.optionsController,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final String? initialContent;
  final TabOptionsController? optionsController;

  @override
  Widget build(BuildContext context) {
    final cache = RemoteEditorCache();
    return RemoteFileEditorLoader(
      host: host,
      shellService: shellService,
      path: path,
      settingsController: settingsController,
      keyService: keyService,
      hostsFuture: hostsFuture,
      initialContent: initialContent,
      optionsController: optionsController,
      onSave: (content) async {
        await shellService.writeFile(host, path, content);
        await cache.materialize(
          host: host.name,
          remotePath: path,
          contents: content,
        );
      },
    );
  }
}
