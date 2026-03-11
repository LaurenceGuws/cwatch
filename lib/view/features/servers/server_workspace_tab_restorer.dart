import 'package:flutter/widgets.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';

import 'servers/server_models.dart';

typedef ServerEmptyTabBuilder =
    WorkspaceTab Function({required String id, required Widget body});
typedef ServerExplorerTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required Function(String path, String content) onOpenEditor,
      required Function(SshHost host, String? dir) onOpenTerminal,
      required Function(ExplorerContext context) onOpenTrash,
      ExplorerContext? explorerContext,
      String? initialPath,
      String? customName,
    });
typedef ServerEditorTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required String path,
      String? initialContent,
    });
typedef ServerTerminalTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required VoidCallback onClose,
      required Function(String path, String content) onOpenEditor,
      String? initialDirectory,
    });
typedef ServerHostTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      String? customName,
    });
typedef ServerTrashTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      ExplorerContext? explorerContext,
      String? customName,
    });

class ServerWorkspaceTabRestorer {
  const ServerWorkspaceTabRestorer();

  SshHost? resolveHost(TabState tabState, List<SshHost> hosts) {
    final action = serverActionFromName(tabState.kind);
    if (action == null) {
      return null;
    }
    final hostName = tabState.hostName;
    switch (action) {
      case ServerAction.empty:
        return const PlaceholderHost();
      case ServerAction.trash:
        if (hostName == null) return const TrashHost();
        return findHostByName(hosts, hostName) ?? const TrashHost();
      case ServerAction.fileExplorer:
      case ServerAction.connectivity:
      case ServerAction.terminal:
      case ServerAction.resources:
      case ServerAction.editor:
      case ServerAction.portForward:
        if (hostName == null) return null;
        return findHostByName(hosts, hostName);
    }
  }

  WorkspaceTab? restoreTab({
    required TabState state,
    required SshHost host,
    required ServerEmptyTabBuilder buildEmptyTab,
    required ServerExplorerTabBuilder buildExplorerTab,
    required ServerEditorTabBuilder buildEditorTab,
    required ServerTerminalTabBuilder buildTerminalTab,
    required ServerHostTabBuilder buildResourcesTab,
    required ServerHostTabBuilder buildConnectivityTab,
    required ServerTrashTabBuilder buildTrashTab,
    required VoidCallback onCloseTab,
    required Function(SshHost host, String path, String content) onOpenEditor,
    required Function(SshHost host, String? dir) onOpenTerminal,
    required Function(ExplorerContext context) onOpenTrash,
    required Widget Function(String tabId) hostListBuilder,
  }) {
    final action = serverActionFromName(state.kind);
    if (action == null) return null;

    switch (action) {
      case ServerAction.fileExplorer:
        return buildExplorerTab(
          id: state.id,
          host: host,
          customName: customName(state),
          initialPath: state.path,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
          onOpenTerminal: onOpenTerminal,
          onOpenTrash: onOpenTrash,
        );
      case ServerAction.editor:
        return buildEditorTab(
          id: state.id,
          host: host,
          path: state.path ?? state.title ?? '',
        );
      case ServerAction.terminal:
        return buildTerminalTab(
          id: state.id,
          host: host,
          initialDirectory: state.path,
          onClose: onCloseTab,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
        );
      case ServerAction.resources:
        return buildResourcesTab(
          id: state.id,
          host: host,
          customName: customName(state),
        );
      case ServerAction.connectivity:
        return buildConnectivityTab(
          id: state.id,
          host: host,
          customName: customName(state),
        );
      case ServerAction.portForward:
        return null;
      case ServerAction.trash:
        return buildTrashTab(
          id: state.id,
          host: host,
          customName: customName(state),
        );
      case ServerAction.empty:
        return buildEmptyTab(id: state.id, body: hostListBuilder(state.id));
    }
  }

  String? customName(TabState state) => state.title ?? state.label;

  SshHost? findHostByName(List<SshHost> hosts, String target) {
    for (final host in hosts) {
      if (host.name == target) {
        return host;
      }
    }
    return null;
  }
}
