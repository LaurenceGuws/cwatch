import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/core/models/workspace_state.dart';
import 'package:cwatch/controller/core/workspace/tabbed_workspace_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_persistence.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';

abstract class PersistentWorkspaceController<
  TWorkspaceState extends WorkspaceState
>
    extends TabbedWorkspaceController {
  PersistentWorkspaceController({
    required this.settingsController,
    required this.workspaceRootController,
    required super.baseTabBuilder,
  }) {
    workspacePersistence = WorkspacePersistence(
      workspaceRootController: workspaceRootController,
      readFromRoot: readFromRoot,
      writeToRoot: writeToRoot,
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  final WorkspaceRootController workspaceRootController;
  late final WorkspacePersistence<TWorkspaceState> workspacePersistence;

  /// Reads the workspace state from the workspace root container.
  TWorkspaceState? readFromRoot(PersistedWorkspaces workspaces);

  /// Writes the workspace state to the workspace root container.
  PersistedWorkspaces writeToRoot(
    PersistedWorkspaces current,
    TWorkspaceState workspace,
  );

  /// Creates a new workspace state snapshot from the current list of tab states.
  TWorkspaceState createWorkspaceState(List<TabState> tabs, int selectedIndex);

  /// Extracts the persisting tab state from a tab's workspace data.
  TabState? getTabState(Object? tabData);

  TWorkspaceState buildWorkspaceStateSnapshot() {
    final persistedTabs = <TabState>[];
    int selectedPersistedIndex = 0;

    for (int i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final tabState = getTabState(tab.workspaceState);
      if (tabState != null) {
        if (i == selectedIndex) {
          selectedPersistedIndex = persistedTabs.length;
        }
        persistedTabs.add(tabState);
      }
    }

    final clampedIndex = persistedTabs.isEmpty
        ? 0
        : selectedPersistedIndex.clamp(0, persistedTabs.length - 1);

    return createWorkspaceState(persistedTabs, clampedIndex);
  }

  String currentWorkspaceSignature() => buildWorkspaceStateSnapshot().signature;

  @override
  Future<void> persistState() async {
    await workspacePersistence.persist(buildWorkspaceStateSnapshot());
  }
}
