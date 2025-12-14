import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_image.dart';
import 'package:cwatch/models/docker_network.dart';
import 'package:cwatch/models/docker_volume.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/modules/docker/services/container_distro_key.dart';
import 'package:cwatch/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/widgets/lists/section_list_item.dart';
import 'package:cwatch/shared/widgets/lists/selectable_list_item.dart';
import 'docker_lists_helpers.dart';

typedef ItemTapDown<T> =
    void Function(
      T item,
      TapDownDetails details, {
      bool secondary,
      int? flatIndex,
    });

PopupMenuItem<String> _actionMenuItem(
  BuildContext context, {
  required String value,
  required String label,
  required IconData icon,
  Color? color,
}) {
  final scheme = Theme.of(context).colorScheme;
  final resolved = color ?? scheme.primary;
  return PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: resolved),
        const SizedBox(width: 8),
        Text(label, style: color != null ? TextStyle(color: color) : null),
      ],
    ),
  );
}

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
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: color),
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
      child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
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
    this.onComposeForward,
    this.onComposeStopForward,
    required this.settingsController,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final ItemTapDown<DockerContainer>? onTapDown;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;
  final void Function(String project, String action)? onComposeAction;
  final void Function(String project)? onComposeForward;
  final void Function(String project)? onComposeStopForward;
  final AppSettingsController settingsController;

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
        final projectName = isCompose
            ? project.replaceFirst('Compose: ', '')
            : null;
        final header = SectionListItem(
          title: project,
          subtitle: '${items.length} containers',
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
                      if (action == 'forward' &&
                          widget.onComposeForward != null) {
                        widget.onComposeForward!(name);
                      } else if (action == 'stopForward' &&
                          widget.onComposeStopForward != null) {
                        widget.onComposeStopForward!(name);
                      } else {
                        widget.onComposeAction!(name, action);
                      }
                    }
                  },
                  itemBuilder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return [
                      _actionMenuItem(
                        context,
                        value: 'logs',
                        label: 'Tail logs',
                        icon: Icons.list_alt_outlined,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'restart',
                        label: 'Restart project',
                        icon: icons.refresh,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'up',
                        label: 'Compose up (detach)',
                        icon: Icons.play_arrow_rounded,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'down',
                        label: 'Compose down',
                        icon: Icons.stop_rounded,
                        color: scheme.error,
                      ),
                      if (widget.onComposeForward != null)
                        _actionMenuItem(
                          context,
                          value: 'forward',
                          label: 'Port forward…',
                          icon: Icons.link_outlined,
                        ),
                      if (widget.onComposeForward != null)
                        _actionMenuItem(
                          context,
                          value: 'stopForward',
                          label: 'Stop port forwards',
                          icon: Icons.link_off_outlined,
                        ),
                    ];
                  },
                ),
              Icon(collapsed ? icons.arrowRight : icons.arrowDown, size: 18),
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
        );

        final rows = items.map((container) {
          flatIndex += 1;
          String runningLabel() {
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
            if (container.createdAt != null &&
                container.createdAt!.isNotEmpty) {
              return 'Running for ${container.createdAt}';
            }
            return 'Running';
          }

          final slug = _slugForContainer(widget.settingsController, container);
          final iconColor = colorForDistro(slug, context.appTheme);
          final iconSize = _distroIconSize(context);
          final statusColor = container.isRunning
              ? context.appTheme.docker.running
              : context.appTheme.docker.stopped;
          final resolvedIconColor = widget.busyIds.contains(container.id)
              ? Theme.of(context).colorScheme.primary
              : iconColor;

          return SelectableListItem(
            selected: widget.selectedIds.contains(container.id),
            title: container.name.isNotEmpty ? container.name : container.id,
            subtitle:
                'Image: ${container.image} • ${container.isRunning ? runningLabel() : container.status}',
            leading: Tooltip(
              message: labelForDistro(slug),
              child: DistroLeadingSlot(
                slug: slug,
                iconSize: iconSize,
                iconColor: resolvedIconColor,
                statusColor: statusColor,
              ),
            ),
            horizontalPadding: context.appTheme.spacing.base * 0.3,
            busy: widget.busyIds.contains(container.id),
            trailing: () {
              final actionLabel = widget.actionLabels[container.id];
              final actionButton = widget.onTapDown == null
                  ? null
                  : IconButton(
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Icon(Icons.more_vert, size: 20),
                      tooltip: 'Actions',
                      onPressed: () => widget.onTapDown!(
                        container,
                        TapDownDetails(kind: PointerDeviceKind.touch),
                        secondary: true,
                        flatIndex: flatIndex,
                      ),
                    );
              if (actionButton == null && actionLabel == null) {
                return null;
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionLabel != null) ...[
                    Text(
                      actionLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (actionButton != null) const SizedBox(width: 4),
                  ],
                  if (actionButton != null) actionButton,
                ],
              );
            }(),
            onTapDown: widget.onTapDown == null
                ? null
                : (details) => widget.onTapDown!(
                    container,
                    details,
                    secondary: false,
                    flatIndex: flatIndex,
                  ),
            onTap: widget.onTap == null ? null : () => widget.onTap!(container),
            onLongPress: widget.onTapDown == null
                ? null
                : () => widget.onTapDown!(
                    container,
                    TapDownDetails(kind: PointerDeviceKind.touch),
                    secondary: true,
                    flatIndex: flatIndex,
                  ),
            onDoubleTap: widget.onTapDown == null
                ? null
                : () => widget.onTapDown!(
                    container,
                    TapDownDetails(kind: PointerDeviceKind.touch),
                    secondary: true,
                    flatIndex: flatIndex,
                  ),
            onSecondaryTapDown: widget.onTapDown == null
                ? null
                : (details) => widget.onTapDown!(
                    container,
                    details,
                    secondary: true,
                    flatIndex: flatIndex,
                  ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionList(
            children: [
              header,
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Column(children: rows),
                ),
            ],
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
    required this.settingsController,
  });

  final List<DockerContainer> containers;
  final ValueChanged<DockerContainer>? onTap;
  final ItemTapDown<DockerContainer>? onTapDown;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;
  final void Function(String project, String action)? onComposeAction;
  final AppSettingsController settingsController;

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
        final projectName = isCompose
            ? project.replaceFirst('Compose: ', '')
            : null;
        final header = SectionListItem(
          title: project,
          subtitle: '${items.length} containers',
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
                  itemBuilder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    return [
                      _actionMenuItem(
                        context,
                        value: 'logs',
                        label: 'Tail logs',
                        icon: Icons.list_alt_outlined,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'restart',
                        label: 'Restart project',
                        icon: icons.refresh,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'up',
                        label: 'Compose up (detach)',
                        icon: Icons.play_arrow_rounded,
                      ),
                      _actionMenuItem(
                        context,
                        value: 'down',
                        label: 'Compose down',
                        icon: Icons.stop_rounded,
                        color: scheme.error,
                      ),
                    ];
                  },
                )
              : null,
        );
        final rows = items.map((container) {
          final runningLabel = container.isRunning
              ? _runningLabel(container)
              : container.status;
          final statusColor = container.isRunning
              ? context.appTheme.docker.running
              : context.appTheme.docker.stopped;
          final slug = _slugForContainer(settingsController, container);
          final iconColor = colorForDistro(slug, context.appTheme);
          final iconSize = _distroIconSize(context);
          final resolvedIconColor = busyIds.contains(container.id)
              ? Theme.of(context).colorScheme.primary
              : iconColor;
          return SelectableListItem(
            selected: selectedIds.contains(container.id),
            title: container.name.isNotEmpty ? container.name : container.id,
            subtitle: 'Image: ${container.image} • $runningLabel',
            leading: Tooltip(
              message: labelForDistro(slug),
              child: DistroLeadingSlot(
                slug: slug,
                iconSize: iconSize,
                iconColor: resolvedIconColor,
                statusColor: statusColor,
              ),
            ),
            horizontalPadding: context.appTheme.spacing.base * 0.3,
            busy: busyIds.contains(container.id),
            trailing: actionLabels[container.id] != null
                ? Text(
                    actionLabels[container.id]!,
                    style: Theme.of(context).textTheme.labelSmall,
                  )
                : null,
            onTapDown: onTapDown == null
                ? null
                : (details) => onTapDown!(container, details, secondary: false),
            onTap: onTap == null ? null : () => onTap!(container),
            onLongPress: onTapDown == null
                ? null
                : () => onTapDown!(
                    container,
                    TapDownDetails(kind: PointerDeviceKind.mouse),
                    secondary: false,
                  ),
            onSecondaryTapDown: onTapDown == null
                ? null
                : (details) => onTapDown!(container, details, secondary: true),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionList(children: [header, ...rows]),
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
    if (images.isEmpty) {
      return const EmptyCard(message: 'No images found.');
    }
    final groups = _groupImages(images);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
        final repo = entry.key;
        final items = entry.value;
        final header = SectionListItem(
          title: repo,
          subtitle: '${items.length} images',
        );
        final rows = items.map((image) {
          final name = [
            image.repository.isNotEmpty ? image.repository : '<none>',
            image.tag.isNotEmpty ? image.tag : '<none>',
          ].join(':');
          final isSelected = selectedIds.contains(_imageKey(image));
          final slug = slugForImage(image.repository, image.tag);
          final iconSize = _distroIconSize(context);
          final iconPadding = context.appTheme.spacing.base * 0.5;
          final iconColor = colorForDistro(slug, context.appTheme);
          return SelectableListItem(
            selected: isSelected,
            title: name,
            subtitle: 'Size: ${image.size}',
            leading: Tooltip(
              message: labelForDistro(slug),
              child: SizedBox(
                width: iconSize + iconPadding,
                child: Center(
                  child: Icon(
                    iconForDistro(slug),
                    size: iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            onTapDown: onTapDown == null
                ? null
                : (details) => onTapDown!(image, details, secondary: false),
            onTap: onTap == null ? null : () => onTap!(image),
            onLongPress: onTapDown == null
                ? null
                : () => onTapDown!(
                    image,
                    TapDownDetails(kind: PointerDeviceKind.mouse),
                    secondary: false,
                  ),
            trailing: onTapDown == null
                ? null
                : IconButton(
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(Icons.more_vert, size: 20),
                    tooltip: 'Actions',
                    onPressed: () => onTapDown!(
                      image,
                      TapDownDetails(kind: PointerDeviceKind.touch),
                      secondary: true,
                    ),
                  ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionList(children: [header, ...rows]),
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
        final slug = slugForImage(image.repository, image.tag);
        final iconSize = _distroIconSize(context);
        final iconPadding = context.appTheme.spacing.base * 0.5;
        final iconColor = colorForDistro(slug, context.appTheme);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableListItem(
            selected: isSelected,
            title: name,
            subtitle: 'Size: ${image.size}',
            leading: Tooltip(
              message: labelForDistro(slug),
              child: SizedBox(
                width: iconSize + iconPadding,
                child: Center(
                  child: Icon(
                    iconForDistro(slug),
                    size: iconSize,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            onTapDown: onTapDown == null
                ? null
                : (d) => onTapDown!(image, d, secondary: false),
            onTap: onTap == null ? null : () => onTap!(image),
            onSecondaryTapDown: onTapDown == null
                ? null
                : (d) => onTapDown!(image, d, secondary: true),
            trailing: onTapDown == null
                ? null
                : IconButton(
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(Icons.more_vert, size: 20),
                    tooltip: 'Actions',
                    onPressed: () => onTapDown!(
                      image,
                      TapDownDetails(kind: PointerDeviceKind.touch),
                      secondary: true,
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
        final header = SectionListItem(
          title: group,
          subtitle: '${items.length} networks',
        );
        final rows = items.map((network) {
          final isSelected = selectedIds.contains(
            network.id.isNotEmpty ? network.id : network.name,
          );
          return SelectableListItem(
            selected: isSelected,
            title: network.name,
            subtitle: network.driver,
            leading: Icon(
              icons.network,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            onTapDown: onTapDown == null
                ? null
                : (details) => onTapDown!(network, details, secondary: false),
            onTap: onTap == null ? null : () => onTap!(network),
            onLongPress: onTapDown == null
                ? null
                : () => onTapDown!(
                    network,
                    TapDownDetails(kind: PointerDeviceKind.mouse),
                    secondary: false,
                  ),
            trailing: onTapDown == null
                ? null
                : IconButton(
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(Icons.more_vert, size: 20),
                    tooltip: 'Actions',
                    onPressed: () => onTapDown!(
                      network,
                      TapDownDetails(kind: PointerDeviceKind.touch),
                      secondary: true,
                    ),
                  ),
          );
        }).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionList(children: [header, ...rows]),
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
        final header = SectionListItem(
          title: group,
          subtitle: '${items.length} volumes',
        );
        final rows = items.map((volume) {
          final isSelected = selectedIds.contains(volume.name);
          final subtitle = [
            volume.driver,
            if (volume.size != null && volume.size!.trim().isNotEmpty)
              volume.size!,
          ].join(' • ');
          return SelectableListItem(
            selected: isSelected,
            title: volume.name,
            subtitle: subtitle,
            leading: Icon(
              icons.volume,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            onTapDown: onTapDown == null
                ? null
                : (details) => onTapDown!(volume, details, secondary: false),
            onTap: onTap == null ? null : () => onTap!(volume),
            onLongPress: onTapDown == null
                ? null
                : () => onTapDown!(
                    volume,
                    TapDownDetails(kind: PointerDeviceKind.mouse),
                    secondary: false,
                  ),
            trailing: onTapDown == null
                ? null
                : IconButton(
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(Icons.more_vert, size: 20),
                    tooltip: 'Actions',
                    onPressed: () => onTapDown!(
                      volume,
                      TapDownDetails(kind: PointerDeviceKind.touch),
                      secondary: true,
                    ),
                  ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionList(children: [header, ...rows]),
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

String? _slugForContainer(
  AppSettingsController settings,
  DockerContainer container,
) {
  return settings.settings.dockerDistroMap[containerDistroCacheKey(
        container,
      )] ??
      slugForContainer(container);
}

double _distroIconSize(BuildContext context) {
  final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
  return titleSize * 1.9;
}
