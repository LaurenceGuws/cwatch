import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';

void main() {
  const state = DockerOverviewActionState();

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

  DockerImage image({
    required String id,
    required String repository,
    required String tag,
  }) {
    return DockerImage(
      id: id,
      repository: repository,
      tag: tag,
      size: '10 MB',
      createdSince: '1 day ago',
    );
  }

  group('DockerOverviewActionState', () {
    test('falls back to the tapped container when nothing is selected', () {
      final fallback = container(id: 'one');

      final selected = state.selectedContainersForAction(
        fallback: fallback,
        selectedIds: const {},
        containers: [fallback],
      );

      expect(selected, [fallback]);
    });

    test('returns selected images from current keys', () {
      final first = image(id: '1', repository: 'repo', tag: 'latest');
      final second = image(id: '2', repository: 'repo', tag: 'stable');

      final selected = state.selectedImagesForAction(
        fallback: first,
        selectedKeys: {state.imageKey(second)},
        images: [first, second],
      );

      expect(selected, [second]);
    });

    test('applies restarted container state', () {
      final original = container(
        id: 'one',
        stateValue: 'exited',
        status: 'stopped',
      );
      final startedAt = DateTime.utc(2026, 1, 1);

      final updated = state.applyRestartedContainer(
        [original],
        original,
        startedAt: startedAt,
      );

      expect(updated.single.state, 'running');
      expect(updated.single.status, 'running');
      expect(updated.single.startedAt, startedAt);
    });

    test('applies stopped container state', () {
      final running = container(id: 'one');

      final updated = state.applyStoppedContainer([running], 'one');

      expect(updated.single.state, 'exited');
      expect(updated.single.status, 'stopped');
      expect(updated.single.startedAt, isNull);
    });

    test('merges project containers while preserving other cached containers', () {
      final cached = [
        container(id: 'a', project: 'alpha'),
        container(id: 'b', project: 'beta'),
      ];
      final fetched = [
        container(id: 'a2', project: 'alpha'),
        container(id: 'b2', project: 'beta'),
      ];

      final merged = state.mergeProjectContainers(
        cached: cached,
        fetched: fetched,
        project: 'alpha',
      );

      expect(merged.map((item) => item.id).toList(), ['b', 'a2']);
    });

    test('uses id fallback for network keys', () {
      final network = DockerNetwork(
        id: '',
        name: 'bridge',
        driver: 'bridge',
        scope: 'local',
      );

      expect(state.networkKey(network), 'bridge');
    });

    test('returns selected volume by name', () {
      final first = DockerVolume(name: 'a', driver: 'local');
      final second = DockerVolume(name: 'b', driver: 'local');

      final selected = state.selectedVolumesForAction(
        fallback: first,
        selectedKeys: const {'b'},
        volumes: [first, second],
      );

      expect(selected, [second]);
    });
  });
}
