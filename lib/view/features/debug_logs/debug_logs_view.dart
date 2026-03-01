import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/form_spacer.dart';
import 'package:cwatch/view/shared/widgets/section_nav_bar.dart';

class DebugLogsView extends StatefulWidget {
  const DebugLogsView({
    super.key,
    required this.settingsController,
    this.leading,
  });

  final AppSettingsController settingsController;
  final Widget? leading;

  @override
  State<DebugLogsView> createState() => _DebugLogsViewState();
}

class _DebugLogsViewState extends State<DebugLogsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final settings = widget.settingsController.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Debug Logs',
              tabs: const [
                Tab(text: 'Networking'),
                Tab(text: 'Performance'),
              ],
              controller: _tabController,
              showTitle: true,
              leading: widget.leading,
              enableWindowDrag: !settings.windowUseSystemDecorations,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DebugLogsPanel(debugEnabled: settings.debugMode),
                  _PerformancePanel(debugEnabled: settings.debugMode),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DebugLogsPanel extends StatefulWidget {
  const _DebugLogsPanel({required this.debugEnabled});

  final bool debugEnabled;

  @override
  State<_DebugLogsPanel> createState() => _DebugLogsPanelState();
}

class _DebugLogsPanelState extends State<_DebugLogsPanel> {
  final Map<RemoteCommandDebugEvent, ValueNotifier<bool>> _expandedRows = {};
  int? _sortColumnIndex;
  bool _sortAscending = true;

  ValueNotifier<bool> _expansionFor(RemoteCommandDebugEvent event) {
    return _expandedRows.putIfAbsent(event, () => ValueNotifier<bool>(false));
  }

