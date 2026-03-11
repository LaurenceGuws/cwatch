import 'dart:async';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/generic_tab_command_entries.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/workspace_shell_chrome.dart';
import 'package:cwatch/view/core/tabs/workspace_settings_sync.dart';

class ServerWorkspaceShell {
  ServerWorkspaceShell({
    required this.moduleId,
    required Future<List<SshHost>> Function() loadHosts,
    required Future<List<SshHost>> Function() reloadHosts,
    required Future<List<SshHost>> Function(List<CustomSshHost> customHosts)
    updateCustomHosts,
    required String Function() buildCustomHostsSignature,
    required String Function() buildPathsSignature,
    required String Function() buildDisabledHostsSignature,
    required void Function(Future<List<SshHost>> hostsFuture) setHostsFuture,
    required void Function() requestViewRefresh,
    required String? Function() persistedWorkspaceSignature,
    required String Function() currentWorkspaceSignature,
    required Future<void> Function() restoreWorkspace,
    required Future<void> Function() persistIfPending,
    required List<WorkspaceTab> Function() tabs,
    required int Function() selectedIndex,
    required void Function(int index) selectTab,
    required void Function(int index) closeTab,
    required void Function(String tabId, WorkspaceTab replacement) replaceTab,
    required void Function(WorkspaceTab tab) addTab,
    required WorkspaceTab Function() createPlaceholderTab,
    required WorkspaceTab Function({
      required String id,
      required SshHost host,
      required ServerAction action,
    })
    createTab,
    required void Function(SshHost host) onHostInteraction,
    required Future<void> Function(SshHost host) openPortForwardDialog,
    required Future<ServerAction?> Function(SshHost host) pickAction,
    required Future<void> Function(int index) renameTab,
    required List<CustomSshHost> Function() customHosts,
  }) : _loadHosts = loadHosts,
       _reloadHosts = reloadHosts,
       _updateCustomHosts = updateCustomHosts,
       _buildCustomHostsSignature = buildCustomHostsSignature,
       _buildPathsSignature = buildPathsSignature,
       _buildDisabledHostsSignature = buildDisabledHostsSignature,
       _setHostsFuture = setHostsFuture,
       _requestViewRefresh = requestViewRefresh,
       _persistedWorkspaceSignature = persistedWorkspaceSignature,
       _currentWorkspaceSignature = currentWorkspaceSignature,
       _restoreWorkspace = restoreWorkspace,
       _persistIfPending = persistIfPending,
       _tabs = tabs,
       _selectedIndex = selectedIndex,
       _selectTab = selectTab,
       _closeTab = closeTab,
       _replaceTab = replaceTab,
       _addTab = addTab,
       _createPlaceholderTab = createPlaceholderTab,
       _createTab = createTab,
       _onHostInteraction = onHostInteraction,
       _openPortForwardDialog = openPortForwardDialog,
       _pickAction = pickAction,
       _renameTab = renameTab,
       _customHosts = customHosts;

  final String moduleId;
  final Future<List<SshHost>> Function() _loadHosts;
  final Future<List<SshHost>> Function() _reloadHosts;
  final Future<List<SshHost>> Function(List<CustomSshHost> customHosts)
  _updateCustomHosts;
  final String Function() _buildCustomHostsSignature;
  final String Function() _buildPathsSignature;
  final String Function() _buildDisabledHostsSignature;
  final void Function(Future<List<SshHost>> hostsFuture) _setHostsFuture;
  final void Function() _requestViewRefresh;
  final String? Function() _persistedWorkspaceSignature;
  final String Function() _currentWorkspaceSignature;
  final Future<void> Function() _restoreWorkspace;
  final Future<void> Function() _persistIfPending;
  final List<WorkspaceTab> Function() _tabs;
  final int Function() _selectedIndex;
  final void Function(int index) _selectTab;
  final void Function(int index) _closeTab;
  final void Function(String tabId, WorkspaceTab replacement) _replaceTab;
  final void Function(WorkspaceTab tab) _addTab;
  final WorkspaceTab Function() _createPlaceholderTab;
  final WorkspaceTab Function({
    required String id,
    required SshHost host,
    required ServerAction action,
  })
  _createTab;
  final void Function(SshHost host) _onHostInteraction;
  final Future<void> Function(SshHost host) _openPortForwardDialog;
  final Future<ServerAction?> Function(SshHost host) _pickAction;
  final Future<void> Function(int index) _renameTab;
  final List<CustomSshHost> Function() _customHosts;
  final WorkspaceSettingsSync _settingsSync = const WorkspaceSettingsSync();

  String _customHostsSignature = '';
  String _pathsSignature = '';
  String _disabledHostsSignature = '';

