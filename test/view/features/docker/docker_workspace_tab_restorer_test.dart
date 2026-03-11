import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/core/models/tab_state.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/view/features/docker/docker_tab_builder.dart';
import 'package:cwatch/view/features/docker/docker_workspace_tab_restorer.dart';

void main() {
  group('DockerWorkspaceTabRestorer', () {
    late DockerWorkspaceTabRestorer restorer;
    late DockerTabBuilder builder;
    late _FakeRemoteShellService shellService;
    late List<String> closedTabs;
    late List<WorkspaceTab> openedTabs;

    setUp(() {
      restorer = const DockerWorkspaceTabRestorer();
      shellService = _FakeRemoteShellService();
      closedTabs = [];
      openedTabs = [];
      builder = DockerTabBuilder(
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
    });

    test('restores command tabs with sanitized persisted commands', () {
      final tab = restorer.buildTab(
        state: const TabState(
          id: 'cmd-1',
          kind: 'command',
          title: 'Shell',
          label: 'Shell',
          hostName: 'alpha',
          command: 'top; exit',
          extra: {
            'containerId': 'container-1',
            'containerName': 'web',
          },
        ),
        hosts: const [
          SshHost(
            name: 'alpha',
            hostname: 'alpha.example',
            port: 22,
            available: true,
          ),
        ],
        builder: builder,
        pickerBuilder: (_) => const SizedBox.shrink(),
        callbacks: _callbacks(
          shellService: shellService,
          closedTabs: closedTabs,
          openedTabs: openedTabs,
        ),
      );

      expect(tab, isNotNull);
      final state = (tab!.workspaceState as DockerTabData).persistedState;
      expect(state.command, 'top');
      expect(state.stringExtra('containerId'), 'container-1');
      expect(state.stringExtra('containerName'), 'web');
    });

    test('restores local container explorer tabs with local-host fallback', () {
      final tab = restorer.buildTab(
        state: const TabState(
          id: 'explorer-1',
          kind: 'containerExplorer',
          title: 'Explore web',
          label: 'Explorer',
          contextName: 'ctx-a',
          path: '/srv/app',
          extra: {
            'containerId': 'container-1',
            'containerName': 'web',
          },
        ),
        hosts: const [],
        builder: builder,
        pickerBuilder: (_) => const SizedBox.shrink(),
        callbacks: _callbacks(
          shellService: shellService,
          closedTabs: closedTabs,
          openedTabs: openedTabs,
        ),
      );

      expect(tab, isNotNull);
      final state = (tab!.workspaceState as DockerTabData).persistedState;
      expect(state.hostName, 'local');
      expect(state.contextName, 'ctx-a');
      expect(state.path, '/srv/app');
      expect(state.stringExtra('containerId'), 'container-1');
    });

    test('returns null when restoring host dashboards for unknown hosts', () {
      final tab = restorer.buildTab(
        state: const TabState(
          id: 'host-overview-1',
          kind: 'hostOverview',
          title: 'Missing host',
          label: 'Missing host',
          hostName: 'missing',
        ),
        hosts: const [],
        builder: builder,
        pickerBuilder: (_) => const SizedBox.shrink(),
        callbacks: _callbacks(
          shellService: shellService,
          closedTabs: closedTabs,
          openedTabs: openedTabs,
        ),
      );

      expect(tab, isNull);
    });
  });
}

TabBuilders _callbacks({
  required RemoteShellService shellService,
  required List<String> closedTabs,
  required List<WorkspaceTab> openedTabs,
}) {
  return TabBuilders(
    cloudIcon: Icons.cloud,
    cloudOutlineIcon: Icons.cloud_outlined,
    commandIcon: Icons.terminal,
    composeIcon: Icons.receipt_long,
    explorerIcon: Icons.folder_open,
    editorIcon: Icons.edit,
    shellForHost: (_) => shellService,
    containerShell: (_, containerId, {String? contextName}) => shellService,
    dockerContextNameFor: (host, contextName) => contextName ?? '${host.name}-docker',
    closeTab: closedTabs.add,
    onOpenTab: openedTabs.add,
  );
}

class _FakeDockerClientService extends Fake implements DockerClientService {}

class _FakeRemoteShellService extends Fake implements RemoteShellService {}

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