  void _syncExpandedRows(List<RemoteCommandDebugEvent> events) {
    if (_expandedRows.isEmpty) {
      return;
    }
    final active = events.toSet();
    _expandedRows.removeWhere((event, _) => !active.contains(event));
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
    return AnimatedBuilder(
      animation: AppLogger.remoteCommandLog,
      builder: (context, _) {
        final spacing = context.appTheme.spacing;
        final rawEvents = AppLogger.remoteCommandLog.events;
        _syncExpandedRows(rawEvents);
        if (rawEvents.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const FormSpacer(),
                  Text(
                    widget.debugEnabled
                        ? 'No command activity logged yet.'
                        : 'Enable Debug Mode to capture command logs.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final events = _sortedEvents(rawEvents);

        return Column(
          children: [
            Padding(
              padding: spacing.inset(horizontal: 3, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    widget.debugEnabled
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    widget.debugEnabled
                        ? 'Debug logging is ON'
                        : 'Debug logging is OFF',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: AppLogger.remoteCommandLog.clear,
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StructuredDataTable<RemoteCommandDebugEvent>(
                rows: events,
                columns: [
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: '',
                    width: 44,
                    alignment: Alignment.topCenter,
                    cellBuilder: (context, event) =>
                        _DetailsToggleCell(expanded: _expansionFor(event)),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Level',
                    width: 90,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.level.index,
                    cellBuilder: (context, event) => _LevelCell(event: event),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Client',
                    width: 100,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.source,
                    cellBuilder: (context, event) => Text(
                      event.source,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Client Context',
                    width: 180,
                    wrap: true,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.contextLabel,
                    cellBuilder: (context, event) => Text(
                      event.contextLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Action',
                    flex: 1,
                    wrap: true,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.operation,
                    cellBuilder: (context, event) => _ActionCell(
                      event: event,
                      expanded: _expansionFor(event),
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Time',
                    width: 90,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.timestamp,
                    cellBuilder: (context, event) => Text(
                      _formatTimestamp(event.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                fitColumnsToWidth: true,
                headerHeight: context.scale(32),
                autoRowHeight: true,
                shrinkToContent: false,
                useZebraStripes: false,
                rowSelectionEnabled: false,
                enableKeyboardNavigation: false,
                onSortChanged: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<RemoteCommandDebugEvent> _sortedEvents(
    List<RemoteCommandDebugEvent> events,
  ) {
    final columnIndex = _sortColumnIndex;
    if (columnIndex == null) {
      return events;
    }
    final columns = _columnsForSort();
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return events;
    }
    final sortValue = columns[columnIndex];
    if (sortValue == null) {
      return events;
    }
    final sorted = [...events];
    sorted.sort((a, b) {
      final aValue = sortValue(a);
      final bValue = sortValue(b);
      final compare = _compareComparable(aValue, bValue);
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  List<Comparable<Object?>? Function(RemoteCommandDebugEvent)?>
  _columnsForSort() {
    return [
      null,
      (event) => event.level.index,
      (event) => event.source,
      (event) => event.contextLabel,
      (event) => event.operation,
      (event) => event.timestamp,
    ];
  }
}

class _DetailsToggleCell extends StatelessWidget {
  const _DetailsToggleCell({required this.expanded});

  final ValueNotifier<bool> expanded;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) => Padding(
        padding: EdgeInsets.only(top: spacing.xs),
        child: IconButton(
          tooltip: isExpanded ? 'Hide details' : 'Show details',
          iconSize: 18,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: scheme.primary,
          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          onPressed: () => expanded.value = !isExpanded,
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.event});

  final RemoteCommandDebugEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final levelLabel = _levelLabel(event.level);
    final color = _levelColor(event.level, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        levelLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _ActionCell extends StatefulWidget {
  const _ActionCell({required this.event, required this.expanded});

  final RemoteCommandDebugEvent event;
  final ValueNotifier<bool> expanded;

  @override
  State<_ActionCell> createState() => _ActionCellState();
}

class _ActionCellState extends State<_ActionCell> {
  bool _showCommand = false;
  bool _showOutput = false;
  bool _showVerification = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final verificationStatus = event.verificationPassed == null
        ? 'No verification run'
        : (event.verificationPassed!
              ? 'Verification passed'
              : 'Verification failed');
    final verificationColor = event.verificationPassed == null
        ? scheme.onSurfaceVariant
        : (event.verificationPassed! ? scheme.primary : scheme.error);
    return ValueListenableBuilder<bool>(
      valueListenable: widget.expanded,
      builder: (context, isExpanded, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.operation, style: Theme.of(context).textTheme.bodySmall),
          if (isExpanded) ...[
            SizedBox(height: spacing.sm),
            if (event.command.isNotEmpty)
              _CollapsibleSection(
                label: 'Command',
                isExpanded: _showCommand,
                onToggle: () => setState(() => _showCommand = !_showCommand),
                maxExpandedHeight: 140,
                child: SelectableText(
                  event.command,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (event.output.isNotEmpty) ...[
              SizedBox(height: spacing.base * 1.5),
              _CollapsibleSection(
                label: 'Output',
                isExpanded: _showOutput,
                onToggle: () => setState(() => _showOutput = !_showOutput),
                maxExpandedHeight: 240,
                child: SelectableText(
                  event.output,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (event.verificationCommand != null ||
                event.verificationOutput != null) ...[
              SizedBox(height: spacing.base * 1.5),
              _CollapsibleSection(
                label: 'Verification',
                isExpanded: _showVerification,
                onToggle: () =>
                    setState(() => _showVerification = !_showVerification),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      'Check: ${event.verificationCommand ?? 'n/a'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (event.verificationOutput != null)
                      Padding(
                        padding: EdgeInsets.only(top: spacing.sm),
                        child: SelectableText(
                          'Check output:\n${event.verificationOutput}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: spacing.base * 1.5),
            Text(
              verificationStatus,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: verificationColor),
            ),
          ],
        ],
      ),
    );
  }
}

String _levelLabel(LogLevel level) {
  switch (level) {
    case LogLevel.trace:
      return 'Trace';
    case LogLevel.debug:
      return 'Debug';
    case LogLevel.info:
      return 'Info';
    case LogLevel.warning:
      return 'Warn';
    case LogLevel.error:
      return 'Error';
    case LogLevel.critical:
      return 'Critical';
  }
}

Color _levelColor(LogLevel level, ColorScheme scheme) {
  switch (level) {
    case LogLevel.trace:
      return scheme.onSurfaceVariant;
    case LogLevel.debug:
      return scheme.onSurfaceVariant;
    case LogLevel.info:
      return scheme.primary;
    case LogLevel.warning:
      return scheme.tertiary;
    case LogLevel.error:
    case LogLevel.critical:
      return scheme.error;
  }
}

int _compareComparable(Comparable<Object?>? a, Comparable<Object?>? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

String _formatTimestamp(DateTime timestamp) {
  return '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.maxExpandedHeight,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;
  final double? maxExpandedHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final expandedBody = maxExpandedHeight == null
        ? child
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxExpandedHeight!),
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.primary,
                ),
                SizedBox(width: spacing.xs),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: EdgeInsets.only(left: spacing.lg),
            child: expandedBody,
          ),
      ],
    );
  }
}

enum _PerfWindow {
  last30s('Last 30s', Duration(seconds: 30)),
  last2m('Last 2m', Duration(minutes: 2)),
  last10m('Last 10m', Duration(minutes: 10)),
  all('All', null);

  const _PerfWindow(this.label, this.duration);
  final String label;
  final Duration? duration;
}

class _PerfMetricKey {
  const _PerfMetricKey({required this.source, required this.metric});

  final String source;
  final String metric;

  @override
  bool operator ==(Object other) {
    return other is _PerfMetricKey &&
        other.source == source &&
        other.metric == metric;
  }

  @override
  int get hashCode => Object.hash(source, metric);
}

class _PerformancePanel extends StatefulWidget {
  const _PerformancePanel({required this.debugEnabled});

  final bool debugEnabled;

  @override
  State<_PerformancePanel> createState() => _PerformancePanelState();
}

class _PerformancePanelState extends State<_PerformancePanel> {
  _PerfWindow _window = _PerfWindow.last2m;
  final Set<String> _selectedSources = <String>{};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLogger.performanceLog,
      builder: (context, _) {
        final spacing = context.appTheme.spacing;
        final samples = AppLogger.performanceLog.samples;
        if (samples.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.xl),
              child: Text(
                widget.debugEnabled
                    ? 'No performance metrics captured yet.'
                    : 'Enable Debug Mode and interact with migration widgets to capture performance metrics.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final sources = samples.map((sample) => sample.source).toSet().toList()
          ..sort();
        if (_selectedSources.isEmpty) {
          _selectedSources.addAll(sources);
        } else {
          _selectedSources.removeWhere((source) => !sources.contains(source));
          if (_selectedSources.isEmpty) {
            _selectedSources.addAll(sources);
          }
        }

        final now = DateTime.now();
        final cutoff = _window.duration == null
            ? null
            : now.subtract(_window.duration!);
        final filtered = samples.where((sample) {
          final sourceAllowed = _selectedSources.contains(sample.source);
          final timeAllowed =
              cutoff == null || !sample.timestamp.isBefore(cutoff);
          return sourceAllowed && timeAllowed;
        }).toList();

        final grouped = <_PerfMetricKey, List<PerformanceMetricSample>>{};
        for (final sample in filtered) {
          final key = _PerfMetricKey(
            source: sample.source,
            metric: sample.metric,
          );
          grouped
              .putIfAbsent(key, () => <PerformanceMetricSample>[])
              .add(sample);
        }
        final metricKeys = grouped.keys.toList()
          ..sort((a, b) {
            final bySource = a.source.compareTo(b.source);
            if (bySource != 0) {
              return bySource;
            }
            return a.metric.compareTo(b.metric);
          });

        return Column(
          children: [
            Padding(
              padding: spacing.inset(horizontal: 3, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.debugEnabled
                            ? Icons.speed
                            : Icons.speed_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: spacing.sm),
                      Text(
                        'Samples: ${samples.length}  Filtered: ${filtered.length}  Metrics: ${metricKeys.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const Spacer(),
                      DropdownButton<_PerfWindow>(
                        value: _window,
                        items: _PerfWindow.values
                            .map(
                              (window) => DropdownMenuItem<_PerfWindow>(
                                value: window,
                                child: Text(window.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _window = value;
                          });
                        },
                      ),
                      SizedBox(width: spacing.sm),
                      TextButton.icon(
                        onPressed: AppLogger.performanceLog.clear,
                        icon: const Icon(Icons.delete_outlined),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.sm),
                  Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.xs,
                    children: sources
                        .map(
                          (source) => FilterChip(
                            label: Text(source),
                            selected: _selectedSources.contains(source),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSources.add(source);
                                } else if (_selectedSources.length > 1) {
                                  _selectedSources.remove(source);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: metricKeys.isEmpty
                  ? const Center(
                      child: Text('No metrics in selected window/filter.'),
                    )
                  : ListView.separated(
                      padding: spacing.inset(horizontal: 3, vertical: 3),
                      itemCount: metricKeys.length,
                      separatorBuilder: (_, separatorIndex) =>
                          SizedBox(height: spacing.md),
                      itemBuilder: (context, index) {
                        final key = metricKeys[index];
                        final series = grouped[key]!;
                        final values = series
                            .map((sample) => sample.value)
                            .toList();
                        return _MetricCard(
                          title: _metricTitle(key.metric),
                          subtitle: '${key.source}.${key.metric}',
                          samples: values,
                          firstTimestamp: series.first.timestamp,
                          lastTimestamp: series.last.timestamp,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _metricTitle(String metric) {
    switch (metric) {
      case 'drag_events_per_sec':
        return 'Editor drag events/sec';
      case 'drag_flushes_per_sec':
        return 'Editor drag flushes/sec';
      case 'wheel_events_per_sec':
        return 'Terminal wheel events/sec';
      case 'wheel_rows_per_sec':
        return 'Terminal wheel rows/sec';
      default:
        return metric.replaceAll('_', ' ');
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.samples,
    required this.firstTimestamp,
    required this.lastTimestamp,
  });

  final String title;
  final String subtitle;
  final List<double> samples;
  final DateTime firstTimestamp;
  final DateTime lastTimestamp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final current = samples.isEmpty ? 0.0 : samples.last;
    final max = samples.isEmpty ? 0.0 : samples.reduce((a, b) => a > b ? a : b);
    final avg = samples.isEmpty
        ? 0.0
        : samples.reduce((a, b) => a + b) / samples.length;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: spacing.inset(horizontal: 3, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: spacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          SizedBox(height: spacing.sm),
          SizedBox(
            height: 84,
            child: samples.isEmpty
                ? const Center(child: Text('No data'))
                : CustomPaint(
                    painter: _SparklinePainter(
                      values: samples,
                      color: scheme.primary,
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.xs,
            children: [
              Text('current: ${current.toStringAsFixed(1)}'),
              Text('avg: ${avg.toStringAsFixed(1)}'),
              Text('max: ${max.toStringAsFixed(1)}'),
              Text('samples: ${samples.length}'),
              Text(
                '${_formatTimestamp(firstTimestamp)} → ${_formatTimestamp(lastTimestamp)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    if (values.isEmpty) {
      return;
    }
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;
    final step = values.length <= 1 ? 0.0 : size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final t = (values[i] - minValue) / span;
      final y = size.height - (t * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    if (oldDelegate.color != color ||
        oldDelegate.values.length != values.length) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }
    return false;
  }
}
