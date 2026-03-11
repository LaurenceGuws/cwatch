import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/features/servers/server_workspace_tab_restorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const restorer = ServerWorkspaceTabRestorer();
  const host = SshHost(
    name: 'alpha',
    hostname: 'alpha.local',
    port: 22,
    available: true,
  );

  WorkspaceTab emptyTab({required String id, required Widget body}) =>
      WorkspaceTab(
        id: id,
        title: 'empty',
        label: 'empty',
        icon: Icons.folder_open,
        body: body,
      );

  WorkspaceTab hostTab({
    required String id,
    required SshHost host,
    String? customName,
  }) => WorkspaceTab(
    id: id,
    title: customName ?? host.name,
    label: customName ?? host.name,
    icon: Icons.computer,
    body: const SizedBox.shrink(),
  );

  test('resolveHost returns placeholder host for empty tabs', () {
    final resolved = restorer.resolveHost(
      const TabState(id: 'empty-1', title: 'Servers', kind: 'empty'),
      const [host],
    );

    expect(resolved?.name, 'Servers');
  });

  test('resolveHost falls back to trash host when trash host is missing', () {
    final resolved = restorer.resolveHost(
      const TabState(id: 'trash-1', title: 'Trash', kind: 'trash'),
      const [host],
    );

    expect(resolved?.name, 'Trash');
  });

  test('restoreTab builds explorer tab with custom name and path', () {
    final restored = restorer.restoreTab(
      state: const TabState(
        id: 'explorer-1',
        title: 'Custom Explorer',
        kind: 'fileExplorer',
        hostName: 'alpha',
        path: '/srv',
      ),
      host: host,
      buildEmptyTab: emptyTab,
      buildExplorerTab: ({
        required id,
        required host,
        required onOpenEditor,
        required onOpenTerminal,
        required onOpenTrash,
        explorerContext,
        initialPath,
        customName,
      }) => hostTab(id: id, host: host, customName: '$customName:$initialPath'),
      buildEditorTab: ({
        required id,
        required host,
        required path,
        initialContent,
      }) => hostTab(id: id, host: host, customName: path),
      buildTerminalTab: ({
        required id,
        required host,
        required onClose,
        required onOpenEditor,
        initialDirectory,
      }) => hostTab(id: id, host: host, customName: initialDirectory),
      buildResourcesTab: hostTab,
      buildConnectivityTab: hostTab,
      buildTrashTab: ({
        required id,
        required host,
        explorerContext,
        customName,
      }) => hostTab(id: id, host: host, customName: customName),
      onCloseTab: () {},
      onOpenEditor: (resolvedHost, path, content) {},
      onOpenTerminal: (resolvedHost, directory) {},
      onOpenTrash: (context) {},
      hostListBuilder: (_) => const SizedBox.shrink(),
    );

    expect(restored, isNotNull);
    expect(restored!.title, 'Custom Explorer:/srv');
  });

  test('restoreTab returns null for unsupported port forward tabs', () {
    final restored = restorer.restoreTab(
      state: const TabState(
        id: 'forward-1',
        title: 'Port Forward',
        kind: 'portForward',
        hostName: 'alpha',
      ),
      host: host,
      buildEmptyTab: emptyTab,
      buildExplorerTab: ({
        required id,
        required host,
        required onOpenEditor,
        required onOpenTerminal,
        required onOpenTrash,
        explorerContext,
        initialPath,
        customName,
      }) => hostTab(id: id, host: host, customName: customName),
      buildEditorTab: ({
        required id,
        required host,
        required path,
        initialContent,
      }) => hostTab(id: id, host: host, customName: path),
      buildTerminalTab: ({
        required id,
        required host,
        required onClose,
        required onOpenEditor,
        initialDirectory,
      }) => hostTab(id: id, host: host, customName: initialDirectory),
      buildResourcesTab: hostTab,
      buildConnectivityTab: hostTab,
      buildTrashTab: ({
        required id,
        required host,
        ExplorerContext? explorerContext,
        customName,
      }) => hostTab(id: id, host: host, customName: customName),
      onCloseTab: () {},
      onOpenEditor: (resolvedHost, path, content) {},
      onOpenTerminal: (resolvedHost, directory) {},
      onOpenTrash: (context) {},
      hostListBuilder: (_) => const SizedBox.shrink(),
    );

    expect(restored, isNull);
  });
}
