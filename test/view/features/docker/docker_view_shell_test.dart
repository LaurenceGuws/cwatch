import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_storage.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_view_runtime.dart';
import 'package:cwatch/view/features/docker/docker_view_shell.dart';
import 'package:cwatch/view/features/docker/docker_workspace_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DockerViewShell', () {
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

    test('initialize registers shell handles and kicks off context loading', () async {
      final harness = _DockerShellHarness();

      await harness.shell.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(CommandPaletteRegistry.instance.forModule(_moduleId), isNotNull);
      expect(TabNavigationRegistry.instance.forModule(_moduleId), isNotNull);
      expect(harness.viewController.loadCalls, 1);
    });

    test('buildCommandPaletteEntries includes generic tab commands', () async {
      final invokedActions = <String>[];
      final harness = _DockerShellHarness(
        selectedIndex: 1,
        tabs: [
          _tab('picker', picker: true),
          _tab(
            'overview',
            canRename: true,
            optionsController: TabOptionsController([
              TabChipOption(
                label: 'Inspect',
                onSelected: () {
                  invokedActions.add('inspect');
                },
              ),
            ]),
          ),
        ],
      );

      final entries = harness.shell.buildCommandPaletteEntries();

      expect(entries.map((entry) => entry.id), [
        '$_moduleId:tabOption:Inspect',
        '$_moduleId:renameTab',
        '$_moduleId:closeTab',
        '$_moduleId:newTab',
      ]);

      await entries[0].onSelected();
      await entries[1].onSelected();
      await entries[2].onSelected();
      await entries[3].onSelected();

      expect(invokedActions, ['inspect']);
      expect(harness.renamedIndices, [1]);
      expect(harness.closedIndices, [1]);
      expect(harness.addPickerCalls, 1);
    });

    test('refreshContexts refreshes controller and replaces picker tabs only', () async {
      final harness = _DockerShellHarness(
        tabs: [
          _tab('picker-a', picker: true),
          _tab('overview'),
          _tab('picker-b', picker: true),
        ],
      );

      harness.shell.refreshContexts();
      await Future<void>.delayed(Duration.zero);

      expect(harness.viewController.refreshCalls, 1);
      expect(harness.replacedTabIds, ['picker-a', 'picker-b']);
      expect(harness.builtPickerIds, ['picker-a', 'picker-b']);
      expect(harness.workspaceController.persistCalls, 1);
      expect(harness.workspaceController.runWithoutPersistCalls, 1);
    });

    test('tabNavigator selects next and previous tabs', () {
      final harness = _DockerShellHarness(
        tabs: [
          _tab('picker', picker: true),
          _tab('overview'),
          _tab('resources'),
        ],
      );

      final nextHandled = harness.shell.tabNavigator.next();
      final previousHandled = harness.shell.tabNavigator.previous();

      expect(nextHandled, isTrue);
      expect(previousHandled, isTrue);
      expect(harness.workspaceController.selectedIndices, [1, 0]);
    });
  });
}

const _moduleId = 'docker';

Future<List<CommandPaletteEntry>> _emptyEntries() async => const [];

bool _returnFalse() => false;

