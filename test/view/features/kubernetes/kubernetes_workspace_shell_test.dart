import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_tab_builder.dart';
import 'package:cwatch/view/features/kubernetes/kubernetes_workspace_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KubernetesWorkspaceShell', () {
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

    test('initializeContexts seeds the contexts future', () async {
      final harness = _KubernetesShellHarness();

      final contexts = await harness.shell.initializeContexts();

      expect(contexts, hasLength(1));
      expect(harness.loadContextsCalls, 1);
      expect(harness.setContextsFutureCalls, 1);
    });

    test('initializeWorkspaceChrome registers shell handles', () {
      final harness = _KubernetesShellHarness();

      harness.shell.initializeWorkspaceChrome();

      expect(CommandPaletteRegistry.instance.forModule(_moduleId), isNotNull);
      expect(TabNavigationRegistry.instance.forModule(_moduleId), isNotNull);
    });

    test('buildCommandPaletteEntries includes generic tab commands', () async {
      final invokedActions = <String>[];
      final harness = _KubernetesShellHarness(
        selectedIndex: 1,
        tabs: [
          _placeholderTab('placeholder'),
          _detailsTab(
            'details',
            optionsController: TabOptionsController([
              TabChipOption(
                label: 'Copy context name',
                onSelected: () {
                  invokedActions.add('copy');
                },
              ),
            ]),
          ),
        ],
      );

      final entries = harness.shell.buildCommandPaletteEntries();

      expect(entries.map((entry) => entry.id), [
        '$_moduleId:tabOption:Copy context name',
        '$_moduleId:closeTab',
        '$_moduleId:newTab',
      ]);

      await entries[0].onSelected();
      await entries[1].onSelected();
      await entries[2].onSelected();

      expect(invokedActions, ['copy']);
      expect(harness.closedIndices, [1]);
      expect(harness.placeholderTabsAdded, 1);
    });

    test('tabNavigator selects next and previous tabs', () {
      final harness = _KubernetesShellHarness(
        tabs: [
          _placeholderTab('placeholder'),
          _detailsTab('details-a'),
          _detailsTab('details-b'),
        ],
      );

      final nextHandled = harness.shell.tabNavigator.next();
      final previousHandled = harness.shell.tabNavigator.previous();

      expect(nextHandled, isTrue);
      expect(previousHandled, isTrue);
      expect(harness.selectedIndices, [1, 0]);
    });

    test('handleSettingsChanged refreshes contexts and restores workspace when signatures diverge', () async {
      final harness = _KubernetesShellHarness();
      await harness.shell.initializeContexts();
      harness.persistedSignature = 'persisted-v2';

      await harness.shell.handleSettingsChanged();

      expect(harness.loadContextsCalls, 2);
      expect(harness.runWithoutPersistCalls, 1);
      expect(harness.persistStateCalls, 1);
      expect(harness.restoreWorkspaceCalls, 1);
      expect(harness.persistIfPendingCalls, 1);
    });

    test('refreshContexts replaces placeholder tabs only', () async {
      final harness = _KubernetesShellHarness(
        tabs: [
          _placeholderTab('placeholder-a'),
          _detailsTab('details'),
          _placeholderTab('placeholder-b'),
        ],
      );

      harness.shell.refreshContexts();
      await Future<void>.delayed(Duration.zero);

      expect(harness.loadContextsCalls, 1);
      expect(harness.runWithoutPersistCalls, 1);
      expect(harness.persistStateCalls, 1);
      expect(harness.replacedTabIds, ['placeholder-a', 'placeholder-b']);
      expect(harness.builtPlaceholderIds, ['placeholder-a', 'placeholder-b']);
    });

    test('openContextTab replaces selected placeholder', () {
      final harness = _KubernetesShellHarness(
        tabs: [
          _placeholderTab('placeholder'),
          _detailsTab('details'),
        ],
        selectedIndex: 0,
      );

      harness.shell.openContextTab(_context);

      expect(harness.replacedTabIds, ['placeholder']);
      expect(harness.addedTabs, isEmpty);
    });

    test('openContextTab appends when current tab is not placeholder', () {
      final harness = _KubernetesShellHarness(
        tabs: [
          _placeholderTab('placeholder'),
          _detailsTab('details'),
        ],
        selectedIndex: 1,
      );

      harness.shell.openContextTab(_context);

      expect(harness.replacedTabIds, isEmpty);
      expect(harness.addedTabs, hasLength(1));
    });
  });
}

