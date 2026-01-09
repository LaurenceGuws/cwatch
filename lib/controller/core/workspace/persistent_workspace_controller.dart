import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/core/models/workspace_state.dart';
import 'package:cwatch/controller/core/workspace/tabbed_workspace_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_persistence.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';

abstract class PersistentWorkspaceController<
  TWorkspaceState extends WorkspaceState
>
    extends TabbedWorkspaceController {
  PersistentWorkspaceController({
    required this.settingsController,
    required super.baseTabBuilder,
  }) {
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: readFromSettings,
      writeToSettings: writeToSettings,
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  late final WorkspacePersistence<TWorkspaceState> workspacePersistence;

  /// Reads the workspace state from the global app settings.
  TWorkspaceState? readFromSettings(AppSettings settings);

  /// Writes the workspace state to the global app settings.
  AppSettings writeToSettings(AppSettings current, TWorkspaceState workspace);

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