class _DockerShellHarness {
  _DockerShellHarness({
    List<WorkspaceTab>? tabs,
    int selectedIndex = 0,
  }) : viewController = _FakeDockerViewController(),
       workspaceController = _FakeDockerWorkspaceController(
         baseTab: (tabs ?? [_tab('picker', picker: true)]).first,
       ),
       invokedActions = [],
       renamedIndices = [],
       closedIndices = [],
       replacedTabIds = [],
       builtPickerIds = [] {
    final initialTabs = tabs ?? [_tab('picker', picker: true)];
    workspaceController.replaceAll(initialTabs, selectedIndex: selectedIndex);

    final settingsController = AppSettingsController();
    final shellFactory = SshShellFactory(
      settingsController: settingsController,
      keyService: BuiltInSshKeyService(),
    );
    final runtime = DockerViewRuntime(
      docker: const DockerClientService(),
      viewController: viewController,
      distroCacheController: DistroCacheController(storage: _MemoryCacheStorage()),
      trashManager: ExplorerTrashManager(),
      portForwardService: PortForwardService(),
      tabBuilder: DockerTabBuilder(
        docker: const DockerClientService(),
        settingsController: settingsController,
        distroCacheController: DistroCacheController(storage: _MemoryCacheStorage()),
        trashManager: ExplorerTrashManager(),
        keyService: BuiltInSshKeyService(),
        portForwardService: PortForwardService(),
        hostsFuture: Future.value(const []),
      ),
      workspaceController: workspaceController,
      shellCallbacks: DockerShellCallbacks(shellFactory: shellFactory),
    );

    shell = DockerViewShell(
      moduleId: _moduleId,
      runtime: runtime,
      viewController: viewController,
      tabs: () => workspaceController.tabs,
      selectedIndex: () => workspaceController.selectedIndex,
      buildPickerTab: ({String? id}) {
        if (id != null) {
          builtPickerIds.add(id);
        }
        return _tab(id ?? 'picker-new', picker: true);
      },
      replaceTab: (id, tab) {
        replacedTabIds.add(id);
        workspaceController.replaceTab(id, tab);
      },
      addPickerTab: () {
        addPickerCalls += 1;
      },
      closeTab: (index) {
        closedIndices.add(index);
      },
      renameTab: (index) {
        renamedIndices.add(index);
      },
    );
  }

  final _FakeDockerViewController viewController;
  final _FakeDockerWorkspaceController workspaceController;
  final List<String> invokedActions;
  final List<int> renamedIndices;
  final List<int> closedIndices;
  final List<String> replacedTabIds;
  final List<String> builtPickerIds;
  late final DockerViewShell shell;
  int addPickerCalls = 0;
}

class _FakeDockerViewController extends DockerViewController {
  _FakeDockerViewController() : super(docker: const DockerClientService());

  int loadCalls = 0;
  int refreshCalls = 0;

  @override
  Future<List<DockerContext>> loadContexts() async {
    loadCalls += 1;
    return const [];
  }

  @override
  void refreshContexts() {
    refreshCalls += 1;
  }
}

class _FakeDockerWorkspaceController extends DockerWorkspaceController {
  _FakeDockerWorkspaceController({required WorkspaceTab baseTab})
    : super(
        settingsController: AppSettingsController(),
        workspaceRootController: WorkspaceRootController(
          settingsController: AppSettingsController(),
          storage: _MemoryWorkspaceStorage(),
        ),
        baseTabBuilder: () => baseTab,
      );

  int persistCalls = 0;
  int runWithoutPersistCalls = 0;
  final List<int> selectedIndices = [];

  @override
  Future<void> persistState() async {
    persistCalls += 1;
  }

  @override
  T runWithoutPersist<T>(T Function() action) {
    runWithoutPersistCalls += 1;
    return super.runWithoutPersist(action);
  }

  @override
  void select(int index) {
    super.select(index);
    selectedIndices.add(selectedIndex);
  }
}

class _MemoryWorkspaceStorage extends WorkspaceStorage {
  _MemoryWorkspaceStorage();

  @override
  Future<void> save(workspaces) async {}

  @override
  Future<PersistedWorkspaces> load({
    PersistedWorkspaces fallback = const PersistedWorkspaces(),
  }) async => fallback;
}

class _MemoryCacheStorage extends CacheStorage {
  _MemoryCacheStorage();

  final Map<String, dynamic> _values = {};

  @override
  Future<Map<String, String>> readStringMap(String key) async {
    final raw = _values[key];
    if (raw is Map<String, String>) {
      return raw;
    }
    return const {};
  }

  @override
  Future<void> writeStringMap(String key, Map<String, String> values) async {
    _values[key] = Map<String, String>.from(values);
  }
}

WorkspaceTab _tab(
  String id, {
  bool picker = false,
  bool canRename = false,
  TabOptionsController? optionsController,
}) {
  return WorkspaceTab(
    id: id,
    title: id,
    label: id,
    icon: Icons.cloud,
    body: const SizedBox.shrink(),
    canRename: canRename,
    isPicker: picker,
    workspaceState: DockerTabData(
      kind: picker ? DockerTabKind.picker : DockerTabKind.contextOverview,
      persistedState: TabState(
        id: id,
        kind: picker
            ? DockerTabKind.picker.name
            : DockerTabKind.contextOverview.name,
      ),
    ),
    optionsController: optionsController,
  );
}
