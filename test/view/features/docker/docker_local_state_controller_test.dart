import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/docker/models/remote_docker_status.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/model/models/persisted_workspaces.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_storage.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/view/features/docker/docker_local_state_controller.dart';
import 'package:cwatch/view/features/docker/docker_workspace_controller.dart';
import 'package:cwatch/view/features/docker/local_docker_context_status.dart';

void main() {
  group('DockerLocalStateController', () {
    test('ensureLocalContextsStatusFuture caches until refresh', () async {
      final harness = _DockerLocalHarness();
      final controller = harness.controller;

      final first = controller.ensureLocalContextsStatusFuture();
      final second = controller.ensureLocalContextsStatusFuture();

      expect(identical(first, second), isTrue);
      await first;
      expect(controller.loadLocalCalls, 1);

      controller.refreshContexts();
      final third = controller.ensureLocalContextsStatusFuture();
      await third;

      expect(identical(first, third), isFalse);
      expect(controller.loadLocalCalls, 2);
    });

    test('beginRemoteScan and completeRemoteScan update scan lifecycle', () async {
      final harness = _DockerLocalHarness();
      final controller = harness.controller;

      final token = controller.beginRemoteScan();

      expect(token, 1);
      expect(controller.scanningRemotes, isTrue);
      expect(controller.scanningNotifier.value, isTrue);
      expect(controller.remoteScanRequested, isTrue);

      harness.remoteStatusesCompleter.complete(const [
        RemoteDockerStatus(
          host: SshHost(
            name: 'alpha',
            hostname: 'alpha.example.com',
            port: 22,
            available: true,
          ),
          available: true,
          detail: 'Ready',
        ),
      ]);
      await controller.completeRemoteScan(token);

      expect(controller.scanningRemotes, isFalse);
      expect(controller.scanningNotifier.value, isFalse);
      expect(harness.requestRefreshCalls, greaterThan(0));
    });

    test('cancelRemoteScan marks token cancelled and keeps scan stopped', () async {
      final harness = _DockerLocalHarness();
      final controller = harness.controller;
      final token = controller.beginRemoteScan();

      controller.cancelRemoteScan(token);
      harness.remoteStatusesCompleter.complete(const []);
      await controller.completeRemoteScan(token);

      expect(controller.isScanCancelled(token), isTrue);
      expect(controller.scanningRemotes, isFalse);
      expect(controller.scanningNotifier.value, isFalse);
    });

    test('isHostEnabled filters unavailable disabled and no-shell hosts', () {
      final controller = _DockerLocalHarness().controller;

      expect(
        controller.isHostEnabled(
          const SshHost(
            name: 'ok',
            hostname: 'ok.example.com',
            port: 22,
            available: true,
          ),
          const {},
          const {},
        ),
        isTrue,
      );

      expect(
        controller.isHostEnabled(
          const SshHost(
            name: 'down',
            hostname: 'down.example.com',
            port: 22,
            available: false,
          ),
          const {},
          const {},
        ),
        isFalse,
      );

      expect(
        controller.isHostEnabled(
          const SshHost(
            name: 'disabled',
            hostname: 'disabled.example.com',
            port: 22,
            available: true,
          ),
          const {'disabled.example.com'},
          const {},
        ),
        isFalse,
      );

      expect(
        controller.isHostEnabled(
          const SshHost(
            name: 'noshell',
            hostname: 'github.com',
            port: 22,
            available: true,
          ),
          const {},
          const {},
        ),
        isFalse,
      );
    });
  });
}

class _DockerLocalHarness {
  _DockerLocalHarness() {
    controller = _TestDockerLocalStateController(
      onRequestRefresh: () {
        requestRefreshCalls += 1;
      },
      remoteStatusesCompleter: remoteStatusesCompleter,
    );
  }

  late final _TestDockerLocalStateController controller;
  int loadLocalCalls = 0;
  int requestRefreshCalls = 0;
  final Completer<List<RemoteDockerStatus>> remoteStatusesCompleter =
      Completer<List<RemoteDockerStatus>>();
}

class _TestDockerLocalStateController extends DockerLocalStateController {
  _TestDockerLocalStateController({
    required VoidCallback onRequestRefresh,
    required this.remoteStatusesCompleter,
  }) : super(
         settingsController: AppSettingsController(),
         workspaceController: _FakeDockerWorkspaceController(
           baseTab: const WorkspaceTab(
             id: 'base',
             title: 'Base',
             label: 'Base',
             icon: Icons.dns,
             body: SizedBox.shrink(),
             workspaceState: DockerWorkspaceState(tabs: <TabState>[], selectedIndex: 0),
           ),
         ),
         viewController: _FakeDockerViewController(),
         shellFactory: SshShellFactory(
           settingsController: AppSettingsController(),
           keyService: BuiltInSshKeyService(),
         ),
         hostsFuture: Future.value(const []),
         requestRefresh: onRequestRefresh,
         refreshPickerTabs: () {},
       );

  int loadLocalCalls = 0;
  final Completer<List<RemoteDockerStatus>> remoteStatusesCompleter;

  @override
  Future<List<LocalDockerContextStatus>> loadLocalContextsStatus() async {
    loadLocalCalls += 1;
    return const [];
  }

  @override
  Future<List<RemoteDockerStatus>> loadRemoteStatuses({
    bool manual = false,
    int token = 0,
  }) async {
    final result = await remoteStatusesCompleter.future;
    if (manual && !isScanCancelled(token)) {
      scanStatusesNotifier.value = result;
      requestRefresh();
    }
    return result;
  }
}

class _FakeDockerViewController extends DockerViewController {
  _FakeDockerViewController() : super(docker: DockerClientService());

  @override
  Future<List<DockerContext>> loadContexts() async => const [];
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
}

class _MemoryWorkspaceStorage extends WorkspaceStorage {
  _MemoryWorkspaceStorage() : super();

  PersistedWorkspaces _workspaces = const PersistedWorkspaces();

  @override
  Future<PersistedWorkspaces> load({
    PersistedWorkspaces fallback = const PersistedWorkspaces(),
  }) async => _workspaces;

  @override
  Future<void> save(PersistedWorkspaces workspaces) async {
    _workspaces = workspaces;
  }
}
