import 'package:flutter/material.dart';

import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/terminal/terminal_tab.dart';
import 'widgets/connectivity_tab.dart';
import 'widgets/resources_tab.dart';
import 'servers/server_models.dart';

typedef EditorBodyBuilder = Widget Function(ServerTab tab);

class ServerTabFactory {
  const ServerTabFactory({
    required this.settingsController,
    required this.trashManager,
    required this.shellServiceForHost,
    required this.editorBuilder,
    required this.keyService,
  });

  final AppSettingsController settingsController;
  final ExplorerTrashManager trashManager;
  final RemoteShellService Function(SshHost host) shellServiceForHost;
  final EditorBodyBuilder editorBuilder;
  final BuiltInSshKeyService keyService;

  ServerTab explorerTab({
    required String id,
    required SshHost host,
    GlobalKey? bodyKey,
    ExplorerContext? explorerContext,
    String? customName,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.fileExplorer,
      customName: customName,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      explorerContext: explorerContext ?? ExplorerContext.server(host),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab editorTab({
    required String id,
    required SshHost host,
    required String path,
    String? initialContent,
    GlobalKey? bodyKey,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.editor,
      customName: path,
      initialContent: initialContent,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab terminalTab({
    required String id,
    required SshHost host,
    String? initialDirectory,
    GlobalKey? bodyKey,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.terminal,
      customName: initialDirectory,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab resourcesTab({
    required String id,
    required SshHost host,
    GlobalKey? bodyKey,
    String? customName,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.resources,
      customName: customName,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab connectivityTab({
    required String id,
    required SshHost host,
    GlobalKey? bodyKey,
    String? customName,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.connectivity,
      customName: customName,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab trashTab({
    required String id,
    required SshHost host,
    ExplorerContext? explorerContext,
    GlobalKey? bodyKey,
    String? customName,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: ServerAction.trash,
      customName: customName ?? 'Trash • ${host.name}',
      explorerContext: explorerContext ?? ExplorerContext.server(host),
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  ServerTab emptyTab({required String id}) {
    return ServerTab(
      id: id,
      host: const PlaceholderHost(),
      action: ServerAction.empty,
      bodyKey: GlobalKey(debugLabel: 'server-tab-$id'),
      optionsController: TabOptionsController(),
    );
  }

  Widget buildBody(
    ServerTab tab, {
    required Future<void> Function(String path, String content) onOpenEditorTab,
    required Future<void> Function(SshHost host, {String? initialDirectory})
    onOpenTerminalTab,
    required void Function(ExplorerContext context) onOpenTrash,
    required void Function(String tabId) onCloseTab,
  }) {
    switch (tab.action) {
      case ServerAction.empty:
        return const SizedBox.shrink();
      case ServerAction.fileExplorer:
        final explorerContext =
            tab.explorerContext ?? ExplorerContext.server(tab.host);
        return FileExplorerTab(
          key: tab.bodyKey,
          host: tab.host,
          explorerContext: explorerContext,
          shellService: shellServiceForHost(tab.host),
          keyService: keyService,
          trashManager: trashManager,
          onOpenTrash: onOpenTrash,
          onOpenEditorTab: onOpenEditorTab,
          onOpenTerminalTab: (path) =>
              onOpenTerminalTab(tab.host, initialDirectory: path),
          optionsController: tab.optionsController,
        );
      case ServerAction.editor:
        return editorBuilder(tab);
      case ServerAction.connectivity:
        return ConnectivityTab(key: tab.bodyKey, host: tab.host);
      case ServerAction.resources:
        return ResourcesTab(
          key: tab.bodyKey,
          host: tab.host,
          shellService: shellServiceForHost(tab.host),
        );
      case ServerAction.terminal:
        return TerminalTab(
          key: tab.bodyKey,
          host: tab.host,
          initialDirectory: tab.customName,
          shellService: shellServiceForHost(tab.host),
          settingsController: settingsController,
          onExit: () => onCloseTab(tab.id),
          optionsController: tab.optionsController,
        );
      case ServerAction.portForward:
        return const SizedBox.shrink();
      case ServerAction.trash:
        final explorerContext =
            tab.explorerContext ?? ExplorerContext.server(tab.host);
        return TrashTab(
          key: tab.bodyKey,
          manager: trashManager,
          shellService: shellServiceForHost(tab.host),
          keyService: keyService,
          context: explorerContext,
        );
    }
  }
}
