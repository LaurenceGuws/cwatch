import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/workspace_persistence.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/models/server_workspace_state.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_storage.dart';

void main() {
  group('WorkspacePersistence', () {
    test('load and read use the configured root mapping', () async {
      final rootController = _createRootController(
        loadedWorkspaces: const PersistedWorkspaces(),
      );
      final persistence = WorkspacePersistence<_FakeWorkspace>(
        workspaceRootController: rootController.controller,
        readFromRoot: (workspaces) => workspaces.server == null
            ? null
            : _FakeWorkspace(workspaces.server!),
        writeToRoot: (current, workspace) =>
            current.copyWith(server: workspace.state),
        signatureOf: (workspace) => workspace.signature,
      );

      expect(persistence.read(), isNull);

      await rootController.controller.update(
        (current) => current.copyWith(server: _FakeWorkspace.serverState('loaded')),
      );

      final loaded = await persistence.load();

      expect(loaded?.signature, 'loaded');
      expect(persistence.read()?.signature, 'loaded');
    });

    test('shouldRestore returns false after markRestored for same signature', () {
      final persistence = _createPersistence();
      final workspace = _FakeWorkspace.server('restored-once');

      expect(persistence.shouldRestore(workspace), isTrue);

      persistence.markRestored(workspace);

      expect(persistence.shouldRestore(workspace), isFalse);
      expect(persistence.shouldRestore(_FakeWorkspace.server('restored-twice')), isTrue);
    });

    test('persist writes through root controller and suppresses duplicate signatures', () async {
      final rootController = _createRootController(
        loadedWorkspaces: const PersistedWorkspaces(),
      );
  final persistence = _createPersistence(rootController: rootController);

      final first = _FakeWorkspace.server('sig-a');
      final duplicate = _FakeWorkspace.server('sig-a');
      final second = _FakeWorkspace.server('sig-b');

      await persistence.persist(first);
      await persistence.persist(duplicate);
      await persistence.persist(second);

      expect(rootController.storage.saveCount, 2);
      expect(rootController.storage.lastSaved?.server?.tabs.single.id, 'sig-b');
    });

    test('markRestored seeds duplicate suppression until signature changes', () async {
      final rootController = _createRootController(
        loadedWorkspaces: const PersistedWorkspaces(),
      );
      final persistence = _createPersistence(rootController: rootController);

      final restored = _FakeWorkspace.server('same-signature');
      persistence.markRestored(restored);

      await persistence.persist(restored);
      expect(rootController.storage.saveCount, 0);

      await persistence.persist(_FakeWorkspace.server('new-signature'));
      expect(rootController.storage.saveCount, 1);
      expect(
        rootController.storage.lastSaved?.server?.tabs.single.id,
        'new-signature',
      );
    });

    test('persistIfPending does nothing when no save is pending', () async {
      final persistence = _createPersistence();
      var called = false;

      persistence.persistIfPending(() async {
        called = true;
      });

      expect(called, isFalse);
    });
  });
}

WorkspacePersistence<_FakeWorkspace> _createPersistence({
  _TestRootControllerBundle? rootController,
}) {
  final bundle =
      rootController ??
      _createRootController(loadedWorkspaces: const PersistedWorkspaces());
  return WorkspacePersistence<_FakeWorkspace>(
    workspaceRootController: bundle.controller,
    readFromRoot: (workspaces) =>
        workspaces.server == null ? null : _FakeWorkspace(workspaces.server!),
    writeToRoot: (current, workspace) => current.copyWith(server: workspace.state),
    signatureOf: (workspace) => workspace.signature,
  );
}

_TestRootControllerBundle _createRootController({
  required PersistedWorkspaces loadedWorkspaces,
}) {
  final storage = _FakeWorkspaceStorage(loadedWorkspaces: loadedWorkspaces);
  final controller = WorkspaceRootController(
    settingsController: AppSettingsController(),
    storage: storage,
  );
  return _TestRootControllerBundle(controller: controller, storage: storage);
}

class _TestRootControllerBundle {
  _TestRootControllerBundle({required this.controller, required this.storage});

  final WorkspaceRootController controller;
  final _FakeWorkspaceStorage storage;
}

class _FakeWorkspace {
  _FakeWorkspace(this.state);

  final ServerWorkspaceState state;

  String get signature => state.tabs.single.id;

  static ServerWorkspaceState serverState(String id) {
    return ServerWorkspaceState(
      tabs: [TabState(id: id, kind: 'placeholder', title: 'Workspace $id')],
      selectedIndex: 0,
    );
  }

  static _FakeWorkspace server(String id) => _FakeWorkspace(serverState(id));
}

class _FakeWorkspaceStorage extends WorkspaceStorage {
  _FakeWorkspaceStorage({required this.loadedWorkspaces});

  final PersistedWorkspaces loadedWorkspaces;
  int saveCount = 0;
  PersistedWorkspaces? lastSaved;
  int loadCount = 0;

  @override
  Future<PersistedWorkspaces> load({
    PersistedWorkspaces fallback = const PersistedWorkspaces(),
  }) async {
    loadCount += 1;
    return loadedWorkspaces;
  }

  @override
  Future<void> save(PersistedWorkspaces workspaces) async {
    saveCount += 1;
    lastSaved = workspaces;
  }
}
