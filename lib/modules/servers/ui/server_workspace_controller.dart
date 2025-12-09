import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/server_workspace_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

import 'server_tab_factory.dart';
import 'servers/server_models.dart';

class ServerWorkspaceController {
  ServerWorkspaceController({
    required this.settingsController,
    required this.keyService,
    required this.commandLog,
    required Future<List<SshHost>> Function() hostsLoader,
    required this.trashManager,
    required RemoteShellService Function(SshHost host) shellServiceForHost,
    required EditorBodyBuilder editorBuilder,
  }) : _hostsLoader = hostsLoader {
    tabFactory = ServerTabFactory(
      settingsController: settingsController,
      trashManager: trashManager,
      keyService: keyService,
      shellServiceForHost: shellServiceForHost,
      editorBuilder: editorBuilder,
    );
    workspacePersistence = WorkspacePersistence(
      settingsController: settingsController,
      readFromSettings: (settings) => settings.serverWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(serverWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
  }

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final RemoteCommandLogController commandLog;
  final ExplorerTrashManager trashManager;
  final Future<List<SshHost>> Function() _hostsLoader;

  late final ServerTabFactory tabFactory;
  late final WorkspacePersistence<ServerWorkspaceState> workspacePersistence;

  Future<List<SshHost>> loadHosts() async {
    try {
      return await _hostsLoader();
    } catch (_) {
      return const [];
    }
  }

  ServerWorkspaceState currentWorkspaceState(
    List<ServerTab> tabs,
    int selectedIndex,
  ) {
    final states = tabs.map(_tabStateFromTab).toList();
    final clampedIndex = states.isEmpty
        ? 0
        : selectedIndex.clamp(0, states.length - 1);
    return ServerWorkspaceState(tabs: states, selectedIndex: clampedIndex);
  }

  List<ServerTab> buildTabsFromState(
    ServerWorkspaceState workspace,
    List<SshHost> hosts,
  ) {
    final restored = <ServerTab>[];
    for (final tabState in workspace.tabs) {
      final host = _resolveHost(tabState, hosts);
      if (host == null) {
        continue;
      }
      final tab = _createTabFromState(tabState, host);
      if (tab != null) {
        restored.add(tab);
      }
    }
    return restored;
  }

  ServerTab? _createTabFromState(TabState state, SshHost host) {
    final action = serverActionFromName(state.kind);
    if (action == null) {
      return null;
    }
    switch (action) {
      case ServerAction.fileExplorer:
        return tabFactory.explorerTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.editor:
        return tabFactory.editorTab(
          id: state.id,
          host: host,
          path: state.path ?? state.title ?? '',
        );
      case ServerAction.terminal:
        return tabFactory.terminalTab(
          id: state.id,
          host: host,
          initialDirectory: state.path,
        );
      case ServerAction.resources:
        return tabFactory.resourcesTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.connectivity:
        return tabFactory.connectivityTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.portForward:
        return null;
      case ServerAction.trash:
        return tabFactory.trashTab(
          id: state.id,
          host: host,
          customName: _customName(state),
        );
      case ServerAction.empty:
        return tabFactory.emptyTab(id: state.id);
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

  TabState _tabStateFromTab(ServerTab tab) {
    final action = tab.action;
    final path =
        action == ServerAction.editor || action == ServerAction.terminal
        ? tab.customName
        : null;
    if (action == ServerAction.portForward) {
      return TabState(
        id: tab.id,
        kind: ServerAction.empty.name,
        hostName: tab.host.name,
      );
    }
    return TabState(
      id: tab.id,
      kind: action.name,
      hostName: tab.host.name,
      title: tab.title,
      label: tab.label,
      path: path,
    );
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
