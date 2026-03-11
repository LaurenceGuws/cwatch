import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/features/docker/services/docker_cli_parsers.dart';

void main() {
  group('DockerCliParsers', () {
    const parsers = DockerCliParsers();

    test('parses contexts and skips malformed lines', () {
      final contexts = parsers.parseContexts('''
{"Name":"default","DockerEndpoint":"unix:///var/run/docker.sock","Current":"*"}
not-json
{"Name":"remote","DockerEndpoint":"ssh://docker@example","Orchestrator":"swarm"}
''');

      expect(contexts, hasLength(2));
      expect(contexts[0].name, 'default');
      expect(contexts[0].current, isTrue);
      expect(contexts[1].name, 'remote');
      expect(contexts[1].orchestrator, 'swarm');
    });

    test('parses containers with compose labels and startedAt', () {
      final containers = parsers.parseContainers('''
{"ID":"abc","Names":"web","Image":"nginx","State":"running","Status":"Up","Ports":"80/tcp","Labels":"com.docker.compose.project=shop,com.docker.compose.service=web","StartedAt":"2026-03-10T10:11:12Z"}
''');

      expect(containers.single.composeProject, 'shop');
      expect(containers.single.composeService, 'web');
      expect(containers.single.startedAt, DateTime.parse('2026-03-10T10:11:12Z'));
    });

    test('parses images, networks, volumes, and stats', () {
      final images = parsers.parseImages(
        '{"ID":"img","Repository":"repo","Tag":"latest","Size":"10MB"}',
      );
      final networks = parsers.parseNetworks(
        '{"ID":"net","Name":"bridge","Driver":"bridge","Scope":"local"}',
      );
      final volumes = parsers.parseVolumes(
        '{"Name":"vol","Driver":"local","Mountpoint":"/data","Scope":"local","Size":"2GB"}',
      );
      final stats = parsers.parseStats(
        '{"Container":"abc","Name":"web","CPUPerc":"10.2%","MemUsage":"20MiB","MemPerc":"1.0%","NetIO":"1kB / 2kB","BlockIO":"0B / 0B","PIDs":"5"}',
      );

      expect(images.single.repository, 'repo');
      expect(networks.single.name, 'bridge');
      expect(volumes.single.size, '2GB');
      expect(stats.single.cpu, '10.2%');
    });

    test('parses volume sizes from system df output', () {
      final sizes = parsers.parseVolumeSizes('''
{"Type":"Images","Name":"ignored","Size":"1GB"}
{"Type":"Volume","Name":"vol-a","Size":"4GB"}
{"Type":"Volume","Name":"vol-b","Size":"N/A"}
''');

      expect(sizes, {'vol-a': '4GB'});
    });

    test('parses memory sizes and docker dates', () {
      expect(parsers.parseMemoryBytes('1.5GiB'), 1610612736);
      expect(parsers.parseMemoryBytes('20MiB / 1GiB'), 20971520);
      expect(parsers.parseDockerDate('2026-03-10 10:11:12 +0000 UTC'),
          DateTime.parse('2026-03-10T10:11:12Z'));
    });
  });
}
