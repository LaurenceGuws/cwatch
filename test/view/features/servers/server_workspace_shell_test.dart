import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/features/servers/server_workspace_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerWorkspaceShell', () {
    tearDown(() {
      CommandPaletteRegistry.instance.unregister(
        _moduleId,
        CommandPaletteRegistry.instance.forModule(_moduleId) ??
            const CommandPaletteHandle(loader: _emptyEntries),
      );
      TabNavigationRegistry.instance.unregister(
        _moduleId,
        TabNavigationRegistry.instance.forModule(_moduleId) ??
            const TabNavigationHandle(next: _returnFalse, previous: _returnFalse),
      );
    });

    test('initializeHosts seeds signatures from the provided host future', () async {
      final harness = _ServerShellHarness();
      final initialFuture = Future<List<SshHost>>.value(const [_host]);

      final hosts = await harness.shell.initializeHosts(initialFuture);

      expect(hosts, hasLength(1));
      expect(harness.loadHostsCalls, 0);
      expect(harness.reloadHostsCalls, 0);
      expect(harness.setHostsFutureCalls, 1);
    });

    test('initializeWorkspaceChrome registers shell handles', () {
      final harness = _ServerShellHarness();

      harness.shell.initializeWorkspaceChrome();

      expect(CommandPaletteRegistry.instance.forModule(_moduleId), isNotNull);
      expect(TabNavigationRegistry.instance.forModule(_moduleId), isNotNull);
    });

    test('buildCommandPaletteEntries includes generic tab commands', () async {
      final invokedActions = <String>[];
      final harness = _ServerShellHarness(
        selectedIndex: 1,
        tabs: [
          _tab('placeholder', action: ServerAction.empty),
          _tab(
            'terminal',
            action: ServerAction.terminal,
            optionsController: TabOptionsController([
              TabChipOption(
                label: 'Reconnect',
                onSelected: () {
                  invokedActions.add('reconnect');
                },
              ),
            ]),
          ),
        ],
      );

      final entries = harness.shell.buildCommandPaletteEntries();

      expect(entries.map((entry) => entry.id), [
        '$_moduleId:tabOption:Reconnect',
        '$_moduleId:renameTab',
        '$_moduleId:closeTab',
        '$_moduleId:newTab',
      ]);

      await entries[0].onSelected();
      await entries[1].onSelected();
      await entries[2].onSelected();
      await entries[3].onSelected();

      expect(invokedActions, ['reconnect']);
      expect(harness.renamedIndices, [1]);
      expect(harness.closedIndices, [1]);
      expect(harness.placeholderTabsAdded, 1);
    });

    test('tabNavigator selects next and previous tabs', () {
      final harness = _ServerShellHarness(
        tabs: [
          _tab('placeholder', action: ServerAction.empty),
          _tab('resources', action: ServerAction.resources),
          _tab('terminal', action: ServerAction.terminal),
        ],
      );

      final nextHandled = harness.shell.tabNavigator.next();
      final previousHandled = harness.shell.tabNavigator.previous();

      expect(nextHandled, isTrue);
      expect(previousHandled, isTrue);
      expect(harness.selectedIndices, [1, 0]);
    });

    test('handleSettingsChanged refreshes hosts without probing when config paths change', () async {
      final harness = _ServerShellHarness();
      harness.shell.initializeHosts(Future<List<SshHost>>.value(const [_host]));
      harness.pathsSignature = 'paths-v2';

      await harness.shell.handleSettingsChanged();

      expect(harness.loadHostsCalls, 1);
      expect(harness.reloadHostsCalls, 0);
      expect(harness.updateCustomHostsCalls, 0);
      expect(harness.restoreWorkspaceCalls, 0);
      expect(harness.persistIfPendingCalls, 1);
    });

    test('handleSettingsChanged updates custom hosts when custom signature changes', () async {
      final harness = _ServerShellHarness();
      harness.shell.initializeHosts(Future<List<SshHost>>.value(const [_host]));
      harness.customHostsSignature = 'custom-v2';

      await harness.shell.handleSettingsChanged();

      expect(harness.loadHostsCalls, 0);
      expect(harness.reloadHostsCalls, 0);
      expect(harness.updateCustomHostsCalls, 1);
      expect(harness.persistIfPendingCalls, 1);
    });

    test('handleSettingsChanged restores workspace when signatures diverge', () async {
      final harness = _ServerShellHarness();
      harness.shell.initializeHosts(Future<List<SshHost>>.value(const [_host]));
      harness.persistedSignature = 'persisted-v2';

      await harness.shell.handleSettingsChanged();

      expect(harness.restoreWorkspaceCalls, 1);
      expect(harness.persistIfPendingCalls, 1);
    });

    test('reloadServerList uses the explicit probing refresh path', () {
      final harness = _ServerShellHarness();

      harness.shell.reloadServerList();

      expect(harness.loadHostsCalls, 0);
      expect(harness.reloadHostsCalls, 1);
      expect(harness.requestViewRefreshCalls, 1);
      expect(harness.setHostsFutureCalls, 1);
    });

    test('replaceTabWithAction replaces placeholder and selects index', () {
      final harness = _ServerShellHarness(
        tabs: [
          _tab('placeholder', action: ServerAction.empty),
          _tab('resources', action: ServerAction.resources),
        ],
      );

      harness.shell.replaceTabWithAction(
        'placeholder',
        _host,
        ServerAction.terminal,
      );

      expect(harness.hostInteractions, [_host.name]);
      expect(harness.replacedTabIds, ['placeholder']);
      expect(harness.selectedIndices, [0]);
    });

    test('addTab replaces selected empty placeholder', () {
      final harness = _ServerShellHarness(
        tabs: [
          _tab('placeholder', action: ServerAction.empty),
          _tab('resources', action: ServerAction.resources),
        ],
        selectedIndex: 0,
      );

      harness.shell.addTab(_host, ServerAction.terminal);

      expect(harness.hostInteractions, [_host.name]);
      expect(harness.replacedTabIds, ['placeholder']);
      expect(harness.addedTabs, isEmpty);
    });

    test('addTab appends when current tab is not empty', () {
      final harness = _ServerShellHarness(
        tabs: [
          _tab('placeholder', action: ServerAction.empty),
          _tab('resources', action: ServerAction.resources),
        ],
        selectedIndex: 1,
      );

      harness.shell.addTab(_host, ServerAction.terminal);

      expect(harness.hostInteractions, [_host.name]);
      expect(harness.replacedTabIds, isEmpty);
      expect(harness.addedTabs, hasLength(1));
    });
  });
}