const _moduleId = 'kubernetes';
const _context = KubeconfigContext(
  name: 'dev-cluster',
  cluster: 'dev-cluster',
  user: 'dev-user',
  server: 'https://k8s.example.com',
  configPath: '/tmp/config',
  namespace: 'default',
  isCurrent: true,
);

Future<List<CommandPaletteEntry>> _emptyEntries() async => const [];

bool _returnFalse() => false;

class _KubernetesShellHarness {
  _KubernetesShellHarness({
    List<WorkspaceTab>? tabs,
    int selectedIndex = 0,
  }) : _tabs = List<WorkspaceTab>.from(
         tabs ?? [_placeholderTab('placeholder')],
       ),
       _selectedIndex = selectedIndex;

  final List<WorkspaceTab> _tabs;
  int _selectedIndex;

  int loadContextsCalls = 0;
  int setContextsFutureCalls = 0;
  int restoreWorkspaceCalls = 0;
  int persistIfPendingCalls = 0;
  int persistStateCalls = 0;
  int runWithoutPersistCalls = 0;
  int placeholderTabsAdded = 0;
  String? persistedSignature;
  String currentSignature = 'current-v1';
  final List<int> selectedIndices = [];
  final List<int> closedIndices = [];
  final List<String> replacedTabIds = [];
  final List<String> builtPlaceholderIds = [];
  final List<WorkspaceTab> addedTabs = [];

  late final KubernetesWorkspaceShell shell = KubernetesWorkspaceShell(
    moduleId: _moduleId,
    loadContexts: () async {
      loadContextsCalls += 1;
      return const [_context];
    },
    setContextsFuture: (_) {
      setContextsFutureCalls += 1;
    },
    tabs: () => _tabs,
    selectedIndex: () => _selectedIndex,
    selectTab: (index) {
      _selectedIndex = index;
      selectedIndices.add(index);
    },
    closeTab: (index) {
      closedIndices.add(index);
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
      if ((tab.workspaceState as KubernetesTabData).context == null) {
        placeholderTabsAdded += 1;
      }
      _tabs.add(tab);
    },
    createPlaceholderTab: ({String? id}) {
      final tabId = id ?? 'placeholder-${placeholderTabsAdded + 1}';
      builtPlaceholderIds.add(tabId);
      return _placeholderTab(tabId);
    },
    createContextTab: ({
      required KubeconfigContext context,
      String? id,
      String? customName,
    }) => _detailsTab(id ?? 'details-${addedTabs.length + 1}', context: context),
    isPlaceholder: (tab) =>
        (tab.workspaceState as KubernetesTabData).persistedState.kind ==
        'placeholder',
    persistedWorkspaceSignature: () => persistedSignature,
    currentWorkspaceSignature: () => currentSignature,
    restoreWorkspace: () async {
      restoreWorkspaceCalls += 1;
    },
    persistIfPending: () async {
      persistIfPendingCalls += 1;
    },
    persistState: () async {
      persistStateCalls += 1;
    },
    runWithoutPersist: (action) {
      runWithoutPersistCalls += 1;
      action();
    },
  );
}

WorkspaceTab _placeholderTab(String id) {
  final builder = const KubernetesTabBuilder(
    placeholderName: '__k8s_placeholder__',
    placeholderConfig: '__k8s_placeholder__',
  );
  return builder.placeholder(id: id, body: const SizedBox.shrink());
}

WorkspaceTab _detailsTab(
  String id, {
  KubeconfigContext context = _context,
  TabOptionsController? optionsController,
}) {
  final builder = const KubernetesTabBuilder(
    placeholderName: '__k8s_placeholder__',
    placeholderConfig: '__k8s_placeholder__',
  );
  return builder.details(
    id: id,
    context: context,
    body: const SizedBox.shrink(),
    optionsController: optionsController,
  );
}
