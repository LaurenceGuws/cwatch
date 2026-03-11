import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';

class DockerOverviewActionState {
  const DockerOverviewActionState();

  List<DockerContainer> selectedContainersForAction({
    required DockerContainer fallback,
    required Set<String> selectedIds,
    required List<DockerContainer> containers,
  }) {
    if (selectedIds.isEmpty) {
      return [fallback];
    }
    final selected = containers
        .where((container) => selectedIds.contains(container.id))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  List<DockerImage> selectedImagesForAction({
    required DockerImage fallback,
    required Set<String> selectedKeys,
    required List<DockerImage> images,
  }) {
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = images
        .where((image) => selectedKeys.contains(imageKey(image)))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  List<DockerNetwork> selectedNetworksForAction({
    required DockerNetwork fallback,
    required Set<String> selectedKeys,
    required List<DockerNetwork> networks,
  }) {
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = networks
        .where((network) => selectedKeys.contains(networkKey(network)))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  List<DockerVolume> selectedVolumesForAction({
    required DockerVolume fallback,
    required Set<String> selectedKeys,
    required List<DockerVolume> volumes,
  }) {
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = volumes
        .where((volume) => selectedKeys.contains(volume.name))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  String networkKey(DockerNetwork network) {
    return network.id.isNotEmpty ? network.id : network.name;
  }

  String imageKey(DockerImage image) {
    final repo = image.repository.isNotEmpty ? image.repository : '<none>';
    final tag = image.tag.isNotEmpty ? image.tag : '<none>';
    return '$repo:$tag:${image.id}';
  }

  List<DockerContainer> applyRestartedContainer(
    List<DockerContainer> cached,
    DockerContainer target, {
    required DateTime? startedAt,
  }) {
    return cached.map((container) {
      if (container.id != target.id) {
        return container;
      }
      return DockerContainer(
        id: container.id,
        name: container.name,
        image: container.image,
        state: 'running',
        status: 'running',
        ports: container.ports,
        command: container.command,
        createdAt: container.createdAt,
        composeProject: container.composeProject,
        composeService: container.composeService,
        startedAt: startedAt ?? DateTime.now().toUtc(),
      );
    }).toList();
  }

  List<DockerContainer> applyStartedContainer(
    List<DockerContainer> cached,
    DockerContainer target, {
    required DateTime? startedAt,
  }) {
    return applyRestartedContainer(
      cached,
      target,
      startedAt: startedAt,
    );
  }

  List<DockerContainer> applyStoppedContainer(
    List<DockerContainer> cached,
    String containerId,
  ) {
    return cached.map((container) {
      if (container.id != containerId) {
        return container;
      }
      return DockerContainer(
        id: container.id,
        name: container.name,
        image: container.image,
        state: 'exited',
        status: 'stopped',
        ports: container.ports,
        command: container.command,
        createdAt: container.createdAt,
        composeProject: container.composeProject,
        composeService: container.composeService,
        startedAt: null,
      );
    }).toList();
  }

  List<DockerContainer> mergeProjectContainers({
    required List<DockerContainer> cached,
    required List<DockerContainer> fetched,
    required String project,
  }) {
    final updatedProject = fetched
        .where((container) => container.composeProject == project)
        .toList();
    final others = cached
        .where((container) => container.composeProject != project)
        .toList();
    return [...others, ...updatedProject];
  }
}
