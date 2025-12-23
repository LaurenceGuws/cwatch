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
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
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
    this.onSelectionChanged,
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
  final void Function(Set<String> tableKeys, List<DockerContainer> selected)?
  onSelectionChanged;
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
    final spacing = context.appTheme.spacing;
    if (widget.containers.isEmpty) {
      return const EmptyCard(message: 'No containers match your filters.');
    }
    final groups = _group(widget.containers);
    final entries = groups.entries.toList();
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final project = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(project);
        final isCompose = project.startsWith('Compose: ');
        final projectName = isCompose
            ? project.replaceFirst('Compose: ', '')
            : null;
        final sectionColor = _sectionBackgroundForIndex(context, index);

        return Padding(
          padding: EdgeInsets.only(bottom: spacing.base * 1.5),
          child: SectionList(
            title: project,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${items.length} containers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                if (isCompose && widget.onComposeAction != null)
                  PopupMenuButton<String>(
                    tooltip: 'Compose actions',
                    icon: const Icon(Icons.more_horiz, size: 18),
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
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      if (collapsed) {
                        _collapsed.remove(project);
                      } else {
                        _collapsed.add(project);
                      }
                    });
                  },
                ),
              ],
            ),
            children: collapsed
                ? const []
                : [
                    StructuredDataTable<DockerContainer>(
                      rows: items,
                      columns: _containerColumns(context),
                      rowHeight: 64,
                      shrinkToContent: true,
                      useZebraStripes: false,
                      surfaceBackgroundColor: sectionColor,
                      primaryDoubleClickOpensContextMenu: false,
                      onRowContextMenu: _handleContainerContextMenu,
                      onSelectionChanged: (selectedRows) {
                        final keys = items.map((item) => item.id).toSet();
                        widget.onSelectionChanged?.call(keys, selectedRows);
                      },
                    ),
                  ],
          ),
        );
      }),
    );
  }

  void _handleContainerContextMenu(DockerContainer container, Offset? anchor) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(
      container,
      details,
      secondary: true,
      flatIndex: _flatIndexFor(container),
    );
  }

  TapDownDetails _tapDetails({
    Offset? anchor,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) {
    final position = anchor ?? Offset.zero;
    return TapDownDetails(
      globalPosition: position,
      localPosition: position,
      kind: kind,
    );
  }

  int? _flatIndexFor(DockerContainer container) {
    final index = widget.containers.indexWhere(
      (item) => item.id == container.id,
    );
    if (index == -1) {
      return null;
    }
    return index;
  }

  List<StructuredDataColumn<DockerContainer>> _containerColumns(
    BuildContext context,
  ) {
    return [
      StructuredDataColumn<DockerContainer>(
        label: 'Container',
        autoFitText: (container) => _displayName(container),
        cellBuilder: _buildContainerCell,
      ),
      StructuredDataColumn<DockerContainer>(
        label: 'Image',
        autoFitText: (container) => container.image,
        cellBuilder: (context, container) => Text(container.image),
      ),
      StructuredDataColumn<DockerContainer>(
        label: 'Status',
        autoFitText: _statusText,
        cellBuilder: (context, container) => Text(_statusText(container)),
      ),
      StructuredDataColumn<DockerContainer>(
        label: 'Action',
        autoFitText: (container) => _actionLabel(container),
        cellBuilder: _buildActionCell,
      ),
    ];
  }

  String _displayName(DockerContainer container) {
    return container.name.isNotEmpty ? container.name : container.id;
  }

  Widget _buildContainerCell(BuildContext context, DockerContainer container) {
    final slug = _slugForContainer(widget.settingsController, container);
    final iconColor = colorForDistro(slug, context.appTheme);
    final iconSize = _distroIconSize(context);
    final statusColor = container.isRunning
        ? context.appTheme.docker.running
        : context.appTheme.docker.stopped;
    final resolvedIconColor = widget.busyIds.contains(container.id)
        ? Theme.of(context).colorScheme.primary
        : iconColor;
    return Row(
      children: [
        Tooltip(
          message: labelForDistro(slug),
          child: DistroLeadingSlot(
            slug: slug,
            iconSize: iconSize,
            iconColor: resolvedIconColor,
            statusColor: statusColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _displayName(container),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  String _statusText(DockerContainer container) {
    if (container.isRunning) {
      return _runningLabel(container);
    }
    return container.status;
  }

  String _actionLabel(DockerContainer container) {
    return widget.actionLabels[container.id] ?? '';
  }

  Widget _buildActionCell(BuildContext context, DockerContainer container) {
    final label = _actionLabel(container);
    final isBusy = widget.busyIds.contains(container.id);
    final theme = Theme.of(context).textTheme.labelSmall;
    if (!isBusy) {
      return Text(_valueOrDash(label), style: theme);
    }
    final displayLabel = label.isNotEmpty ? label : 'Working';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(displayLabel, style: theme),
      ],
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
                  icon: const Icon(Icons.more_vert),
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
        final rows = List.generate(items.length, (index) {
          final container = items[index];
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
            stripeIndex: index,
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
        });

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

class ImagePeek extends StatefulWidget {
  const ImagePeek({
    super.key,
    required this.images,
    this.onTap,
    this.onTapDown,
    this.onSelectionChanged,
    required this.selectedIds,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final ItemTapDown<DockerImage>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerImage> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;

  @override
  State<ImagePeek> createState() => _ImagePeekState();
}

class _ImagePeekState extends State<ImagePeek> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const EmptyCard(message: 'No images found.');
    }
    final spacing = context.appTheme.spacing;
    final groups = _groupImages(widget.images);
    final entries = groups.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final repo = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(repo);
        final sectionColor = _sectionBackgroundForIndex(context, index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.base * 1.5),
          child: SectionList(
            title: repo,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${items.length} images',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      if (collapsed) {
                        _collapsed.remove(repo);
                      } else {
                        _collapsed.add(repo);
                      }
                    });
                  },
                ),
              ],
            ),
            children:
                collapsed
                    ? const []
                    : [
                        StructuredDataTable<DockerImage>(
                          rows: items,
                          columns: _imageColumns(context),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
                          primaryDoubleClickOpensContextMenu: false,
                          onRowContextMenu: _handleImageContextMenu,
                          onSelectionChanged: (selectedRows) {
                            final keys = items.map(_imageKey).toSet();
                            widget.onSelectionChanged?.call(keys, selectedRows);
                          },
                        ),
                      ],
          ),
        );
      }),
    );
  }

  void _handleImageContextMenu(DockerImage image, Offset? anchor) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(image, details, secondary: true);
  }

  TapDownDetails _tapDetails({
    Offset? anchor,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) {
    final position = anchor ?? Offset.zero;
    return TapDownDetails(
      globalPosition: position,
      localPosition: position,
      kind: kind,
    );
  }

  List<StructuredDataColumn<DockerImage>> _imageColumns(BuildContext context) {
    return [
      StructuredDataColumn<DockerImage>(
        label: 'Tag',
        autoFitText: _tagLabel,
        cellBuilder: _buildTagCell,
      ),
      StructuredDataColumn<DockerImage>(
        label: 'Size',
        autoFitText: (image) => image.size,
        cellBuilder: (context, image) => Text(image.size),
      ),
      StructuredDataColumn<DockerImage>(
        label: 'Created',
        autoFitText: _createdLabel,
        cellBuilder: (context, image) => Text(_createdLabel(image)),
      ),
    ];
  }

  Widget _buildTagCell(BuildContext context, DockerImage image) {
    final slug = slugForImage(image.repository, image.tag);
    final iconSize = _distroIconSize(context);
    final iconColor = colorForDistro(slug, context.appTheme);
    return Row(
      children: [
        Tooltip(
          message: labelForDistro(slug),
          child: Icon(iconForDistro(slug), size: iconSize, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _tagLabel(image),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  String _tagLabel(DockerImage image) {
    return image.tag.isNotEmpty ? image.tag : '<none>';
  }

  String _createdLabel(DockerImage image) {
    return _valueOrDash(image.createdSince);
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
      children: List.generate(images.length, (index) {
        final image = images[index];
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
            stripeIndex: index,
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
      }),
    );
  }
}

class NetworkList extends StatefulWidget {
  const NetworkList({
    super.key,
    required this.networks,
    this.onTap,
    this.onTapDown,
    this.onSelectionChanged,
    required this.selectedIds,
  });

  final List<DockerNetwork> networks;
  final ValueChanged<DockerNetwork>? onTap;
  final ItemTapDown<DockerNetwork>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerNetwork> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;

  @override
  State<NetworkList> createState() => _NetworkListState();
}

class _NetworkListState extends State<NetworkList> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (widget.networks.isEmpty) {
      return const EmptyCard(message: 'No networks found.');
    }
    final spacing = context.appTheme.spacing;
    final groups = _groupByComposeish(widget.networks);
    final entries = groups.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final group = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(group);
        final sectionColor = _sectionBackgroundForIndex(context, index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.base * 1.5),
          child: SectionList(
            title: group,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${items.length} networks',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      if (collapsed) {
                        _collapsed.remove(group);
                      } else {
                        _collapsed.add(group);
                      }
                    });
                  },
                ),
              ],
            ),
            children:
                collapsed
                    ? const []
                    : [
                        StructuredDataTable<DockerNetwork>(
                          rows: items,
                          columns: _networkColumns(context, icons),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
                          primaryDoubleClickOpensContextMenu: false,
                          onRowContextMenu: _handleNetworkContextMenu,
                          onSelectionChanged: (selectedRows) {
                            final keys = items
                                .map(
                                  (item) =>
                                      item.id.isNotEmpty ? item.id : item.name,
                                )
                                .toSet();
                            widget.onSelectionChanged?.call(
                              keys,
                              selectedRows,
                            );
                          },
                        ),
                      ],
          ),
        );
      }),
    );
  }

  void _handleNetworkContextMenu(DockerNetwork network, Offset? anchor) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(network, details, secondary: true);
  }

  TapDownDetails _tapDetails({
    Offset? anchor,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) {
    final position = anchor ?? Offset.zero;
    return TapDownDetails(
      globalPosition: position,
      localPosition: position,
      kind: kind,
    );
  }

  List<StructuredDataColumn<DockerNetwork>> _networkColumns(
    BuildContext context,
    AppIcons icons,
  ) {
    return [
      StructuredDataColumn<DockerNetwork>(
        label: 'Network',
        autoFitText: (network) => network.name,
        cellBuilder: (context, network) => Row(
          children: [
            Icon(
              icons.network,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                network.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      StructuredDataColumn<DockerNetwork>(
        label: 'Driver',
        autoFitText: (network) => network.driver,
        cellBuilder: (context, network) => Text(network.driver),
      ),
      StructuredDataColumn<DockerNetwork>(
        label: 'Scope',
        autoFitText: (network) => network.scope,
        cellBuilder: (context, network) => Text(network.scope),
      ),
    ];
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

class VolumeList extends StatefulWidget {
  const VolumeList({
    super.key,
    required this.volumes,
    this.onTap,
    this.onTapDown,
    this.onSelectionChanged,
    required this.selectedIds,
  });

  final List<DockerVolume> volumes;
  final ValueChanged<DockerVolume>? onTap;
  final ItemTapDown<DockerVolume>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerVolume> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;

  @override
  State<VolumeList> createState() => _VolumeListState();
}

class _VolumeListState extends State<VolumeList> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final icons = context.appTheme.icons;
    if (widget.volumes.isEmpty) {
      return const EmptyCard(message: 'No volumes found.');
    }
    final spacing = context.appTheme.spacing;
    final groups = _groupByComposeish(widget.volumes);
    final entries = groups.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final group = entry.key;
        final items = entry.value;
        final collapsed = _collapsed.contains(group);
        final sectionColor = _sectionBackgroundForIndex(context, index);
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.base * 1.5),
          child: SectionList(
            title: group,
            backgroundColor: sectionColor,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${items.length} volumes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      if (collapsed) {
                        _collapsed.remove(group);
                      } else {
                        _collapsed.add(group);
                      }
                    });
                  },
                ),
              ],
            ),
            children:
                collapsed
                    ? const []
                    : [
                        StructuredDataTable<DockerVolume>(
                          rows: items,
                          columns: _volumeColumns(context, icons),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
                          primaryDoubleClickOpensContextMenu: false,
                          onRowContextMenu: _handleVolumeContextMenu,
                          onSelectionChanged: (selectedRows) {
                            final keys =
                                items.map((item) => item.name).toSet();
                            widget.onSelectionChanged?.call(
                              keys,
                              selectedRows,
                            );
                          },
                        ),
                      ],
          ),
        );
      }),
    );
  }

  void _handleVolumeContextMenu(DockerVolume volume, Offset? anchor) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(volume, details, secondary: true);
  }

  TapDownDetails _tapDetails({
    Offset? anchor,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) {
    final position = anchor ?? Offset.zero;
    return TapDownDetails(
      globalPosition: position,
      localPosition: position,
      kind: kind,
    );
  }

  List<StructuredDataColumn<DockerVolume>> _volumeColumns(
    BuildContext context,
    AppIcons icons,
  ) {
    return [
      StructuredDataColumn<DockerVolume>(
        label: 'Volume',
        autoFitText: (volume) => volume.name,
        cellBuilder: (context, volume) => Row(
          children: [
            Icon(
              icons.volume,
              size: 18,
              color: Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                volume.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Driver',
        autoFitText: (volume) => volume.driver,
        cellBuilder: (context, volume) => Text(volume.driver),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Size',
        autoFitText: (volume) => _valueOrDash(volume.size),
        cellBuilder: (context, volume) => Text(_valueOrDash(volume.size)),
      ),
      StructuredDataColumn<DockerVolume>(
        label: 'Scope',
        autoFitText: (volume) => _valueOrDash(volume.scope),
        cellBuilder: (context, volume) => Text(_valueOrDash(volume.scope)),
      ),
    ];
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

Color _sectionBackgroundForIndex(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  final base = context.appTheme.section.surface.background;
  final overlay = scheme.surfaceTint.withValues(alpha: 0.08);
  final alternate = Color.alphaBlend(overlay, base);
  return index.isEven ? base : alternate;
}

String _valueOrDash(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }
  return value;
}
