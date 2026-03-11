import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_container_stat.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/view/features/docker/widgets/docker_container_peek_state_controller.dart';

class _FakeDockerClientService extends DockerClientService {
  _FakeDockerClientService(this._stats) : super();

  final List<DockerContainerStat> _stats;
  int calls = 0;

  @override
  Future<List<DockerContainerStat>> listContainerStats({
    String? context,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    calls++;
    return _stats;
  }
}

void main() {
  group('DockerContainerPeekStateController', () {
    test('groups compose projects before standalone and sorts by name', () {
      final controller = DockerContainerPeekStateController();
      final grouped = controller.groupContainers([
        DockerContainer(id: '3', name: 'c', image: 'img', state: 'running', status: 'Up', ports: '', composeProject: null),
        DockerContainer(id: '1', name: 'a', image: 'img', state: 'running', status: 'Up', ports: '', composeProject: 'beta'),
        DockerContainer(id: '2', name: 'b', image: 'img', state: 'running', status: 'Up', ports: '', composeProject: 'alpha'),
      ]);

      expect(grouped.keys.toList(), ['Compose: alpha', 'Compose: beta', 'Standalone']);
    });

    test('runningLabel formats elapsed uptime from startedAt', () {
      final now = DateTime(2026, 3, 11, 12, 0, 0);
      final controller = DockerContainerPeekStateController(now: () => now);
      final container = DockerContainer(
        id: '1',
        name: 'web',
        image: 'nginx',
        state: 'running',
        status: 'Up',
        ports: '',
        startedAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      );

      expect(controller.runningLabel(container), 'Running for 2h 15m');
    });

    test('fetchAllStats caches results and resolves by id or name', () async {
      final fake = _FakeDockerClientService([
        DockerContainerStat(
          id: 'abc',
          name: 'web',
          cpu: '12.5%',
          memUsage: '10MiB / 100MiB',
          memPercent: '23.0%',
          netIO: '1kB / 2kB',
          blockIO: '0B / 0B',
          pids: '5',
        ),
      ]);
      final controller = DockerContainerPeekStateController();

      final first = await controller.fetchAllStats(dockerService: fake);
      final second = await controller.fetchAllStats(dockerService: fake);

      expect(fake.calls, 1);
      final byId = controller.getContainerStats(
        first,
        DockerContainer(id: 'abc', name: 'other', image: 'img', state: 'running', status: 'Up', ports: ''),
      );
      final byName = controller.getContainerStats(
        second,
        DockerContainer(id: 'missing', name: 'web', image: 'img', state: 'running', status: 'Up', ports: ''),
      );
      expect(byId['cpu'], 12.5);
      expect(byName['ram'], 23.0);
    });
  });
}
