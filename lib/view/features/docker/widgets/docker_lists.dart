import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/distro_icons.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/features/docker/services/container_distro_key.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/view/shared/widgets/lists/selectable_list_item.dart';
import 'docker_lists_helpers.dart';

typedef ItemTapDown<T> =
    void Function(
      T item,
      TapDownDetails details, {
      bool secondary,
      int? flatIndex,
      List<T>? selectedRows,
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
    final spacing = context.appTheme.spacing;
    return SizedBox(
      width: 140,
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.base * 3,
            vertical: spacing.base * 2.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: spacing.sm),
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
    final spacing = context.appTheme.spacing;
    return Card(
      child: Padding(padding: EdgeInsets.all(spacing.lg), child: Text(message)),
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
    this.dockerService,
    this.contextName,
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
  final DockerClientService? dockerService;
  final String? contextName;

  @override
  State<ContainerPeek> createState() => _ContainerPeekState();
}

class _ContainerPeekState extends State<ContainerPeek> {
  final Set<String> _collapsed = {};
  Future<Map<String, Map<String, double>>>? _allStatsFuture;
  Map<String, Map<String, double>>? _cachedStats;

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
          padding: EdgeInsets.only(bottom: spacing.sm),
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
                    icon: Icon(Icons.more_horiz, size: context.appTheme.iconSizes.medium),
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

  void _handleContainerContextMenu(
    DockerContainer container,
    List<DockerContainer> selectedRows,
    Offset? anchor,
  ) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(
      container,
      details,
      secondary: true,
      flatIndex: _flatIndexFor(container),
      selectedRows: selectedRows,
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
    // Always return all 6 columns: Container, Image, Status, Action, CPU, RAM
    final columns = [
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
      StructuredDataColumn<DockerContainer>(
        label: 'CPU',
        width: 80,
        autoFitText: (container) => '--',
        cellBuilder: (context, container) => _buildCpuCell(context, container),
      ),
      StructuredDataColumn<DockerContainer>(
        label: 'RAM',
        width: 80,
        autoFitText: (container) => '--',
        cellBuilder: (context, container) => _buildRamCell(context, container),
      ),
    ];
    assert(columns.length == 6, 'Expected 6 columns but got ${columns.length}');
    return columns;
  }
  
  Future<Map<String, Map<String, double>>> _fetchAllStats() async {
    // Return cached stats if available
    if (_cachedStats != null) {
      return Future.value(_cachedStats!);
    }
    
    // Use existing future if already loading
    if (_allStatsFuture != null) {
      return _allStatsFuture!;
    }
    
    // Start loading stats lazily
    _allStatsFuture = _loadAllStats();
    final stats = await _allStatsFuture!;
    _cachedStats = stats;
    return stats;
  }
  
  Future<Map<String, Map<String, double>>> _loadAllStats() async {
    final dockerService = widget.dockerService;
    if (dockerService == null) {
      return {};
    }
    try {
      // Fetch stats for all containers at once
      final stats = await dockerService.listContainerStats(
        context: widget.contextName,
      );
      
      final statsMap = <String, Map<String, double>>{};
      for (final stat in stats) {
        // Parse CPU percentage (remove % sign)
        final cpuStr = stat.cpu.replaceAll('%', '').trim();
        final cpu = double.tryParse(cpuStr) ?? 0.0;
        
        // Parse RAM percentage (remove % sign)
        final ramStr = stat.memPercent.replaceAll('%', '').trim();
        final ram = double.tryParse(ramStr) ?? 0.0;
        
        // Index by both ID and name for lookup
        statsMap[stat.id] = {'cpu': cpu, 'ram': ram};
        statsMap[stat.name] = {'cpu': cpu, 'ram': ram};
      }
      
      return statsMap;
    } catch (error) {
      // Return empty map if stats can't be loaded
      return {};
    }
  }
  
  Map<String, double> _getContainerStats(
    Map<String, Map<String, double>>? allStats,
    DockerContainer container,
  ) {
    if (allStats == null) {
      return {'cpu': 0.0, 'ram': 0.0};
    }
    return allStats[container.id] ?? 
           allStats[container.name] ?? 
           {'cpu': 0.0, 'ram': 0.0};
  }
  
  Widget _buildCpuCell(BuildContext context, DockerContainer container) {
    // Show placeholder immediately if no service or container not running
    if (widget.dockerService == null || !container.isRunning) {
      return Text(
        '--',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    
    // Show placeholder while loading stats
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: _fetchAllStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show placeholder text while loading
          return Text(
            '--',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Text(
            '--',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        final stats = _getContainerStats(snapshot.data, container);
        final cpu = stats['cpu'] ?? 0.0;
        return Text(
          '${cpu.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
  
  Widget _buildRamCell(BuildContext context, DockerContainer container) {
    // Show placeholder immediately if no service or container not running
    if (widget.dockerService == null || !container.isRunning) {
      return Text(
        '--',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    
    // Show placeholder while loading stats
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: _fetchAllStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show placeholder text while loading
          return Text(
            '--',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Text(
            '--',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        }
        final stats = _getContainerStats(snapshot.data, container);
        final ram = stats['ram'] ?? 0.0;
        return Text(
          '${ram.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
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
        SizedBox(width: context.appTheme.spacing.md),
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
        final header = SelectableListItem(
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
            horizontalPadding: context.appTheme.spacing.xs,
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
          padding: EdgeInsets.only(bottom: context.appTheme.spacing.md),
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

class _ImageRow {
  const _ImageRow({
    required this.repository,
    required this.images,
  });

  final String repository;
  final List<DockerImage> images;

  String get displayName => repository.isNotEmpty ? repository : '<none>';
  int get tagCount => images.length;
  String get totalSize => _calculateTotalSize(images);

  static String _calculateTotalSize(List<DockerImage> images) {
    if (images.isEmpty) return '—';
    // Show the largest image size as representative
    if (images.length == 1) return images.first.size;
    // For multiple tags, show count
    return '${images.length} tag${images.length == 1 ? '' : 's'}';
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
    required this.busyIds,
    required this.actionLabels,
    this.onRemoveImages,
    this.onPruneImages,
    this.onPullImage,
  });

  final List<DockerImage> images;
  final ValueChanged<DockerImage>? onTap;
  final ItemTapDown<DockerImage>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerImage> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;
  final Future<void> Function(List<String> imageIds)? onRemoveImages;
  final Future<void> Function()? onPruneImages;
  final Future<void> Function(String imageName)? onPullImage;

  @override
  State<ImagePeek> createState() => _ImagePeekState();
}

class _ImagePeekState extends State<ImagePeek> {
  final Map<String, ValueNotifier<bool>> _expandedRows = {};

  ValueNotifier<bool> _expansionFor(String repository) {
    return _expandedRows.putIfAbsent(
      repository,
      () => ValueNotifier<bool>(false),
    );
  }

  void _syncExpandedRows(List<_ImageRow> rows) {
    if (_expandedRows.isEmpty) {
      return;
    }
    final active = rows.map((r) => r.repository).toSet();
    _expandedRows.removeWhere((repo, _) => !active.contains(repo));
  }

  @override
  void dispose() {
    for (final notifier in _expandedRows.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const EmptyCard(message: 'No images found.');
    }

    final groups = _groupImages(widget.images);
    final rows = groups.entries
        .map((e) => _ImageRow(repository: e.key, images: e.value))
        .toList();
    _syncExpandedRows(rows);

    final totalTags = widget.images.length;
    final totalRepos = rows.length;
    final selectedCount = widget.selectedIds.length;
    final totalSize = _calculateTotalSize(widget.images);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: _ImageActionsBar(
            totalRepos: totalRepos,
            totalTags: totalTags,
            totalSize: totalSize,
            selectedCount: selectedCount,
            onClearSelection: () {
              widget.onSelectionChanged?.call({}, []);
            },
            onRemoveSelected: selectedCount > 0
                ? () => _handleRemoveSelected(context)
                : null,
            onPruneUnused: () => _handlePruneUnused(context),
            onPullImage: () => _handlePullImage(context),
          ),
        ),
        Card(
          margin: EdgeInsets.only(top: context.appTheme.spacing.xs),
          child: StructuredDataTable<_ImageRow>(
            rows: rows,
            columns: _imageColumns(context, totalTags, totalSize),
            autoRowHeight: true,
            shrinkToContent: true,
            useZebraStripes: false,
            rowSelectionEnabled: false,
            enableKeyboardNavigation: false,
            primaryDoubleClickOpensContextMenu: false,
          ),
        ),
      ],
    );
  }

  Future<void> _handleRemoveSelected(BuildContext context) async {
    if (widget.onRemoveImages == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove action not available')),
      );
      return;
    }

    // Get selected image IDs
    final selectedImages = widget.images
        .where((img) => widget.selectedIds.contains(_imageKey(img)))
        .toList();

    if (selectedImages.isEmpty) return;

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Images'),
        content: Text(
          'Are you sure you want to remove ${selectedImages.length} '
          'image${selectedImages.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final imageIds = selectedImages.map((img) => img.id).toList();
    await widget.onRemoveImages!(imageIds);
  }

  Future<void> _handlePruneUnused(BuildContext context) async {
    if (widget.onPruneImages == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prune action not available')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prune Unused Images'),
        content: const Text(
          'This will remove all dangling images (not tagged and not '
          'referenced by any container). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Prune'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.onPruneImages!();
  }

  Future<void> _handlePullImage(BuildContext context) async {
    if (widget.onPullImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pull action not available')),
      );
      return;
    }

    final imageName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Pull Image'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Image name',
              hintText: 'e.g., nginx:latest, ubuntu:22.04',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Pull'),
            ),
          ],
        );
      },
    );

    if (imageName == null || imageName.isEmpty) return;

    await widget.onPullImage!(imageName);
  }

  List<StructuredDataColumn<_ImageRow>> _imageColumns(
    BuildContext context,
    int totalTags,
    String totalSize,
  ) {
    return [
      StructuredDataColumn<_ImageRow>(
        label: '',
        width: 44,
        alignment: Alignment.topCenter,
        cellBuilder: (context, row) => _ExpandToggleCell(
          expanded: _expansionFor(row.repository),
        ),
      ),
      StructuredDataColumn<_ImageRow>(
        label: 'Repository',
        flex: 2,
        alignment: Alignment.topLeft,
        cellBuilder: (context, row) => _RepositoryCell(
          row: row,
          expanded: _expansionFor(row.repository),
          onTapDown: widget.onTapDown,
          onSelectionChanged: widget.onSelectionChanged,
          selectedIds: widget.selectedIds,
          busyIds: widget.busyIds,
          actionLabels: widget.actionLabels,
        ),
      ),
      StructuredDataColumn<_ImageRow>(
        label: 'Tags ($totalTags)',
        width: 100,
        alignment: Alignment.topLeft,
        cellBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '${row.tagCount}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
      StructuredDataColumn<_ImageRow>(
        label: 'Size ($totalSize)',
        width: 140,
        alignment: Alignment.topLeft,
        cellBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            row.totalSize,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    ];
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

  String _calculateTotalSize(List<DockerImage> images) {
    if (images.isEmpty) return '0 B';
    
    double totalBytes = 0;
    int parsedCount = 0;
    
    for (final image in images) {
      final bytes = _parseSizeToBytes(image.size);
      if (bytes != null) {
        totalBytes += bytes;
        parsedCount++;
      }
    }
    
    if (parsedCount == 0) return '—';
    
    return _formatBytes(totalBytes);
  }

  double? _parseSizeToBytes(String size) {
    final trimmed = size.trim();
    if (trimmed.isEmpty || trimmed == '—') return null;
    
    // Parse sizes like "1.5GB", "500MB", "10.2KB", etc.
    final regex = RegExp(r'^([\d.]+)\s*([KMGT]?B)$', caseSensitive: false);
    final match = regex.firstMatch(trimmed);
    
    if (match == null) return null;
    
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    
    final unit = match.group(2)?.toUpperCase() ?? 'B';
    
    switch (unit) {
      case 'B':
        return value;
      case 'KB':
        return value * 1024;
      case 'MB':
        return value * 1024 * 1024;
      case 'GB':
        return value * 1024 * 1024 * 1024;
      case 'TB':
        return value * 1024 * 1024 * 1024 * 1024;
      default:
        return null;
    }
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }
}

class _ImageActionsBar extends StatelessWidget {
  const _ImageActionsBar({
    required this.totalRepos,
    required this.totalTags,
    required this.totalSize,
    required this.selectedCount,
    required this.onClearSelection,
    this.onRemoveSelected,
    required this.onPruneUnused,
    this.onPullImage,
  });

  final int totalRepos;
  final int totalTags;
  final String totalSize;
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback? onRemoveSelected;
  final VoidCallback onPruneUnused;
  final Future<void> Function()? onPullImage;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final icons = context.appTheme.icons;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Summary info
          Icon(
            Icons.layers_outlined,
            size: 18,
            color: scheme.primary,
          ),
          SizedBox(width: spacing.sm),
          Text(
            '$totalRepos repositories • $totalTags tags • $totalSize',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (selectedCount > 0) ...[
            SizedBox(width: spacing.base),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$selectedCount selected',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const Spacer(),
          // Actions
          if (selectedCount > 0) ...[
            TextButton.icon(
              onPressed: onClearSelection,
              icon: Icon(Icons.clear, size: context.appTheme.iconSizes.small),
              label: const Text('Clear'),
            ),
            SizedBox(width: spacing.xs),
            FilledButton.tonalIcon(
              onPressed: onRemoveSelected,
              icon: Icon(Icons.delete_outline, size: context.appTheme.iconSizes.medium),
              label: const Text('Remove'),
              style: FilledButton.styleFrom(
                foregroundColor: scheme.error,
              ),
            ),
            SizedBox(width: spacing.xs),
          ],
          IconButton(
            icon: Icon(icons.refresh, size: context.appTheme.iconSizes.medium),
            tooltip: 'Prune unused images',
            onPressed: onPruneUnused,
          ),
          SizedBox(width: spacing.xs),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: context.appTheme.iconSizes.medium),
            tooltip: 'More actions',
            onSelected: (action) async {
              switch (action) {
                case 'pull':
                  await onPullImage?.call();
                  break;
                case 'prune':
                  onPruneUnused();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pull',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: context.appTheme.iconSizes.medium),
                    SizedBox(width: context.appTheme.spacing.md),
                    Text('Pull image...'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'prune',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: context.appTheme.iconSizes.medium),
                    SizedBox(width: context.appTheme.spacing.md),
                    Text('Prune unused'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpandToggleCell extends StatelessWidget {
  const _ExpandToggleCell({required this.expanded});

  final ValueNotifier<bool> expanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) {
        return IconButton(
          icon: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: isExpanded ? 'Collapse' : 'Expand',
          onPressed: () => expanded.value = !expanded.value,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        );
      },
    );
  }
}

class _RepositoryCell extends StatelessWidget {
  const _RepositoryCell({
    required this.row,
    required this.expanded,
    required this.onTapDown,
    required this.onSelectionChanged,
    required this.selectedIds,
    required this.busyIds,
    required this.actionLabels,
  });

  final _ImageRow row;
  final ValueNotifier<bool> expanded;
  final ItemTapDown<DockerImage>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerImage> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Repository name row
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: context.appTheme.iconSizes.large,
                    color: scheme.primary,
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      row.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded child table (spans across remaining columns)
            if (isExpanded) ...[
              SizedBox(height: spacing.xs),
              // Negative margin to span back to the left edge
              Transform.translate(
                offset: Offset(-44 - spacing.base, 0),
                child: SizedBox(
                  width: context.scale(2000), // Large width to span across
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.lg * 2 + 44,
                      0,
                      spacing.lg,
                      spacing.sm,
                    ),
                    child:                 _TagsTable(
                  images: row.images,
                  onTapDown: onTapDown,
                  onSelectionChanged: onSelectionChanged,
                  selectedIds: selectedIds,
                  busyIds: busyIds,
                  actionLabels: actionLabels,
                ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TagsTable extends StatelessWidget {
  const _TagsTable({
    required this.images,
    required this.onTapDown,
    required this.onSelectionChanged,
    required this.selectedIds,
    required this.busyIds,
    required this.actionLabels,
  });

  final List<DockerImage> images;
  final ItemTapDown<DockerImage>? onTapDown;
  final void Function(Set<String> tableKeys, List<DockerImage> selected)?
  onSelectionChanged;
  final Set<String> selectedIds;
  final Set<String> busyIds;
  final Map<String, String> actionLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: StructuredDataTable<DockerImage>(
        rows: images,
        columns: _tagColumns(context),
        rowHeight: 48,
        headerHeight: context.scale(32),
        shrinkToContent: true,
        useZebraStripes: false,
        surfaceBackgroundColor: scheme.surface,
        primaryDoubleClickOpensContextMenu: false,
        onRowContextMenu: (image, selectedRows, anchor) {
          if (onTapDown == null) return;
          final details = _tapDetails(anchor: anchor);
          onTapDown!(image, details, secondary: true, selectedRows: selectedRows);
        },
        onSelectionChanged: (selectedRows) {
          final keys = images.map(_imageKey).toSet();
          onSelectionChanged?.call(keys, selectedRows);
        },
      ),
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

  List<StructuredDataColumn<DockerImage>> _tagColumns(BuildContext context) {
    return [
      StructuredDataColumn<DockerImage>(
        label: 'Tag',
        flex: 2,
        autoFitText: _tagLabel,
        cellBuilder: (context, image) => _buildTagCell(context, image),
      ),
      StructuredDataColumn<DockerImage>(
        label: 'Size',
        flex: 1,
        alignment: Alignment.centerRight,
        autoFitText: (image) => image.size,
        cellBuilder: (context, image) => Text(image.size),
      ),
      StructuredDataColumn<DockerImage>(
        label: 'Created',
        flex: 1,
        alignment: Alignment.center,
        autoFitText: _createdLabel,
        cellBuilder: (context, image) => Text(_createdLabel(image)),
      ),
    ];
  }

  Widget _buildTagCell(BuildContext context, DockerImage image) {
    final slug = slugForImage(image.repository, image.tag);
    final iconSize = _distroIconSize(context);
    final iconColor = colorForDistro(slug, context.appTheme);
    final isBusy = busyIds.contains(image.id);
    final action = actionLabels[image.id];
    
    return Row(
      children: [
        if (isBusy) ...[
          SizedBox(
            width: context.scale(16),
            height: context.scale(16),
            child: CircularProgressIndicator(
              strokeWidth: 2 * context.zoomFactor,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: context.appTheme.spacing.md),
        ] else ...[
          Tooltip(
            message: labelForDistro(slug),
            child: Icon(iconForDistro(slug), size: iconSize, color: iconColor),
          ),
          SizedBox(width: context.appTheme.spacing.md),
        ],
        Expanded(
          child: Text(
            _tagLabel(image),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (isBusy && action != null) ...[
          SizedBox(width: context.appTheme.spacing.md),
          Text(
            action,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  String _tagLabel(DockerImage image) {
    return image.tag.isNotEmpty ? image.tag : '<none>';
  }

  String _createdLabel(DockerImage image) {
    return _valueOrDash(image.createdSince);
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
    final spacing = context.appTheme.spacing;
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
          padding: EdgeInsets.only(bottom: spacing.sm),
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
                    icon: Icon(Icons.more_vert, size: context.appTheme.iconSizes.large),
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
          padding: EdgeInsets.only(bottom: spacing.sm),
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
            children: collapsed
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
                        widget.onSelectionChanged?.call(keys, selectedRows);
                      },
                    ),
                  ],
          ),
        );
      }),
    );
  }

  void _handleNetworkContextMenu(
    DockerNetwork network,
    List<DockerNetwork> selectedRows,
    Offset? anchor,
  ) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(network, details, secondary: true, selectedRows: selectedRows);
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
          padding: EdgeInsets.only(bottom: spacing.sm),
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
            children: collapsed
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
                        final keys = items.map((item) => item.name).toSet();
                        widget.onSelectionChanged?.call(keys, selectedRows);
                      },
                    ),
                  ],
          ),
        );
      }),
    );
  }

  void _handleVolumeContextMenu(
    DockerVolume volume,
    List<DockerVolume> selectedRows,
    Offset? anchor,
  ) {
    if (widget.onTapDown == null) {
      return;
    }
    final details = _tapDetails(anchor: anchor);
    widget.onTapDown!(volume, details, secondary: true, selectedRows: selectedRows);
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
        alignment: Alignment.centerRight,
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
  // Scale with zoom factor to match text scaling
  return (titleSize * 1.9) * context.zoomFactor;
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
