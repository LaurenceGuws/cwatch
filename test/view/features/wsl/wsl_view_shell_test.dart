import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/features/wsl/wsl_view_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WslViewShell', () {
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

    test('initializeWorkspaceChrome registers shell handles', () {
      final harness = _WslShellHarness();

      harness.shell.initializeWorkspaceChrome();

      expect(CommandPaletteRegistry.instance.forModule(_moduleId), isNotNull);
      expect(TabNavigationRegistry.instance.forModule(_moduleId), isNotNull);
    });

    test('buildCommandPaletteEntries includes generic tab commands', () async {
      final invokedActions = <String>[];
      final harness = _WslShellHarness(
        selectedIndex: 1,
        tabs: [
          _tab('picker', canRename: false),
          _tab(
            'ubuntu',
            canRename: true,
            optionsController: TabOptionsController([
              TabChipOption(
                label: 'Restart session',
                onSelected: () {
                  invokedActions.add('restart');
                },
              ),
            ]),
          ),
        ],
      );

      final entries = harness.shell.buildCommandPaletteEntries();

      expect(entries.map((entry) => entry.id), [
        '$_moduleId:tabOption:Restart session',
        '$_moduleId:renameTab',
        '$_moduleId:closeTab',
        '$_moduleId:newTab',
      ]);

      await entries[0].onSelected();
      await entries[1].onSelected();
      await entries[2].onSelected();
      await entries[3].onSelected();

      expect(invokedActions, ['restart']);
      expect(harness.renamedIndices, [1]);
      expect(harness.closedIndices, [1]);
      expect(harness.addPickerCalls, 1);
    });

    test('tabNavigator selects next and previous tabs', () {
      final harness = _WslShellHarness(
        tabs: [
          _tab('picker'),
          _tab('ubuntu'),
          _tab('debian'),
        ],
      );

      final nextHandled = harness.shell.tabNavigator.next();
      final previousHandled = harness.shell.tabNavigator.previous();

      expect(nextHandled, isTrue);
      expect(previousHandled, isTrue);
      expect(harness.selectedIndices, [1, 0]);
    });

    test('handleSettingsChanged restores workspace when signatures diverge', () async {
      final harness = _WslShellHarness();
      harness.persistedSignature = 'persisted-v2';

      await harness.shell.handleSettingsChanged();

      expect(harness.restoreWorkspaceCalls, 1);
      expect(harness.persistIfPendingCalls, 1);
    });
  });
}

const _moduleId = 'wsl';

Future<List<CommandPaletteEntry>> _emptyEntries() async => const [];

bool _returnFalse() => false;

class _WslShellHarness {
  _WslShellHarness({
    List<WorkspaceTab>? tabs,
    int selectedIndex = 0,
  }) : _tabs = List<WorkspaceTab>.from(tabs ?? [_tab('picker')]),
       _selectedIndex = selectedIndex;

  final List<WorkspaceTab> _tabs;
  int _selectedIndex;

  int restoreWorkspaceCalls = 0;
  int persistIfPendingCalls = 0;
  int addPickerCalls = 0;
  String? persistedSignature;
  String currentSignature = 'current-v1';
  final List<int> selectedIndices = [];
  final List<int> closedIndices = [];
  final List<int> renamedIndices = [];

  late final WslViewShell shell = WslViewShell(
    moduleId: _moduleId,
    tabs: () => _tabs,
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
    addPickerTab: () {
      addPickerCalls += 1;
    },
    persistedWorkspaceSignature: () => persistedSignature,
    currentWorkspaceSignature: () => currentSignature,
    restoreWorkspace: () async {
      restoreWorkspaceCalls += 1;
    },
    persistIfPending: () async {
      persistIfPendingCalls += 1;
    },
  );
}

WorkspaceTab _tab(
  String id, {
  bool canRename = true,
  TabOptionsController? optionsController,
}) {
  return WorkspaceTab(
    id: id,
    title: id,
    label: id,
    icon: Icons.terminal,
    body: const SizedBox.shrink(),
    canRename: canRename,
    optionsController: optionsController,
  );
}
