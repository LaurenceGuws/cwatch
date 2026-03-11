import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_storage_menu_helper.dart';

void main() {
  const helper = DockerOverviewStorageMenuHelper();
  const actionState = DockerOverviewActionState();

  group('DockerOverviewStorageMenuHelper', () {
    test('projectNetworkMenu falls back to selected networks', () {
      final first = DockerNetwork(
        id: 'a',
        name: 'alpha',
        driver: 'bridge',
        scope: 'local',
      );
      final second = DockerNetwork(
        id: 'b',
        name: 'beta',
        driver: 'bridge',
        scope: 'swarm',
      );

      final projection = helper.projectNetworkMenu(
        network: first,
        selectedRows: null,
        selectedKeys: {actionState.networkKey(second)},
        networks: [first, second],
        actionState: actionState,
      );

      expect(projection.title, 'alpha');
      expect(projection.copyValue, actionState.networkKey(first));
      expect(projection.copyLabel, 'Network ID');
    });

    test('projectVolumeMenu summarizes multi-selection', () {
      final first = DockerVolume(name: 'data', driver: 'local');
      final second = DockerVolume(name: 'cache', driver: 'local');

      final projection = helper.projectVolumeMenu(
        volume: first,
        selectedRows: [first, second],
        selectedKeys: const {},
        volumes: [first, second],
        actionState: actionState,
      );

      expect(projection.title, '2 volumes selected');
      expect(projection.details, {'Selected': '2'});
      expect(projection.copyValue, 'data\ncache');
      expect(projection.copyLabel, 'Volume names');
    });
  });
}
