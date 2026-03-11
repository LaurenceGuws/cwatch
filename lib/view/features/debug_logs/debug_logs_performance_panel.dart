import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

class DebugLogsPerformancePanel extends StatefulWidget {
  const DebugLogsPerformancePanel({super.key, required this.debugEnabled});

  final bool debugEnabled;

  @override
  State<DebugLogsPerformancePanel> createState() =>
      _DebugLogsPerformancePanelState();
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

class _DebugLogsPerformancePanelState
    extends State<DebugLogsPerformancePanel> {
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
                    : 'Enable Debug Mode and interact with widgets to capture performance metrics.',
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
                '${_formatTimestamp(firstTimestamp)} -> ${_formatTimestamp(lastTimestamp)}',
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

String _formatTimestamp(DateTime timestamp) {
  return '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
}
