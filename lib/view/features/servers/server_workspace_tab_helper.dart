import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';

typedef VoidCallback = void Function();

typedef ServerExplorerActionTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required Function(String path, String content) onOpenEditor,
      required Function(SshHost host, String? dir) onOpenTerminal,
      required Function(ExplorerContext context) onOpenTrash,
    });
typedef ServerTerminalActionTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required VoidCallback onClose,
      required Function(String path, String content) onOpenEditor,
      String? initialDirectory,
    });
typedef ServerEditorActionTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      required String path,
      String? initialContent,
    });
typedef ServerHostActionTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
    });
typedef ServerTrashActionTabBuilder =
    WorkspaceTab Function({
      required String id,
      required SshHost host,
      ExplorerContext? explorerContext,
    });
typedef ServerEmptyActionTabBuilder =
    WorkspaceTab Function({required String id});

class ServerWorkspaceTabHelper {
  const ServerWorkspaceTabHelper();

  WorkspaceTab createTab({
    required String id,
    required SshHost host,
    required ServerAction action,
    required ServerExplorerActionTabBuilder buildExplorerTab,
    required ServerTerminalActionTabBuilder buildTerminalTab,
    required ServerEditorActionTabBuilder buildEditorTab,
    required ServerHostActionTabBuilder buildResourcesTab,
    required ServerHostActionTabBuilder buildConnectivityTab,
    required ServerTrashActionTabBuilder buildTrashTab,
    required ServerEmptyActionTabBuilder buildEmptyTab,
    required VoidCallback onCloseTerminalTab,
    required Function(SshHost host, String path, String content) onOpenEditor,
    required Function(SshHost host, String? dir) onOpenTerminal,
    required Function(ExplorerContext context) onOpenTrash,
  }) {
    switch (action) {
      case ServerAction.fileExplorer:
        return buildExplorerTab(
          id: id,
          host: host,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
          onOpenTerminal: (resolvedHost, dir) => onOpenTerminal(
            resolvedHost,
            dir,
          ),
          onOpenTrash: onOpenTrash,
        );
      case ServerAction.terminal:
        return buildTerminalTab(
          id: id,
          host: host,
          onClose: onCloseTerminalTab,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
        );
      case ServerAction.editor:
        return buildEditorTab(id: id, host: host, path: '');
      case ServerAction.resources:
        return buildResourcesTab(id: id, host: host);
      case ServerAction.connectivity:
        return buildConnectivityTab(id: id, host: host);
      case ServerAction.trash:
        return buildTrashTab(id: id, host: host);
      case ServerAction.portForward:
      case ServerAction.empty:
        return buildEmptyTab(id: id);
    }
  }

  WorkspaceTab createTrashTab({
    required String id,
    required ExplorerContext context,
    required ServerTrashActionTabBuilder buildTrashTab,
  }) {
    return buildTrashTab(
      id: id,
      host: context.host,
      explorerContext: context,
    );
  }

  WorkspaceTab createEditorTab({
    required String id,
    required SshHost host,
    required String path,
    required String content,
    required ServerEditorActionTabBuilder buildEditorTab,
  }) {
    return buildEditorTab(
      id: id,
      host: host,
      path: path,
      initialContent: content,
    );
  }

  WorkspaceTab createTerminalTab({
    required String id,
    required SshHost host,
    String? initialDirectory,
    required ServerTerminalActionTabBuilder buildTerminalTab,
    required VoidCallback onClose,
    required Function(String path, String content) onOpenEditor,
  }) {
    return buildTerminalTab(
      id: id,
      host: host,
      initialDirectory: initialDirectory,
      onClose: onClose,
      onOpenEditor: onOpenEditor,
    );
  }

  WorkspaceTab renamedTab(WorkspaceTab tab, String trimmedName) {
    final updated = tab.copyWith(title: trimmedName, label: trimmedName);
    if (tab.workspaceState is! ServerTabData) {
      return updated;
    }
    final oldData = tab.workspaceState as ServerTabData;
    return updated.copyWith(
      workspaceState: ServerTabData(
        host: oldData.host,
        action: oldData.action,
        persistedState: oldData.persistedState.copyWith(title: trimmedName),
      ),
    );
  }
}
