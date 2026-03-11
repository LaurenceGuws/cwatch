import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_view_dashboard_helper.dart';

void main() {
  group('DockerViewDashboardHelper', () {
    late DockerViewDashboardHelper helper;
    late DockerTabBuilder tabBuilder;
    late DockerShellCallbacks shellCallbacks;
    late List<String> closedTabs;
    late List<WorkspaceTab> openedTabs;

    setUp(() {
      helper = const DockerViewDashboardHelper();
      closedTabs = [];
      openedTabs = [];
      tabBuilder = DockerTabBuilder(
        docker: _FakeDockerClientService(),
        settingsController: AppSettingsController(),
        distroCacheController: DistroCacheController(
          storage: _MemoryCacheStorage(),
        ),
        trashManager: ExplorerTrashManager(),
        keyService: BuiltInSshKeyService(),
        portForwardService: PortForwardService(),
        hostsFuture: Future.value(const []),
      );
      final shellFactory = SshShellFactory(
        settingsController: AppSettingsController(),
        keyService: BuiltInSshKeyService(),
      );
      shellCallbacks = DockerShellCallbacks(shellFactory: shellFactory);
    });

    test('buildContextDashboardTab creates context resources tabs', () {
      final tab = helper.buildContextDashboardTab(
        contextName: 'ctx-a',
        target: DockerDashboardTarget.resources,
        icon: Icons.cloud,
        tabBuilder: tabBuilder,
        onOpenTab: openedTabs.add,
        onCloseTab: closedTabs.add,
        id: 'ctx-fixed',
      );

      expect(tab.id, 'ctx-fixed');
      expect(tab.title, 'ctx-a');
      final data = tab.workspaceState as DockerTabData;
      expect(data.kind.name, 'contextResources');
    });

    test('buildHostDashboardTab creates host overview tabs', () {
      final tab = helper.buildHostDashboardTab(
        host: const SshHost(
          name: 'alpha',
          hostname: 'alpha.example',
          port: 22,
          available: true,
        ),
        target: DockerDashboardTarget.overview,
        icon: Icons.cloud_outlined,
        shellCallbacks: shellCallbacks,
        tabBuilder: tabBuilder,
        onOpenTab: openedTabs.add,
        onCloseTab: closedTabs.add,
        id: 'host-fixed',
      );

      expect(tab.id, 'host-fixed');
      expect(tab.title, 'alpha');
      final data = tab.workspaceState as DockerTabData;
      expect(data.kind.name, 'hostOverview');
    });
  });
}

class _FakeDockerClientService extends Fake implements DockerClientService {}

class _MemoryCacheStorage extends CacheStorage {
  final Map<String, Map<String, String>> _stringMaps = {};

  @override
  Future<Map<String, String>> readStringMap(String key) async {
    return Map<String, String>.from(_stringMaps[key] ?? const {});
  }

  @override
  Future<void> writeStringMap(String key, Map<String, String> value) async {
    _stringMaps[key] = Map<String, String>.from(value);
  }
}