const _moduleId = 'servers';
const _host = SshHost(
  name: 'alpha',
  hostname: 'alpha.example.com',
  port: 22,
  available: true,
);

Future<List<CommandPaletteEntry>> _emptyEntries() async => const [];

bool _returnFalse() => false;

class _ServerShellHarness {
  _ServerShellHarness({
    List<WorkspaceTab>? tabs,
    int selectedIndex = 0,
  }) : _tabs = List<WorkspaceTab>.from(
         tabs ?? [_tab('placeholder', action: ServerAction.empty)],
       ),
       _selectedIndex = selectedIndex;

  final List<WorkspaceTab> _tabs;
  int _selectedIndex;

  int loadHostsCalls = 0;
  int reloadHostsCalls = 0;
  int updateCustomHostsCalls = 0;
  int setHostsFutureCalls = 0;
  int requestViewRefreshCalls = 0;
  int restoreWorkspaceCalls = 0;
  int persistIfPendingCalls = 0;
  int placeholderTabsAdded = 0;
  int portForwardOpens = 0;
  String customHostsSignature = 'custom-v1';
  String pathsSignature = 'paths-v1';
  String disabledHostsSignature = 'disabled-v1';
  String? persistedSignature;
  String currentSignature = 'current-v1';
  final List<int> selectedIndices = [];
  final List<int> closedIndices = [];
  final List<int> renamedIndices = [];
  final List<String> replacedTabIds = [];
  final List<WorkspaceTab> addedTabs = [];
  final List<String> hostInteractions = [];
  List<CustomSshHost> customHosts = const [
    CustomSshHost(name: 'alpha', hostname: 'alpha.example.com'),
  ];

  late final ServerWorkspaceShell shell = ServerWorkspaceShell(
    moduleId: _moduleId,
    loadHosts: () async {
      loadHostsCalls += 1;
      return const [_host];
    },
    reloadHosts: () async {
      reloadHostsCalls += 1;
      return const [_host];
    },
    updateCustomHosts: (hosts) async {
      updateCustomHostsCalls += 1;
      return hosts
          .map(
            (host) => SshHost(
              name: host.name,
              hostname: host.hostname,
              port: host.port,
              available: true,
              user: host.user,
              identityFiles: host.identityFile == null
                  ? const []
                  : [host.identityFile!],
              source: 'custom',
            ),
          )
          .toList();
    },
    buildCustomHostsSignature: () => customHostsSignature,
    buildPathsSignature: () => pathsSignature,
    buildDisabledHostsSignature: () => disabledHostsSignature,
    setHostsFuture: (_) {
      setHostsFutureCalls += 1;
    },
    requestViewRefresh: () {
      requestViewRefreshCalls += 1;
    },
    persistedWorkspaceSignature: () => persistedSignature,
    currentWorkspaceSignature: () => currentSignature,
    restoreWorkspace: () async {
      restoreWorkspaceCalls += 1;
    },
    persistIfPending: () async {
      persistIfPendingCalls += 1;
    },
    tabs: () => List.unmodifiable(_tabs),
    selectedIndex: () => _selectedIndex,
    selectTab: (index) {
      _selectedIndex = index;
      selectedIndices.add(index);
    },
    closeTab: (index) {
      closedIndices.add(index);
    },
    renameTab: (index) async {
      renamedIndices.add(index);
    },
    replaceTab: (tabId, replacement) {
      replacedTabIds.add(tabId);
      final index = _tabs.indexWhere((tab) => tab.id == tabId);
      if (index != -1) {
        _tabs[index] = replacement;
      }
    },
    addTab: (tab) {
      addedTabs.add(tab);
      if ((tab.workspaceState as ServerTabData?)?.action == ServerAction.empty) {
        placeholderTabsAdded += 1;
      }
      _tabs.add(tab);
    },
    createPlaceholderTab: () => _tab(
      'placeholder-${placeholderTabsAdded + 1}',
      action: ServerAction.empty,
    ),
    createTab: ({required id, required host, required action}) {
      return _tab(id, action: action, host: host);
    },
    onHostInteraction: (host) {
      hostInteractions.add(host.name);
    },
    openPortForwardDialog: (_) async {
      portForwardOpens += 1;
    },
    pickAction: (_) async => ServerAction.terminal,
    customHosts: () => customHosts,
  );
}

WorkspaceTab _tab(
  String id, {
  required ServerAction action,
  SshHost host = _host,
  TabOptionsController? optionsController,
}) {
  return WorkspaceTab(
    id: id,
    title: id,
    label: id,
    icon: Icons.computer,
    body: const SizedBox.shrink(),
    canRename: true,
    workspaceState: ServerTabData(
      host: host,
      action: action,
      persistedState: TabState(
        id: id,
        kind: action.name,
        title: id,
        hostName: host.name,
      ),
    ),
    optionsController: optionsController,
  );
}
