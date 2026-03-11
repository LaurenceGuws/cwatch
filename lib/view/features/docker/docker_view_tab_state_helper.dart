import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';

class DockerViewTabStateHelper {
  const DockerViewTabStateHelper();

  WorkspaceTab renameTab(WorkspaceTab tab, String title) {
    return _updateDockerTabState(
      tab.copyWith(title: title, label: title),
      updateState: (data) => data.persistedState.copyWith(
        title: title,
        label: title,
      ),
    );
  }

  WorkspaceTab updateExplorerPath(WorkspaceTab tab, String path) {
    return _updateDockerTabState(
      tab,
      updateState: (data) => data.persistedState.copyWith(path: path),
    );
  }

  List<String> pickerTabIds(Iterable<WorkspaceTab> tabs) {
    return tabs
        .where((tab) => _dockerTabData(tab)?.kind == DockerTabKind.picker)
        .map((tab) => tab.id)
        .toList();
  }

  WorkspaceTab _updateDockerTabState(
    WorkspaceTab tab, {
    required TabState Function(DockerTabData data) updateState,
  }) {
    final data = _dockerTabData(tab);
    if (data == null) {
      return tab;
    }
    return tab.copyWith(
      workspaceState: DockerTabData(
        kind: data.kind,
        persistedState: updateState(data),
      ),
    );
  }

  DockerTabData? _dockerTabData(WorkspaceTab tab) {
    final state = tab.workspaceState;
    if (state is DockerTabData) {
      return state;
    }
    return null;
  }
}
