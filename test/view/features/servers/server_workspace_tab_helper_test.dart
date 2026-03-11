import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/features/servers/server_workspace_tab_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const helper = ServerWorkspaceTabHelper();
  const host = SshHost(
    name: 'alpha',
    hostname: 'alpha.local',
    port: 22,
    available: true,
  );

  WorkspaceTab hostTab({
    required String id,
    required String title,
    Object? workspaceState,
  }) {
    return WorkspaceTab(
      id: id,
      title: title,
      label: title,
      icon: Icons.computer,
      body: const SizedBox.shrink(),
      workspaceState: workspaceState,
    );
  }

  test('createTab routes file explorer action to explorer builder', () {
    final tab = helper.createTab(
      id: 'explorer-1',
      host: host,
      action: ServerAction.fileExplorer,
      buildExplorerTab: ({
        required id,
        required host,
        required onOpenEditor,
        required onOpenTerminal,
        required onOpenTrash,
      }) => hostTab(id: id, title: 'explorer:${host.name}'),
      buildTerminalTab: ({
        required id,
        required host,
        required onClose,
        required onOpenEditor,
        initialDirectory,
      }) => hostTab(id: id, title: 'terminal'),
      buildEditorTab: ({
        required id,
        required host,
        required path,
        initialContent,
      }) => hostTab(id: id, title: 'editor'),
      buildResourcesTab: ({required id, required host}) =>
          hostTab(id: id, title: 'resources'),
      buildConnectivityTab: ({required id, required host}) =>
          hostTab(id: id, title: 'connectivity'),
      buildTrashTab: ({required id, required host, explorerContext}) =>
          hostTab(id: id, title: 'trash'),
      buildEmptyTab: ({required id}) => hostTab(id: id, title: 'empty'),
      onCloseTerminalTab: () {},
      onOpenEditor: (resolvedHost, path, content) {},
      onOpenTerminal: (resolvedHost, dir) {},
      onOpenTrash: (context) {},
    );

    expect(tab.title, 'explorer:alpha');
  });

  test('createTrashTab uses explorer context host', () {
    final context = ExplorerContext.server(host);
    final tab = helper.createTrashTab(
      id: 'trash-1',
      context: context,
      buildTrashTab: ({
        required id,
        required host,
        explorerContext,
      }) => hostTab(id: id, title: 'trash:${host.name}'),
    );

    expect(tab.title, 'trash:alpha');
  });

  test('renamedTab updates persisted title for server workspace state', () {
    final original = hostTab(
      id: 'term-1',
      title: 'old',
      workspaceState: ServerTabData(
        host: host,
        action: ServerAction.terminal,
        persistedState: const TabState(
          id: 'term-1',
          title: 'old',
          kind: 'terminal',
        ),
      ),
    );

    final renamed = helper.renamedTab(original, 'new');

    expect(renamed.title, 'new');
    expect(renamed.label, 'new');
    final state = renamed.workspaceState as ServerTabData;
    expect(state.persistedState.title, 'new');
  });
}
