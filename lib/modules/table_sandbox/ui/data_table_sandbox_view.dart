import 'dart:math';

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/data_table/structured_data_table.dart';

class DataTableSandboxView extends StatefulWidget {
  const DataTableSandboxView({super.key, required this.leading});

  final Widget leading;

  @override
  State<DataTableSandboxView> createState() => _DataTableSandboxViewState();
}

class _DataTableSandboxViewState extends State<DataTableSandboxView> {
  late List<_SandboxRow> _rows;
  String? _statusFilter;

  double _measureOneLineText(
    BuildContext context,
    String text, {
    TextStyle? style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _measureChipWidth(
    BuildContext context,
    StructuredDataChip chip, {
    required double paddingHorizontal,
    required double gapAfter,
  }) {
    final spacing = context.appTheme.spacing;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );
    final iconWidth = chip.icon == null ? 0.0 : 14.0 + spacing.xs;
    final textWidth = _measureOneLineText(context, chip.label, style: style);
    return paddingHorizontal * 2 + iconWidth + textWidth + gapAfter;
  }

  double _statusPillWidth(BuildContext context, _SandboxRow row) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(row.status, scheme);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        );
    final textWidth = _measureOneLineText(
      context,
      row.statusLabel,
      style: style,
    );
    final padding = spacing.base * 1.2;
    return padding * 2 + 8 + spacing.xs + textWidth;
  }

  double _sessionBadgeWidth(BuildContext context, _SandboxRow row) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final highlight = row.sessions > 6 ? scheme.primary : scheme.onSurface;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: highlight,
          fontWeight: FontWeight.w700,
        );
    final textWidth = _measureOneLineText(
      context,
      '${row.sessions} active',
      style: style,
    );
    final padding = spacing.base * 1.2;
    return padding * 2 + 16 + spacing.xs + textWidth;
  }

  double _nameCellWidth(BuildContext context, _SandboxRow row) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;

    final nameStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    final descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    final nameWidth = _measureOneLineText(
      context,
      row.name,
      style: nameStyle,
    );
    final descriptionWidth = _measureOneLineText(
      context,
      row.description,
      style: descriptionStyle,
    );

    // Mirrors _NameCell structure: 36 avatar + gap + max(line widths).
    return 36 + spacing.base * 1.5 + max(nameWidth, descriptionWidth);
  }

  @override
  void initState() {
    super.initState();
    _rows = _seedRows;
  }

  List<_SandboxRow> get _visibleRows {
    if (_statusFilter == null) return _rows;
    return _rows.where((row) => row.status == _statusFilter).toList();
  }

  List<_SandboxRow> get _secondaryRows =>
      _rows.where((row) => row.kind != 'Kubernetes').toList();

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _shuffleMetrics() {
    final rand = Random();
    setState(() {
      _rows = _rows
          .map(
            (row) => row.copyWith(
              latencyMs: max(20, row.latencyMs + rand.nextInt(60) - 30),
              sessions: max(0, row.sessions + rand.nextInt(4) - 2),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final typography = context.appTheme.typography;
    final scheme = Theme.of(context).colorScheme;

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: spacing.xs),
          const Text('Sandbox'),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.base * 0.6,
          vertical: spacing.base * 0.6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                widget.leading,
                SizedBox(width: spacing.md),
                Text(
                  'Data table lab',
                  style: typography.sectionTitle,
                ),
                SizedBox(width: spacing.sm),
                badge,
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Shuffle data'),
                  onPressed: _shuffleMetrics,
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              'A reusable data-table style list tuned for power-user views '
              '(servers, contexts, engines, explorer rows). '
              'It supports keyboard navigation, multi-select, context menus, '
              'metadata chips, and rich cells.',
              style: typography.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                _buildFilterChip(label: 'All', value: null),
                _buildFilterChip(label: 'Healthy', value: 'healthy'),
                _buildFilterChip(label: 'Warning', value: 'warning'),
                _buildFilterChip(label: 'Offline', value: 'offline'),
              ],
            ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: Column(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: StructuredDataTable<_SandboxRow>(
                      rows: _visibleRows,
                      rowHeight: 70,
                      shrinkToContent: true,
                      columns: [
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Name',
                          flex: 2,
                          sortValue: (row) => row.name,
                          autoFitText: (row) => row.name,
                          autoFitWidth: (context, row) =>
                              _nameCellWidth(context, row),
                          cellBuilder: (context, row) =>
                              _NameCell(row: row, scheme: scheme),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Status',
                          width: 140,
                          sortValue: (row) => row.status,
                          autoFitText: (row) => row.statusLabel,
                          autoFitWidth: (context, row) =>
                              _statusPillWidth(context, row),
                          cellBuilder: (context, row) => _StatusPill(row: row),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Latency',
                          width: 160,
                          sortValue: (row) => row.latencyMs,
                          autoFitText: (row) => '${row.latencyMs} ms',
                          autoFitWidth: (context, row) {
                            final style =
                                Theme.of(context).textTheme.bodyMedium;
                            return _measureOneLineText(
                              context,
                              '${row.latencyMs} ms',
                              style: style,
                            );
                          },
                          cellBuilder: (context, row) => _LatencyBar(row: row),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Sessions',
                          width: 120,
                          alignment: Alignment.center,
                          sortValue: (row) => row.sessions,
                          autoFitText: (row) => '${row.sessions} active',
                          autoFitWidth: (context, row) =>
                              _sessionBadgeWidth(context, row),
                          cellBuilder: (context, row) => _SessionBadge(row: row),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Region',
                          width: 140,
                          sortValue: (row) => row.region,
                          autoFitText: (row) => row.region,
                          cellBuilder: (context, row) => Text(
                            row.region,
                            style: typography.body,
                          ),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Updated',
                          width: 160,
                          sortValue: (row) => row.lastUpdatedMinutes,
                          autoFitText: (row) => row.lastUpdatedLabel,
                          cellBuilder: (context, row) => Text(
                            row.lastUpdatedLabel,
                            style: typography.caption,
                          ),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Meta',
                          flex: 2,
                          minWidth: 520,
                          sortValue: (row) => row.kind,
                          autoFitText: (row) => '${row.kind} ${row.tags.join(" ")}',
                          autoFitWidth: (context, row) {
                            final spacing = context.appTheme.spacing;
                            final chips = <StructuredDataChip>[
                              StructuredDataChip(
                                label: row.kind,
                                color: _accentForKind(
                                  row.kind,
                                  Theme.of(context).colorScheme,
                                ),
                                icon: Icons.devices_other_rounded,
                              ),
                              ...row.tags.map(
                                (tag) => StructuredDataChip(
                                  label: tag,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ];
                            final paddingHorizontal = spacing.sm;
                            var total = 0.0;
                            for (var i = 0; i < chips.length; i++) {
                              total += _measureChipWidth(
                                context,
                                chips[i],
                                paddingHorizontal: paddingHorizontal,
                                gapAfter: i == chips.length - 1 ? 0.0 : spacing.xs,
                              );
                            }
                            return total;
                          },
                          cellBuilder: (context, row) => _MetadataOnly(
                            chips: [
                              StructuredDataChip(
                                label: row.kind,
                                color: _accentForKind(row.kind, scheme),
                                icon: Icons.devices_other_rounded,
                              ),
                              ...row.tags.map(
                                (tag) => StructuredDataChip(
                                  label: tag,
                                  color: scheme.secondary.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      metadataBuilder: (_) => const [],
                      rowActions: [
                        StructuredDataAction<_SandboxRow>(
                          label: 'Open shell',
                          icon: Icons.terminal_outlined,
                          onSelected: (row) => _notify('Shell → ${row.name}'),
                        ),
                        StructuredDataAction<_SandboxRow>(
                          label: 'Inspect',
                          icon: Icons.search,
                          onSelected: (row) => _notify('Inspect → ${row.name}'),
                        ),
                        StructuredDataAction<_SandboxRow>(
                          label: 'Restart',
                          icon: Icons.restart_alt,
                          onSelected: (row) => _notify('Restart → ${row.name}'),
                        ),
                        StructuredDataAction<_SandboxRow>(
                          label: 'Delete',
                          icon: Icons.delete_outline,
                          destructive: true,
                          onSelected: (row) => _notify('Delete → ${row.name}'),
                        ),
                      ],
                      onRowDoubleTap: (row) => _notify('Open ${row.name}'),
                      emptyState: const Text('No entries match this filter.'),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Flexible(
                    fit: FlexFit.loose,
                    child: StructuredDataTable<_SandboxRow>(
                      rows: _secondaryRows,
                      rowHeight: 70,
                      shrinkToContent: true,
                      columns: [
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Service',
                          flex: 2,
                          autoFitWidth: (context, row) =>
                              _nameCellWidth(context, row),
                          cellBuilder: (context, row) =>
                              _NameCell(row: row, scheme: scheme),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Status',
                          width: 140,
                          autoFitWidth: (context, row) =>
                              _statusPillWidth(context, row),
                          cellBuilder: (context, row) => _StatusPill(row: row),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Sessions',
                          width: 120,
                          alignment: Alignment.center,
                          autoFitWidth: (context, row) =>
                              _sessionBadgeWidth(context, row),
                          cellBuilder: (context, row) => _SessionBadge(row: row),
                        ),
                        StructuredDataColumn<_SandboxRow>(
                          label: 'Region',
                          width: 140,
                          cellBuilder: (context, row) => Text(
                            row.region,
                            style: typography.body,
                          ),
                        ),
                      ],
                      metadataBuilder: (row) => [
                        StructuredDataChip(
                          label: row.kind,
                          color: _accentForKind(row.kind, scheme),
                          icon: Icons.layers,
                        ),
                        StructuredDataChip(
                          label: row.statusLabel,
                          color: _statusColor(row.status, scheme)
                              .withValues(alpha: 0.55),
                        ),
                      ],
                      rowActions: [
                        StructuredDataAction<_SandboxRow>(
                          label: 'Connect',
                          icon: Icons.link,
                          onSelected: (row) => _notify('Connect → ${row.name}'),
                        ),
                        StructuredDataAction<_SandboxRow>(
                          label: 'Stop',
                          icon: Icons.stop_circle_outlined,
                          onSelected: (row) => _notify('Stop → ${row.name}'),
                        ),
                      ],
                      onRowDoubleTap: (row) => _notify('Open ${row.name}'),
                      emptyState: const Text('No services available.'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({required String label, String? value}) {
    final selected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.16),
        width: 0.5,
      ),
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.04),
      selectedColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _accentForKind(String kind, ColorScheme scheme) {
    switch (kind) {
      case 'Docker engine':
        return scheme.primary;
      case 'Kubernetes':
        return scheme.secondary;
      case 'VM/Server':
        return scheme.tertiary;
      default:
        return scheme.secondary;
    }
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.row, required this.scheme});

  final _SandboxRow row;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final avatarColor = _statusColor(row.status, scheme);
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: _chipDecoration(avatarColor, colorScheme),
            child: Icon(
              row.icon,
              color: avatarColor,
              size: 18,
            ),
          ),
          SizedBox(width: spacing.base * 1.5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: spacing.xs),
              Text(
                row.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.row});

  final _SandboxRow row;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final color = _statusColor(row.status, scheme);
    final decoration = _chipDecoration(color, scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * 1.2,
        vertical: spacing.xs * 1.4,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: spacing.xs),
          Text(
            row.statusLabel,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LatencyBar extends StatelessWidget {
  const _LatencyBar({required this.row});

  final _SandboxRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final pct = (row.latencyMs / 200).clamp(0.0, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${row.latencyMs} ms',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        SizedBox(height: spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: 1 - pct,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            valueColor: AlwaysStoppedAnimation(
              pct < 0.45
                  ? scheme.primary
                  : (pct < 0.7 ? scheme.secondary : scheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({required this.row});

  final _SandboxRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final highlight = row.sessions > 6 ? scheme.primary : scheme.onSurface;
    final decoration = _chipDecoration(highlight, scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * 1.2,
        vertical: spacing.xs * 1.2,
      ),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            row.sessions > 0 ? Icons.link : Icons.link_off,
            size: 16,
            color: highlight,
          ),
          SizedBox(width: spacing.xs),
          Flexible(
            child: Text(
              '${row.sessions} active',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: highlight, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataOnly extends StatelessWidget {
  const _MetadataOnly({required this.chips});

  final List<StructuredDataChip> chips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final chipHeight = spacing.base * 4;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: chipHeight,
            width: constraints.maxWidth,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (chip) => Container(
                        margin: EdgeInsets.only(right: spacing.xs),
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.xs * 0.9,
                        ),
                        decoration: BoxDecoration(
                          color: (chip.color ?? scheme.surfaceContainerHighest)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.transparent, width: 0.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chip.icon != null) ...[
                              Icon(
                                chip.icon,
                                size: 14,
                                color: chip.color ?? scheme.onSurface,
                              ),
                              SizedBox(width: spacing.xs),
                            ],
                            Text(
                              chip.label,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: chip.color ?? scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SandboxRow {
  const _SandboxRow({
    required this.name,
    required this.description,
    required this.status,
    required this.region,
    required this.kind,
    required this.latencyMs,
    required this.sessions,
    required this.lastUpdatedMinutes,
    required this.tags,
    required this.icon,
  });

  final String name;
  final String description;
  final String status;
  final String region;
  final String kind;
  final int latencyMs;
  final int sessions;
  final int lastUpdatedMinutes;
  final List<String> tags;
  final IconData icon;

  String get statusLabel {
    switch (status) {
      case 'healthy':
        return 'Healthy';
      case 'warning':
        return 'Warning';
      case 'offline':
        return 'Offline';
      default:
        return status;
    }
  }

  String get lastUpdatedLabel =>
      lastUpdatedMinutes == 0 ? 'Just now' : '$lastUpdatedMinutes min ago';

  _SandboxRow copyWith({
    int? latencyMs,
    int? sessions,
  }) {
    return _SandboxRow(
      name: name,
      description: description,
      status: status,
      region: region,
      kind: kind,
      latencyMs: latencyMs ?? this.latencyMs,
      sessions: sessions ?? this.sessions,
      lastUpdatedMinutes: lastUpdatedMinutes,
      tags: tags,
      icon: icon,
    );
  }
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'healthy':
      return scheme.primary;
    case 'warning':
      return scheme.secondary;
    case 'offline':
      return scheme.error;
    default:
      return scheme.primary;
  }
}

BoxDecoration _chipDecoration(Color base, ColorScheme scheme) {
  return BoxDecoration(
    color: base.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(2),
    border: Border.all(
      color: scheme.outlineVariant.withValues(alpha: 0.12),
      width: 0.4,
    ),
  );
}

const List<_SandboxRow> _seedRows = [
  _SandboxRow(
    name: 'fra-edge-01',
    description: 'Gateway • Debian 12',
    status: 'healthy',
    region: 'Frankfurt',
    kind: 'VM/Server',
    latencyMs: 38,
    sessions: 5,
    lastUpdatedMinutes: 2,
    tags: ['prod', 'tls', 'ansible'],
    icon: Icons.dns_outlined,
  ),
  _SandboxRow(
    name: 'k8s-lab-west',
    description: 'Kubernetes control plane',
    status: 'warning',
    region: 'us-west-2',
    kind: 'Kubernetes',
    latencyMs: 84,
    sessions: 9,
    lastUpdatedMinutes: 6,
    tags: ['ingress', 'autoscale', 'demo'],
    icon: Icons.podcasts,
  ),
  _SandboxRow(
    name: 'edge-registry',
    description: 'Docker engine for mirror cache',
    status: 'healthy',
    region: 'London',
    kind: 'Docker engine',
    latencyMs: 42,
    sessions: 3,
    lastUpdatedMinutes: 1,
    tags: ['registry', 'cache'],
    icon: Icons.storage_outlined,
  ),
  _SandboxRow(
    name: 'ops-sftp',
    description: 'File bridge (sshfs)',
    status: 'offline',
    region: 'Toronto',
    kind: 'VM/Server',
    latencyMs: 190,
    sessions: 0,
    lastUpdatedMinutes: 18,
    tags: ['backup', 'audit'],
    icon: Icons.cloud_off_outlined,
  ),
  _SandboxRow(
    name: 'cluster-mesh-eu',
    description: 'Kubernetes worker pool',
    status: 'healthy',
    region: 'Amsterdam',
    kind: 'Kubernetes',
    latencyMs: 56,
    sessions: 6,
    lastUpdatedMinutes: 3,
    tags: ['mesh', 'cilium'],
    icon: Icons.hub_outlined,
  ),
  _SandboxRow(
    name: 'builder-02',
    description: 'Docker engine with cache mounts',
    status: 'warning',
    region: 'Paris',
    kind: 'Docker engine',
    latencyMs: 112,
    sessions: 2,
    lastUpdatedMinutes: 9,
    tags: ['ci', 'buildx'],
    icon: Icons.devices_fold_outlined,
  ),
];
