import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/models/docker_container.dart';

void main() {
  group('DockerOverviewController', () {
    test('selectSingleContainer replaces selection and updates focus state', () {
      final controller = DockerOverviewController(docker: _FakeDockerClientService());
      controller.cachedContainers = const [
        DockerContainer(
          id: 'alpha',
          name: 'alpha',
          image: 'img',
          state: 'running',
          status: 'Up',
          ports: '',
          command: '',
          createdAt: '',
        ),
        DockerContainer(
          id: 'beta',
          name: 'beta',
          image: 'img',
          state: 'running',
          status: 'Up',
          ports: '',
          command: '',
          createdAt: '',
        ),
      ];
      controller.selectedContainerIds.add('alpha');

      controller.selectSingleContainer('beta', index: 1);

      expect(controller.selectedContainerIds, {'beta'});
      expect(controller.focusedContainerIndex, 1);
      expect(controller.containerAnchorIndex, 1);
    });



    test('clearContainerSelection clears ids and focus state', () {
      final controller = DockerOverviewController(docker: _FakeDockerClientService());
      controller.selectedContainerIds.addAll({'alpha', 'beta'});
      controller.focusedContainerIndex = 1;
      controller.containerAnchorIndex = 0;

      controller.clearContainerSelection();

      expect(controller.selectedContainerIds, isEmpty);
      expect(controller.focusedContainerIndex, isNull);
      expect(controller.containerAnchorIndex, isNull);
    });

    test('clearSelection clears keyed selection sets', () {
      final controller = DockerOverviewController(docker: _FakeDockerClientService());
      controller.selectedNetworkKeys.addAll({'n1', 'n2'});

      controller.clearSelection(controller.selectedNetworkKeys);

      expect(controller.selectedNetworkKeys, isEmpty);
    });

    test('selectSingleKey replaces selection for simple keyed sets', () {
      final controller = DockerOverviewController(docker: _FakeDockerClientService());
      controller.selectedImageKeys.addAll({'repo:a', 'repo:b'});

      controller.selectSingleKey(controller.selectedImageKeys, 'repo:c');

      expect(controller.selectedImageKeys, {'repo:c'});
    });
  });
}

class _FakeDockerClientService extends Fake implements DockerClientService {}
