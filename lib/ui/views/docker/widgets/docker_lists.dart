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

class ContainerPeek extends StatefulWidget {
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
  State<ContainerPeek> createState() => _ContainerPeekState();
}

class _ContainerPeekState extends State<ContainerPeek> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    final groups = _group(widget.containers);
    return Column(
      children: groups.entries.map((entry) {
        final project = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(project);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                dense: true,
                title: Text(project),
                subtitle: Text('${items.length} containers'),
                trailing: Icon(collapsed
                    ? Icons.keyboard_arrow_right
                    : Icons.keyboard_arrow_down),
                onTap: () {
                  setState(() {
                    if (collapsed) {
                      _collapsed.remove(project);
                    } else {
                      _collapsed.add(project);
                    }
                  });
                },
              ),
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: items
                        .map(
                          (container) => _ContainerRow(
                            container: container,
                            onTap: widget.onTap,
                            onTapDown: widget.onTapDown,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<DockerContainer>> _group(
    List<DockerContainer> containers,
  ) {
    final map = <String, List<DockerContainer>>{};
    for (final c in containers) {
      final key = c.composeProject?.isNotEmpty == true
          ? 'Compose: ${c.composeProject}'
          : _inferComposeGroup(c.name);
      map.putIfAbsent(key, () => []).add(c);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Standalone') return 1;
        if (b == 'Standalone') return -1;
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: map[k]!};
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
    final groups = _group(containers);
    return Column(
      children: groups.entries.map((entry) {
        final project = entry.key;
        final items = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(project),
            subtitle: Text('${items.length} containers'),
            children: items
                .map(
                  (container) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _ContainerRow(
                      container: container,
                      onTap: onTap,
                      onTapDown: onTapDown,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<DockerContainer>> _group(List<DockerContainer> containers) {
    final map = <String, List<DockerContainer>>{};
    for (final c in containers) {
      final key = c.composeProject?.isNotEmpty == true
          ? 'Compose: ${c.composeProject}'
          : _inferComposeGroup(c.name);
      map.putIfAbsent(key, () => []).add(c);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Standalone') return 1;
        if (b == 'Standalone') return -1;
        return a.compareTo(b);
      });
    return {for (final k in sortedKeys) k: map[k]!};
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
    final groups = _groupImages(images);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final repo = entry.key;
        final items = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(repo),
            subtitle: Text('${items.length} images'),
            children: items.map((image) {
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<DockerImage>> _groupImages(List<DockerImage> images) {
    final map = <String, List<DockerImage>>{};
    for (final img in images) {
      final key = img.repository.isNotEmpty ? img.repository : '<none>';
      map.putIfAbsent(key, () => []).add(img);
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k: map[k]!};
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
    final groups = _groupByComposeish(networks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final group = entry.key;
        final items = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(group),
            subtitle: Text('${items.length} networks'),
            children: items
                .map(
                  (network) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: GestureDetector(
                      onTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(network, d),
                      onSecondaryTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(network, d),
                      child: InkWell(
                        onTap: onTap == null ? null : () => onTap!(network),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Expanded(child: Text(network.name)),
                            Text(network.driver,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<DockerNetwork>> _groupByComposeish(
    List<DockerNetwork> networks,
  ) {
    final map = <String, List<DockerNetwork>>{};
    for (final net in networks) {
      final inferred = _inferComposeGroup(net.name);
      map.putIfAbsent(inferred, () => []).add(net);
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k: map[k]!};
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
    final groups = _groupByComposeish(volumes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final group = entry.key;
        final items = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(group),
            subtitle: Text('${items.length} volumes'),
            children: items
                .map(
                  (volume) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: GestureDetector(
                      onTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(volume, d),
                      onSecondaryTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(volume, d),
                      child: InkWell(
                        onTap: onTap == null ? null : () => onTap!(volume),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Expanded(child: Text(volume.name)),
                            Text(volume.driver,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Map<String, List<DockerVolume>> _groupByComposeish(
    List<DockerVolume> volumes,
  ) {
    final map = <String, List<DockerVolume>>{};
    for (final vol in volumes) {
      final inferred = _inferComposeGroup(vol.name);
      map.putIfAbsent(inferred, () => []).add(vol);
    }
    final keys = map.keys.toList()..sort();
    return {for (final k in keys) k: map[k]!};
  }
}
class _ContainerRow extends StatelessWidget {
  const _ContainerRow({
    required this.container,
    this.onTap,
    this.onTapDown,
  });

  final DockerContainer container;
  final ValueChanged<DockerContainer>? onTap;
  final void Function(DockerContainer, TapDownDetails)? onTapDown;

  @override
  Widget build(BuildContext context) {
    final color = container.isRunning ? Colors.green : Colors.orange;
    final statusLabel =
        container.isRunning ? 'Running' : 'Stopped (${container.status})';
    return GestureDetector(
      onTapDown: onTapDown == null ? null : (d) => onTapDown!(container, d),
      onSecondaryTapDown:
          onTapDown == null ? null : (d) => onTapDown!(container, d),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(container),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.dns, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    container.name.isNotEmpty ? container.name : container.id,
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
    );
  }
}

String _inferComposeGroup(String name) {
  final cleaned = name.trim();
  if (cleaned.contains('_')) {
    final project = cleaned.split('_').first;
    if (project.isNotEmpty) return 'Compose: $project';
  }
  if (cleaned.contains('-')) {
    final parts = cleaned.split('-');
    if (parts.length > 1) {
      const commonSuffixes = {
        'default',
        'app',
        'web',
        'db',
        'backend',
        'frontend',
        'api',
        'service',
        'svc',
        'worker',
        'cache',
        'data',
      };
      if (commonSuffixes.contains(parts.last.toLowerCase()) ||
          parts.length > 2) {
        final project = parts.first;
        if (project.isNotEmpty) return 'Compose: $project';
      }
    }
  }
  return 'Standalone';
}
