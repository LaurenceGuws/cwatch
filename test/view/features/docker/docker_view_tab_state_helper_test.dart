import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_view_tab_state_helper.dart';

void main() {
  group('DockerViewTabStateHelper', () {
    const helper = DockerViewTabStateHelper();

    test('renameTab updates visible labels and persisted docker state', () {
      final renamed = helper.renameTab(_dockerTab(id: 'alpha'), 'Renamed');

      expect(renamed.title, 'Renamed');
      expect(renamed.label, 'Renamed');
      final state = (renamed.workspaceState as DockerTabData).persistedState;
      expect(state.title, 'Renamed');
      expect(state.label, 'Renamed');
    });

    test('updateExplorerPath updates persisted docker explorer path', () {
      final updated = helper.updateExplorerPath(
        _dockerTab(
          id: 'explorer-1',
          kind: DockerTabKind.containerExplorer,
          path: '/srv/app',
        ),
        '/srv/app/current',
      );

      final state = (updated.workspaceState as DockerTabData).persistedState;
      expect(state.path, '/srv/app/current');
    });

    test('pickerTabIds returns only docker picker tabs', () {
      final pickerIds = helper.pickerTabIds([
        _dockerTab(id: 'picker-1', kind: DockerTabKind.picker),
        _dockerTab(id: 'overview-1', kind: DockerTabKind.contextOverview),
        _plainTab(id: 'plain-1'),
        _dockerTab(id: 'picker-2', kind: DockerTabKind.picker),
      ]);

      expect(pickerIds, ['picker-1', 'picker-2']);
    });
  });
}

WorkspaceTab _dockerTab({
  required String id,
  DockerTabKind kind = DockerTabKind.contextOverview,
  String title = 'Original',
  String label = 'Original',
  String? path,
}) {
  return WorkspaceTab(
    id: id,
    title: title,
    label: label,
    icon: Icons.adb,
    body: const SizedBox.shrink(),
    workspaceState: DockerTabData(
      kind: kind,
      persistedState: TabState(
        id: id,
        kind: kind.name,
        title: title,
        label: label,
        path: path,
      ),
    ),
  );
}

WorkspaceTab _plainTab({required String id}) {
  return WorkspaceTab(
    id: id,
    title: 'Plain',
    label: 'Plain',
    icon: Icons.pages,
    body: const SizedBox.shrink(),
  );
}
