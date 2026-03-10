import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/models/server_workspace_state.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_storage.dart';

void main() {
  group('WorkspaceRootController', () {
    test('loads persisted workspaces from dedicated storage', () async {
      final settingsController = AppSettingsController();
      final storage = _FakeWorkspaceStorage(
        loadedWorkspaces: PersistedWorkspaces(
          server: _serverWorkspace('server-from-storage'),
          docker: _dockerWorkspace('docker-from-storage'),
        ),
      );

      final controller = WorkspaceRootController(
        settingsController: settingsController,
        storage: storage,
      );

      final loaded = await controller.ensureLoaded();

      expect(controller.isLoaded, isTrue);
      expect(storage.loadCount, 1);
      expect(loaded.server?.tabs.single.id, 'server-from-storage');
      expect(loaded.docker?.tabs.single.id, 'docker-from-storage');
      expect(storage.capturedFallback.server, isNull);
      expect(storage.capturedFallback.docker, isNull);
    });

    test('falls back to legacy embedded workspace data from AppSettings', () async {
      final settingsController = AppSettingsController();
      settingsController.applyOverrides(
        (current) => current.copyWith(
          serverWorkspace: _serverWorkspace('server-from-settings'),
          dockerWorkspace: _dockerWorkspace('docker-from-settings'),
        ),
      );
      final storage = _FakeWorkspaceStorage(useFallbackOnLoad: true);

      final controller = WorkspaceRootController(
        settingsController: settingsController,
        storage: storage,
      );

      final loaded = await controller.ensureLoaded();

      expect(storage.loadCount, 1);
      expect(storage.capturedFallback.server?.tabs.single.id, 'server-from-settings');
      expect(storage.capturedFallback.docker?.tabs.single.id, 'docker-from-settings');
      expect(loaded.server?.tabs.single.id, 'server-from-settings');
      expect(loaded.docker?.tabs.single.id, 'docker-from-settings');
    });

    test('update saves the dedicated workspace root', () async {
      final settingsController = AppSettingsController();
      final storage = _FakeWorkspaceStorage(useFallbackOnLoad: true);
      final controller = WorkspaceRootController(
        settingsController: settingsController,
        storage: storage,
      );

      await controller.update(
        (current) => current.copyWith(server: _serverWorkspace('updated-server')),
      );

      expect(storage.loadCount, 1);
      expect(storage.saveCount, 1);
      expect(controller.workspaces.server?.tabs.single.id, 'updated-server');
      expect(storage.lastSaved?.server?.tabs.single.id, 'updated-server');
    });

    test('coalesces concurrent ensureLoaded calls', () async {
      final settingsController = AppSettingsController();
      final completer = Completer<PersistedWorkspaces>();
      final storage = _FakeWorkspaceStorage(loadCompleter: completer);
      final controller = WorkspaceRootController(
        settingsController: settingsController,
        storage: storage,
      );

      final firstLoad = controller.ensureLoaded();
      final secondLoad = controller.ensureLoaded();

      expect(storage.loadCount, 1);

      completer.complete(
        PersistedWorkspaces(server: _serverWorkspace('coalesced-server')),
      );

      final results = await Future.wait([firstLoad, secondLoad]);

      expect(results[0].server?.tabs.single.id, 'coalesced-server');
      expect(results[1].server?.tabs.single.id, 'coalesced-server');
      expect(storage.loadCount, 1);
      expect(controller.isLoaded, isTrue);
    });
  });
}

class _FakeWorkspaceStorage extends WorkspaceStorage {
  _FakeWorkspaceStorage({
    this.loadedWorkspaces,
    this.useFallbackOnLoad = false,
    this.loadCompleter,
  });

  final PersistedWorkspaces? loadedWorkspaces;
  final bool useFallbackOnLoad;
  final Completer<PersistedWorkspaces>? loadCompleter;

  int loadCount = 0;
  int saveCount = 0;
  PersistedWorkspaces capturedFallback = const PersistedWorkspaces();
  PersistedWorkspaces? lastSaved;

  @override
  Future<PersistedWorkspaces> load({
    PersistedWorkspaces fallback = const PersistedWorkspaces(),
  }) async {
    loadCount += 1;
    capturedFallback = fallback;
    final completer = loadCompleter;
    if (completer != null) {
      return completer.future;
    }
    if (useFallbackOnLoad) {
      return fallback;
    }
    return loadedWorkspaces ?? fallback;
  }

  @override
  Future<void> save(PersistedWorkspaces workspaces) async {
    saveCount += 1;
    lastSaved = workspaces;
  }
}

ServerWorkspaceState _serverWorkspace(String tabId) {
  return ServerWorkspaceState(
    tabs: [TabState(id: tabId, kind: 'placeholder', title: 'Server Placeholder')],
    selectedIndex: 0,
  );
}

DockerWorkspaceState _dockerWorkspace(String tabId) {
  return DockerWorkspaceState(
    tabs: [TabState(id: tabId, kind: 'picker', title: 'Docker Picker')],
    selectedIndex: 0,
  );
}
