import 'package:flutter/widgets.dart';
import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/tabbed_workspace_controller.dart';
import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/server_workspace_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

import 'server_tab_builder.dart';
import 'servers/server_models.dart';

class ServerWorkspaceController extends TabbedWorkspaceController {
  ServerWorkspaceController({
    required this.settingsController,
    required Future<List<SshHost>> Function() hostsLoader,
    required super.baseTabBuilder,
  }) : _hostsLoader = hostsLoader {
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: (settings) => settings.serverWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(serverWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  final Future<List<SshHost>> Function() _hostsLoader;
  late final WorkspacePersistence<ServerWorkspaceState> workspacePersistence;

  Future<List<SshHost>> loadHosts() async {
    try {
      return await _hostsLoader();
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH hosts for workspace',
        tag: 'Servers',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<void> restoreState() async {
    // This is handled by the View which calls restore with specific builder/hosts
    // because we need runtime dependencies that are not available here.
  }

  Future<void> restore({
    required ServerTabBuilder builder,
    required List<SshHost> hosts,
    required VoidCallback onCloseTab,
    required Function(SshHost host, String path, String content) onOpenEditor,
    required Function(SshHost host, String? dir) onOpenTerminal,
    required Function(ExplorerContext context) onOpenTrash,
    required Widget Function(String tabId) hostListBuilder,
  }) async {
    final workspace = settingsController.settings.serverWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) return;
    if (!workspacePersistence.shouldRestore(workspace)) return;

    final restoredTabs = <WorkspaceTab>[];
    for (final tabState in workspace.tabs) {
      final host = _resolveHost(tabState, hosts);
      if (host == null) continue;

      final tab = _createTabFromState(
        state: tabState,
        host: host,
        builder: builder,
        onCloseTab: onCloseTab,
        onOpenEditor: onOpenEditor,
        onOpenTerminal: onOpenTerminal,
        onOpenTrash: onOpenTrash,
        hostListBuilder: hostListBuilder,
      );
      if (tab != null) {
        restoredTabs.add(tab);
      }
    }

    if (restoredTabs.isNotEmpty) {
      workspacePersistence.markRestored(workspace);
      replaceAll(restoredTabs, selectedIndex: workspace.selectedIndex);
    }
  }

  ServerWorkspaceState buildWorkspaceStateSnapshot() {
    final persistedTabs = <TabState>[];
    int selectedPersistedIndex = 0;

    for (int i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      if (tab.workspaceState is ServerTabData) {
        final data = tab.workspaceState as ServerTabData;
        if (i == selectedIndex) {
          selectedPersistedIndex = persistedTabs.length;
        }
        persistedTabs.add(data.persistedState);
      }
    }

    final clampedIndex = persistedTabs.isEmpty
        ? 0
        : selectedPersistedIndex.clamp(0, persistedTabs.length - 1);

    return ServerWorkspaceState(
      tabs: persistedTabs,
      selectedIndex: clampedIndex,
    );
  }

  String currentWorkspaceSignature() {
    return buildWorkspaceStateSnapshot().signature;
  }

  @override
  Future<void> persistState() async {
    await workspacePersistence.persist(buildWorkspaceStateSnapshot());
  }

  void updateTabState(String tabId, TabState newState) {
    final index = tabs.indexWhere((t) => t.id == tabId);
    if (index != -1) {
      final tab = tabs[index];
      if (tab.workspaceState is ServerTabData) {
        final oldData = tab.workspaceState as ServerTabData;
        final newTab = tab.copyWith(
          workspaceState: ServerTabData(
            host: oldData.host,
            action: oldData.action,
            persistedState: newState,
          ),
        );
        replaceTab(tabId, newTab);
      }
    }
  }

  WorkspaceTab? _createTabFromState({
    required TabState state,
    required SshHost host,
    required ServerTabBuilder builder,
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
        return builder.explorerTab(
          id: state.id,
          host: host,
          customName: _customName(state),
          initialPath: state.path,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
          onOpenTerminal: onOpenTerminal,
          onOpenTrash: onOpenTrash,
        );
      case ServerAction.editor:
        return builder.editorTab(
          id: state.id,
          host: host,
          path: state.path ?? state.title ?? '',
        );
      case ServerAction.terminal:
        return builder.terminalTab(
          id: state.id,
          host: host,
          initialDirectory: state.path,
          onClose: onCloseTab,
          onOpenEditor: (path, content) => onOpenEditor(host, path, content),
        );
      case ServerAction.resources:
        return builder.resourcesTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.connectivity:
        return builder.connectivityTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.portForward:
        return null;
      case ServerAction.trash:
        return builder.trashTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.empty:
        return builder.emptyTab(id: state.id, body: hostListBuilder(state.id));
    }
  }

  SshHost? _resolveHost(TabState tabState, List<SshHost> hosts) {
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
        return _findHostByName(hosts, hostName) ?? const TrashHost();
      case ServerAction.fileExplorer:
      case ServerAction.connectivity:
      case ServerAction.terminal:
      case ServerAction.resources:
      case ServerAction.editor:
      case ServerAction.portForward:
        if (hostName == null) return null;
        return _findHostByName(hosts, hostName);
    }
  }

  String? _customName(TabState state) => state.title ?? state.label;

  SshHost? _findHostByName(List<SshHost> hosts, String target) {
    for (final host in hosts) {
      if (host.name == target) {
        return host;
      }
    }
    return null;
  }
}
