import 'package:flutter/material.dart';

import '../../../../models/docker_container.dart';
import '../../../../models/docker_image.dart';
import '../../../../models/docker_network.dart';
import '../../../../models/docker_volume.dart';
import '../../../theme/app_theme.dart';

typedef ItemTapDown<T> = void Function(
  T item,
  TapDownDetails details, {
  bool secondary,
  int? flatIndex,
});

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
    required this.selectedIds,
    required this.busyIds,
    required this.actionLabels,
    this.onComposeAction,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final ItemTapDown<DockerContainer>? onTapDown;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;
  final void Function(String project, String action)? onComposeAction;

  @override
  State<ContainerPeek> createState() => _ContainerPeekState();
}

class _ContainerPeekState extends State<ContainerPeek> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (widget.containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    final groups = _group(widget.containers);
    var flatIndex = 0;
    return Column(
      children: groups.entries.map((entry) {
        final project = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(project);
        final isCompose = project.startsWith('Compose: ');
        final projectName =
            isCompose ? project.replaceFirst('Compose: ', '') : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              ListTile(
                dense: true,
                title: Text(project),
                subtitle: Text('${items.length} containers'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCompose && widget.onComposeAction != null)
                      PopupMenuButton<String>(
                        tooltip: 'Compose actions',
                        icon: Icon(icons.settings),
                        onSelected: (action) {
                          final name = projectName;
                          if (name != null) {
                            widget.onComposeAction!(name, action);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'logs', child: Text('Tail logs')),
                          PopupMenuItem(
                            value: 'restart',
                            child: Text('Restart project'),
                          ),
                          PopupMenuItem(
                            value: 'up',
                            child: Text('Compose up (detach)'),
                          ),
                          PopupMenuItem(
                            value: 'down',
                            child: Text('Compose down'),
                          ),
                        ],
                      ),
                    Icon(
                      collapsed ? icons.arrowRight : icons.arrowDown,
                    ),
                  ],
                ),
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
                        .map((container) {
                          final row = _ContainerRow(
                            container: container,
                            onTap: widget.onTap,
                            onTapDown: widget.onTapDown,
                            selected: widget.selectedIds.contains(container.id),
                            busy: widget.busyIds.contains(container.id),
                            progressLabel: widget.actionLabels[container.id],
                            flatIndex: flatIndex,
                          );
                          flatIndex += 1;
                          return row;
                        })
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
          : 'Standalone';
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
    required this.selectedIds,
    required this.busyIds,
    required this.actionLabels,
    this.onComposeAction,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final ItemTapDown<DockerContainer>? onTapDown;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;
  final void Function(String project, String action)? onComposeAction;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    final groups = _group(containers);
    return Column(
      children: groups.entries.map((entry) {
        final project = entry.key;
        final items = entry.value;
        final isCompose = project.startsWith('Compose: ');
        final projectName =
            isCompose ? project.replaceFirst('Compose: ', '') : null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(project),
            subtitle: Text('${items.length} containers'),
            trailing: isCompose && onComposeAction != null
                ? PopupMenuButton<String>(
                    tooltip: 'Compose actions',
                    icon: Icon(icons.settings),
                    onSelected: (action) {
                      final name = projectName;
                      if (name != null) {
                        onComposeAction!(name, action);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'logs', child: Text('Tail logs')),
                      PopupMenuItem(
                        value: 'restart',
                        child: Text('Restart project'),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        child: Text('Compose up (detach)'),
                      ),
                      PopupMenuItem(value: 'down', child: Text('Compose down')),
                    ],
                  )
                : null,
            children: items
                .map(
                  (container) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _ContainerRow(
                      container: container,
                      onTap: onTap,
                      onTapDown: onTapDown,
                      selected: selectedIds.contains(container.id),
                      busy: busyIds.contains(container.id),
                      progressLabel: actionLabels[container.id],
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
          : 'Standalone';
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

class ComposeProjectList extends StatelessWidget {
  const ComposeProjectList({
    super.key,
    required this.projects,
    required this.onComposeAction,
  });

  final Map<String, List<DockerContainer>> projects;
  final void Function(String project, String action) onComposeAction;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return const SizedBox.shrink();
    return const SizedBox.shrink();
  }
}

class ImagePeek extends StatelessWidget {
  const ImagePeek({
    super.key,
    required this.images,
    this.onTap,
    this.onTapDown,
    required this.selectedIds,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final ItemTapDown<DockerImage>? onTapDown;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
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
              final isSelected = selectedIds.contains(_imageKey(image));
              return GestureDetector(
                onTapDown: onTapDown == null
                    ? null
                    : (d) => onTapDown!(image, d, secondary: false),
                onSecondaryTapDown: onTapDown == null
                    ? null
                    : (d) => onTapDown!(image, d, secondary: true),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Container(
                    decoration: isSelected
                        ? BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(icons.image,
                            size: 18, color: Theme.of(context).iconTheme.color),
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
    required this.selectedIds,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final ItemTapDown<DockerImage>? onTapDown;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
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
        final isSelected = selectedIds.contains(_imageKey(image));
        return GestureDetector(
          onTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(image, d, secondary: false),
          onSecondaryTapDown: onTapDown == null
              ? null
              : (d) => onTapDown!(image, d, secondary: true),
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(image),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                decoration: isSelected
                    ? BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icons.image,
                            size: 18, color: Theme.of(context).iconTheme.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text('Size: ${image.size}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
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
    required this.selectedIds,
  });

  final List<DockerNetwork> networks;
  final ValueChanged<DockerNetwork>? onTap;
  final ItemTapDown<DockerNetwork>? onTapDown;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
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
                          : (d) => onTapDown!(network, d, secondary: false),
                      onSecondaryTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(network, d, secondary: true),
                      child: InkWell(
                        onTap: onTap == null ? null : () => onTap!(network),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration:
                              selectedIds.contains(network.id.isNotEmpty ? network.id : network.name)
                                  ? BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  : null,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      icons.network,
                                      size: 18,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(network.name)),
                                  ],
                                ),
                              ),
                              Text(network.driver,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
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
    required this.selectedIds,
  });

  final List<DockerVolume> volumes;
  final ValueChanged<DockerVolume>? onTap;
  final ItemTapDown<DockerVolume>? onTapDown;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
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
                          : (d) => onTapDown!(volume, d, secondary: false),
                      onSecondaryTapDown: onTapDown == null
                          ? null
                          : (d) => onTapDown!(volume, d, secondary: true),
                      child: InkWell(
                        onTap: onTap == null ? null : () => onTap!(volume),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: selectedIds.contains(volume.name)
                              ? BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                )
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      icons.volume,
                                      size: 18,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(volume.name)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    volume.driver,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (volume.size != null &&
                                      volume.size!.trim().isNotEmpty)
                                    Text(
                                      volume.size!,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ],
                          ),
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
    this.selected = false,
    this.busy = false,
    this.progressLabel,
    this.flatIndex,
  });

  final DockerContainer container;
  final ValueChanged<DockerContainer>? onTap;
  final ItemTapDown<DockerContainer>? onTapDown;
  final bool selected;
  final bool busy;
  final String? progressLabel;
  final int? flatIndex;

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    final dockerTheme = context.appTheme.docker;
    final color = container.isRunning ? dockerTheme.running : dockerTheme.stopped;
    final hasProgress = progressLabel != null && progressLabel!.isNotEmpty;
    final statusLabel = hasProgress
        ? '${progressLabel![0].toUpperCase()}${progressLabel!.substring(1)}…'
        : container.isRunning
            ? _runningLabel(container)
            : 'Stopped (${container.status})';
    final statusColor = busy ? Theme.of(context).colorScheme.primary : color;
    return GestureDetector(
      onTapDown: onTapDown == null
          ? null
          : (d) => onTapDown!(
                container,
                d,
                secondary: false,
                flatIndex: flatIndex,
              ),
      onSecondaryTapDown: onTapDown == null
          ? null
          : (d) => onTapDown!(
                container,
                d,
                secondary: true,
                flatIndex: flatIndex,
              ),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(container),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icons.container, color: color),
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
                          ?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ),
              if (busy) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _runningLabel(DockerContainer container) {
    if (container.startedAt != null) {
      final now = DateTime.now();
      final diff = now.difference(container.startedAt!.toLocal());
      if (diff.inDays >= 1) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        return 'Running for ${days}d ${hours}h';
      }
      if (diff.inHours >= 1) {
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        return 'Running for ${hours}h ${mins}m';
      }
      if (diff.inMinutes >= 1) {
        final mins = diff.inMinutes;
        final secs = diff.inSeconds % 60;
        return 'Running for ${mins}m ${secs}s';
      }
      return 'Running for ${diff.inSeconds}s';
    }
    if (container.createdAt != null && container.createdAt!.isNotEmpty) {
      return 'Running for ${container.createdAt}';
    }
    return 'Running';
  }
}

String _imageKey(DockerImage image) {
  final repo = image.repository.isNotEmpty ? image.repository : '<none>';
  final tag = image.tag.isNotEmpty ? image.tag : '<none>';
  return '$repo:$tag:${image.id}';
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
