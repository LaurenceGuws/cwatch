import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/docker_overview_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/features/docker/services/container_distro_manager.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_runtime_state.dart';

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

class _FakeDockerClientService extends DockerClientService {
  _FakeDockerClientService({
    this.inspectStartTime,
  }) : super(
         processRunner:
             (
               executable,
               arguments, {
               workingDirectory,
               environment,
               runInShell = false,
               stdoutEncoding,
               stderrEncoding,
             }) async => ProcessResult(0, 0, '', ''),
       );

  Future<DateTime?> Function({required String id, String? context})?
  inspectStartTime;

  @override
  Future<DateTime?> inspectContainerStartTime({
    required String id,
    String? context,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return inspectStartTime?.call(id: id, context: context);
  }
}

class _FakeDockerOverviewController extends DockerOverviewController {
  _FakeDockerOverviewController({
    required super.docker,
  });

  List<DockerContainer> fetchContainersResult = const [];
  Object? fetchContainersError;

  @override
  Future<List<DockerContainer>> fetchContainers() async {
    final error = fetchContainersError;
    if (error != null) {
      throw error;
    }
    return fetchContainersResult;
  }
}

void main() {
  DockerContainer container({
    required String id,
    String name = 'c',
    String image = 'img',
    String stateValue = 'running',
    String status = 'running',
    String? project,
    DateTime? startedAt,
  }) {
    return DockerContainer(
      id: id,
      name: name,
      image: image,
      state: stateValue,
      status: status,
      ports: '80/tcp',
      command: 'run',
      createdAt: '1h ago',
      composeProject: project,
      composeService: project == null ? null : 'svc',
      startedAt: startedAt,
    );
  }

  DockerOverviewRuntimeState runtime({
    required _FakeDockerOverviewController controller,
    required DockerOverviewUiAdapter uiAdapter,
  }) {
    return DockerOverviewRuntimeState(
      controller: controller,
      containerDistroManager: ContainerDistroManager(
        distroCacheController: DistroCacheController(
          storage: _MemoryCacheStorage(),
        ),
        docker: controller.docker,
      ),
      actionState: const DockerOverviewActionState(),
      uiAdapter: uiAdapter,
    );
  }

  Future<DockerOverviewUiAdapter> buildUiAdapter(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return DockerOverviewUiAdapter(context: context);
  }

  group('DockerOverviewRuntimeState', () {
    testWidgets('updates restarted container from inspected start time', (
      tester,
    ) async {
      final startedAt = DateTime.utc(2026, 2, 1);
      final docker = _FakeDockerClientService(
        inspectStartTime: ({required id, context}) async => startedAt,
      );
      final controller = _FakeDockerOverviewController(docker: docker)
        ..cachedContainers = [
          container(id: 'one', stateValue: 'exited', status: 'stopped'),
        ];
      final uiAdapter = await buildUiAdapter(tester);

      await runtime(
        controller: controller,
        uiAdapter: uiAdapter,
      ).updateContainerAfterRestart(
        controller.cachedContainers.single,
      );

      expect(controller.cachedContainers.single.state, 'running');
      expect(controller.cachedContainers.single.startedAt, startedAt);
    });

    testWidgets('marks container stopped in cached state', (tester) async {
      final controller =
          _FakeDockerOverviewController(docker: _FakeDockerClientService())
            ..cachedContainers = [container(id: 'one')];
      final uiAdapter = await buildUiAdapter(tester);

      runtime(
        controller: controller,
        uiAdapter: uiAdapter,
      ).markContainerStopped('one');

      expect(controller.cachedContainers.single.state, 'exited');
      expect(controller.cachedContainers.single.startedAt, isNull);
    });

    testWidgets('syncs compose project containers and preserves others', (
      tester,
    ) async {
      final controller =
          _FakeDockerOverviewController(docker: _FakeDockerClientService())
            ..cachedContainers = [
              container(id: 'a', project: 'alpha'),
              container(id: 'b', project: 'beta'),
            ]
            ..fetchContainersResult = [
              container(id: 'a2', project: 'alpha'),
              container(id: 'b2', project: 'beta'),
            ];
      final uiAdapter = await buildUiAdapter(tester);

      await runtime(
        controller: controller,
        uiAdapter: uiAdapter,
      ).syncProjectContainers('alpha');

      expect(
        controller.cachedContainers.map((item) => item.id).toList(),
        ['b', 'a2'],
      );
    });
  });
}
