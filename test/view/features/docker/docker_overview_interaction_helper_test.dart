import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_interaction_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const helper = DockerOverviewInteractionHelper();

  DockerContainer container(String id) => DockerContainer(
    id: id,
    name: id,
    image: 'img',
    state: 'running',
    status: 'running',
    ports: '80/tcp',
    command: 'run',
    createdAt: '1h ago',
  );

  group('DockerOverviewInteractionHelper', () {
    test('container secondary tap selects tapped row when not already selected', () {
      final controller = _FakeDockerOverviewController();
      final items = [container('a'), container('b')];

      helper.handleContainerSecondaryTap(
        container: items[1],
        controller: controller,
        containers: items,
      );

      expect(controller.selectedContainerIds, {'b'});
      expect(controller.focusedContainerIndex, 1);
    });

    test('image and network secondary taps select keyed rows', () {
      final controller = _FakeDockerOverviewController();
      const actionState = DockerOverviewActionState();
      final image = DockerImage(
        id: 'img-1',
        repository: 'repo',
        tag: 'latest',
        size: '10 MB',
        createdSince: '1d',
      );
      final network = DockerNetwork(
        id: 'net-1',
        name: 'bridge',
        driver: 'bridge',
        scope: 'local',
      );

      helper.handleImageSecondaryTap(
        image: image,
        controller: controller,
        actionState: actionState,
      );
      helper.handleNetworkSecondaryTap(
        network: network,
        controller: controller,
        actionState: actionState,
      );

      expect(controller.selectedImageKeys, {actionState.imageKey(image)});
      expect(controller.selectedNetworkKeys, {actionState.networkKey(network)});
    });

    test('volume secondary tap selects volume name', () {
      final controller = _FakeDockerOverviewController();
      final volume = DockerVolume(name: 'data', driver: 'local');

      helper.handleVolumeSecondaryTap(
        volume: volume,
        controller: controller,
      );

      expect(controller.selectedVolumeKeys, {'data'});
    });

    test('compose action routes logs and lifecycle commands', () async {
      final calls = <String>[];

      await helper.handleComposeAction(
        project: 'alpha',
        action: 'logs',
        openLogs: (project) async => calls.add('logs:$project'),
        runCommand: (project, action) async => calls.add('$action:$project'),
      );
      await helper.handleComposeAction(
        project: 'alpha',
        action: 'restart',
        openLogs: (project) async => calls.add('logs:$project'),
        runCommand: (project, action) async => calls.add('$action:$project'),
      );

      expect(calls, ['logs:alpha', 'restart:alpha']);
    });

    test('tab surface pointer down clears active tab selection', () {
      final controller = _FakeDockerOverviewController()
        ..selectedImageKeys.add('repo:latest');

      helper.handleTabSurfacePointerDown(
        tabIndex: 2,
        event: const PointerDownEvent(buttons: kPrimaryButton),
        controller: controller,
      );

      expect(controller.selectedImageKeys, isEmpty);
    });
  });
}

class _FakeDockerOverviewController extends DockerOverviewController {
  _FakeDockerOverviewController()
    : super(docker: _FakeDockerClientService());
}

class _FakeDockerClientService extends Fake implements DockerClientService {}
