import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import 'resource_models.dart';

/// Card wrapper for resource sections
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Card(
      elevation: surface.elevation,
      margin: surface.margin,
      shape: RoundedRectangleBorder(borderRadius: surface.radius),
      child: Container(
        decoration: BoxDecoration(
          color: surface.background,
          borderRadius: surface.radius,
          border: Border.all(color: surface.borderColor),
        ),
        padding: surface.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: spacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Gauge row widget for displaying percentage metrics
class GaugeRow extends StatelessWidget {
  const GaugeRow({
    super.key,
    required this.label,
    required this.percent,
    required this.value,
  });

  final String label;
  final double percent;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

/// Disk usage card widget
class DiskUsageCard extends StatelessWidget {
  const DiskUsageCard({super.key, required this.disk});

  final DiskUsage disk;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            disk.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          UsedFreeBar(
            usedFraction: disk.usedPct / 100,
            usedColor: color,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${disk.usedGb.toStringAsFixed(1)} GB used'),
              Text('${disk.freeGb.toStringAsFixed(1)} GB free'),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              IoMetric(
                label: 'Read',
                value: '${disk.readMbps.toStringAsFixed(1)} Mbps',
                icon: Icons.download,
              ),
              SizedBox(width: spacing.sm),
              IoMetric(
                label: 'Write',
                value: '${disk.writeMbps.toStringAsFixed(1)} Mbps',
                icon: Icons.upload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Used/free bar widget
class UsedFreeBar extends StatelessWidget {
  const UsedFreeBar({
    super.key,
    required this.usedFraction,
    required this.usedColor,
  });

  final double usedFraction;
  final Color usedColor;

  @override
  Widget build(BuildContext context) {
    final fraction = usedFraction.clamp(0.0, 1.0);
    return Stack(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: usedColor.withValues(alpha: 0.15),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: usedColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// IO metric widget
class IoMetric extends StatelessWidget {
  const IoMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sparkline chart widget
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.data,
    required this.color,
    this.normalize = true,
    this.label,
  });

  final List<double> data;
  final Color color;
  final bool normalize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const SizedBox.expand();
    }
    late final List<double> values;
    late final double minY;
    late final double maxY;
    if (normalize) {
      values = data.map((value) => value.clamp(0, 100).toDouble()).toList();
      minY = 0;
      maxY = 100;
    } else {
      final minValue = data.reduce(min);
      final maxValue = data.reduce(max);
      final padding = (maxValue - minValue).abs() * 0.2;
      final adjustedMin = minValue - padding;
      final adjustedMax = maxValue + padding;
      if (adjustedMin == adjustedMax) {
        minY = adjustedMin - 1;
        maxY = adjustedMax + 1;
      } else {
        minY = adjustedMin;
        maxY = adjustedMax;
      }
      values = data;
    }
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].toDouble()),
    ];
    final minValue = values.reduce(min);
    final maxValue = values.reduce(max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: max(spots.last.x, 1),
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'min ${minValue.toStringAsFixed(2)} · max ${maxValue.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

