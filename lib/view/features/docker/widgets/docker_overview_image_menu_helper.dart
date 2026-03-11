import 'package:cwatch/model/models/docker_image.dart';

class DockerOverviewImageMenuHelper {
  const DockerOverviewImageMenuHelper();

  String imageReference(DockerImage image) {
    return [
      image.repository.isNotEmpty ? image.repository : '<none>',
      image.tag.isNotEmpty ? image.tag : '<none>',
    ].join(':');
  }

  Future<void> handleAction({
    required String action,
    required List<DockerImage> selection,
    required Future<String?> Function(String initialValue) promptTag,
    required Future<String?> Function() promptPull,
    required Future<void> Function(String imageName) pullImage,
    required Future<void> Function({
      required String sourceImage,
      required String targetImage,
      required String? sourceImageId,
    })
    tagImage,
    required Future<void> Function(String imageName, {String? imageId}) pushImage,
    required Future<void> Function(String imageId) inspectImage,
    required Future<void> Function(String imageId) showImageHistory,
    required Future<void> Function(List<String> imageIds) removeImages,
  }) async {
    switch (action) {
      case 'pull':
        final imageName = await promptPull();
        if (imageName != null && imageName.isNotEmpty) {
          await pullImage(imageName);
        }
        break;
      case 'tag':
        final imageRef = imageReference(selection.first);
        final newTag = await promptTag(imageRef);
        if (newTag != null && newTag.isNotEmpty) {
          await tagImage(
            sourceImage: imageRef,
            targetImage: newTag,
            sourceImageId: selection.first.id,
          );
        }
        break;
      case 'push':
        await pushImage(
          imageReference(selection.first),
          imageId: selection.first.id,
        );
        break;
      case 'inspect':
        await inspectImage(selection.first.id);
        break;
      case 'history':
        await showImageHistory(selection.first.id);
        break;
      case 'remove':
        await removeImages(selection.map((img) => img.id).toList());
        break;
    }
  }
}
