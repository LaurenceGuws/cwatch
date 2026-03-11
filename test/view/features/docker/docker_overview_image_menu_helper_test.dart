import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_image_menu_helper.dart';

void main() {
  const helper = DockerOverviewImageMenuHelper();

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

  group('DockerOverviewImageMenuHelper', () {
    test('imageReference falls back to <none> parts', () {
      expect(
        helper.imageReference(
          image(id: '1', repository: '', tag: ''),
        ),
        '<none>:<none>',
      );
    });

    test('tag action prompts and tags selected image', () async {
      final calls = <String>[];
      final selection = [image(id: '1', repository: 'repo', tag: 'latest')];

      await helper.handleAction(
        action: 'tag',
        selection: selection,
        promptTag: (initialValue) async {
          calls.add('prompt:$initialValue');
          return 'repo:v2';
        },
        promptPull: () async => null,
        pullImage: (imageName) async => calls.add('pull:$imageName'),
        tagImage: ({
          required sourceImage,
          required targetImage,
          required sourceImageId,
        }) async => calls.add('tag:$sourceImage->$targetImage:$sourceImageId'),
        pushImage: (imageName, {imageId}) async =>
            calls.add('push:$imageName:$imageId'),
        inspectImage: (imageId) async => calls.add('inspect:$imageId'),
        showImageHistory: (imageId) async => calls.add('history:$imageId'),
        removeImages: (imageIds) async => calls.add('remove:${imageIds.join(",")}'),
      );

      expect(calls, ['prompt:repo:latest', 'tag:repo:latest->repo:v2:1']);
    });

    test('remove action removes all selected image ids', () async {
      final removed = <List<String>>[];
      final selection = [
        image(id: '1', repository: 'repo', tag: 'latest'),
        image(id: '2', repository: 'repo', tag: 'stable'),
      ];

      await helper.handleAction(
        action: 'remove',
        selection: selection,
        promptTag: (initialValue) async => null,
        promptPull: () async => null,
        pullImage: (imageName) async {},
        tagImage: ({
          required sourceImage,
          required targetImage,
          required sourceImageId,
        }) async {},
        pushImage: (imageName, {imageId}) async {},
        inspectImage: (imageId) async {},
        showImageHistory: (imageId) async {},
        removeImages: (imageIds) async => removed.add(imageIds),
      );

      expect(removed, [
        ['1', '2'],
      ]);
    });
  });
}