  late final TabNavigationHandle tabNavigator = TabNavigationHandle(
    next: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      final next = (_selectedIndex() + 1) % length;
      _selectTab(next);
      return true;
    },
    previous: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      final prev = (_selectedIndex() - 1 + length) % length;
      _selectTab(prev);
      return true;
    },
  );

  late final CommandPaletteHandle commandPaletteHandle = CommandPaletteHandle(
    loader: buildCommandPaletteEntries,
  );
  late final WorkspaceShellChrome _shellChrome = WorkspaceShellChrome(
    moduleId: moduleId,
    tabNavigator: tabNavigator,
    commandPaletteHandle: commandPaletteHandle,
  );

  Future<List<SshHost>> initializeHosts(Future<List<SshHost>> initialHostsFuture) {
    _customHostsSignature = _buildCustomHostsSignature();
    _pathsSignature = _buildPathsSignature();
    _disabledHostsSignature = _buildDisabledHostsSignature();
    _setHostsFuture(initialHostsFuture);
    return initialHostsFuture;
  }

  void initializeWorkspaceChrome() {
    _shellChrome.register();
  }

  void dispose() {
    _shellChrome.unregister();
  }

  List<CommandPaletteEntry> buildCommandPaletteEntries() {
    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    return buildGenericTabCommandEntries(
      moduleId: moduleId,
      selectedTab: tabs.isNotEmpty ? tabs[selectedIndex] : null,
      onNewTab: startEmptyTab,
      onCloseTab: () => _closeTab(selectedIndex),
      onRenameTab: () => _renameTab(selectedIndex),
    );
  }

  Future<void> handleSettingsChanged() async {
    final nextCustomSignature = _buildCustomHostsSignature();
    final nextPathsSignature = _buildPathsSignature();
    final nextDisabledSignature = _buildDisabledHostsSignature();
    final customHostsChanged = nextCustomSignature != _customHostsSignature;
    final pathsChanged = nextPathsSignature != _pathsSignature;
    final disabledChanged = nextDisabledSignature != _disabledHostsSignature;

    if (pathsChanged) {
      _customHostsSignature = nextCustomSignature;
      _pathsSignature = nextPathsSignature;
      _disabledHostsSignature = nextDisabledSignature;
      _setHostsFuture(_loadHosts());
    } else if (customHostsChanged) {
      _customHostsSignature = nextCustomSignature;
      _setHostsFuture(_updateCustomHosts(_customHosts()));
    } else if (disabledChanged) {
      _disabledHostsSignature = nextDisabledSignature;
      _requestViewRefresh();
    }

    await _settingsSync.handleSettingsChanged(
      mounted: true,
      persistedSignature: _persistedWorkspaceSignature(),
      currentSignature: _currentWorkspaceSignature(),
      restoreWorkspace: _restoreWorkspace,
      persistIfPending: _persistIfPending,
    );
  }

  void reloadServerList() {
    _setHostsFuture(_reloadHosts());
    _requestViewRefresh();
  }

  void startEmptyTab() {
    _addTab(_createPlaceholderTab());
  }

  void replaceTabWithAction(String tabId, SshHost host, ServerAction action) {
    if (action == ServerAction.portForward) {
      unawaited(_openPortForwardDialog(host));
      return;
    }
    _onHostInteraction(host);
    final index = _tabs().indexWhere((tab) => tab.id == tabId);
    if (index == -1) return;
    final tab = _createTab(
      id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: action,
    );
    _replaceTab(tabId, tab);
    _selectTab(index);
  }

  Future<void> activateEmptyTab(String tabId, SshHost host) async {
    final index = _tabs().indexWhere((tab) => tab.id == tabId);
    if (index == -1) return;
    final action = await _pickAction(host);
    if (action == null) return;
    if (action == ServerAction.portForward) {
      await _openPortForwardDialog(host);
      return;
    }
    _onHostInteraction(host);
    final tab = _createTab(id: tabId, host: host, action: action);
    _replaceTab(tabId, tab);
    _selectTab(index);
  }

  Future<void> startActionFlowForHost(SshHost host) async {
    final action = await _pickAction(host);
    if (action == null) return;
    if (action == ServerAction.portForward) {
      await _openPortForwardDialog(host);
      return;
    }
    addTab(host, action);
  }

  void addTab(SshHost host, ServerAction action) {
    _onHostInteraction(host);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    final tab = _createTab(
      id: '${host.name}-$timestamp-$random',
      host: host,
      action: action,
    );

    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    final currentTab =
        tabs.isNotEmpty && selectedIndex >= 0 && selectedIndex < tabs.length
        ? tabs[selectedIndex]
        : null;
    final shouldReplace =
        currentTab != null &&
        (currentTab.workspaceState as ServerTabData?)?.action ==
            ServerAction.empty;

    if (shouldReplace) {
      _replaceTab(currentTab.id, tab);
    } else {
      _addTab(tab);
    }
  }
}
