import 'package:flutter/material.dart';

import '../../../../models/docker_container.dart';
import '../../../../models/docker_image.dart';
import '../../../../models/docker_network.dart';
import '../../../../models/docker_volume.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 140,
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}

class ContainerPeek extends StatelessWidget {
  const ContainerPeek({
    super.key,
    required this.containers,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final void Function(DockerContainer, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    return Column(
      children: containers.map((container) {
        final color = container.isRunning ? Colors.green : Colors.orange;
        final statusLabel =
            container.isRunning ? 'Running' : 'Stopped (${container.status})';
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(container, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(container, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(container),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.dns, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          container.name.isNotEmpty
                              ? container.name
                              : container.id,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Image: ${container.image}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          statusLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ContainerList extends StatelessWidget {
  const ContainerList({
    super.key,
    required this.containers,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final void Function(DockerContainer, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    return Column(
      children: containers.map((container) {
        final color = container.isRunning ? Colors.green : Colors.orange;
        final statusLabel =
            container.isRunning ? 'Running' : 'Stopped (${container.status})';
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(container, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(container, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(container),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.dns, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          container.name.isNotEmpty
                              ? container.name
                              : container.id,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          'Image: ${container.image}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          statusLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ImagePeek extends StatelessWidget {
  const ImagePeek({
    super.key,
    required this.images,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final void Function(DockerImage, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const EmptyCard(message: 'No images found.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: images.map((image) {
        final name = [
          image.repository.isNotEmpty ? image.repository : '<none>',
          image.tag.isNotEmpty ? image.tag : '<none>',
        ].join(':');
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(image, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(image, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(image),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.image, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Size: ${image.size}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ImageList extends StatelessWidget {
  const ImageList({
    super.key,
    required this.images,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final void Function(DockerImage, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const EmptyCard(message: 'No images found.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: images.map((image) {
        final name = [
          image.repository.isNotEmpty ? image.repository : '<none>',
          image.tag.isNotEmpty ? image.tag : '<none>',
        ].join(':');
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(image, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(image, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(image),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  Text('Size: ${image.size}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class NetworkList extends StatelessWidget {
  const NetworkList({
    super.key,
    required this.networks,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerNetwork> networks;
  final ValueChanged<DockerNetwork>? onTap;
  final void Function(DockerNetwork, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) {
      return const EmptyCard(message: 'No networks found.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: networks.map((network) {
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(network, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(network, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(network),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(network.name)),
                  Text(network.driver,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class VolumeList extends StatelessWidget {
  const VolumeList({
    super.key,
    required this.volumes,
    this.onTap,
    this.onTapDown,
  });

  final List<DockerVolume> volumes;
  final ValueChanged<DockerVolume>? onTap;
  final void Function(DockerVolume, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    if (volumes.isEmpty) {
      return const EmptyCard(message: 'No volumes found.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: volumes.map((volume) {
        return GestureDetector(
          onTapDown:
              onTapDown == null ? null : (d) => onTapDown!(volume, d),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(volume, d),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(volume),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(volume.name)),
                  Text(volume.driver,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
