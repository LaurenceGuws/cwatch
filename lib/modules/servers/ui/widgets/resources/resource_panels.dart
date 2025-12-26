import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'resource_models.dart';
import 'resource_widgets.dart';

/// CPU panel widget
class CpuPanel extends StatelessWidget {
  const CpuPanel({super.key, required this.snapshot, required this.cpuHistory});

  final ResourceSnapshot snapshot;
  final List<double> cpuHistory;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'CPU',
      subtitle:
          'Load: ${snapshot.load1.toStringAsFixed(2)} (1m) · '
          '${snapshot.load5.toStringAsFixed(2)} (5m) · '
          '${snapshot.load15.toStringAsFixed(2)} (15m)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GaugeRow(
            label: 'Usage',
            percent: snapshot.cpuUsage / 100,
            value: '${snapshot.cpuUsage.toStringAsFixed(1)}%',
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            height: 100,
            child: SparklineChart(
              data: cpuHistory.isEmpty ? [snapshot.cpuUsage] : cpuHistory,
              color: scheme.primary,
              label: 'CPU %',
            ),
          ),
        ],
      ),
    );
  }
}

/// Memory panel widget
class MemoryPanel extends StatelessWidget {
  const MemoryPanel({
    super.key,
    required this.snapshot,
    required this.memoryHistory,
  });

  final ResourceSnapshot snapshot;
  final List<double> memoryHistory;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Memory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GaugeRow(
            label: 'Memory',
            percent: snapshot.memoryUsedPct / 100,
            value:
                '${snapshot.memoryUsedGb.toStringAsFixed(1)} / ${snapshot.memoryTotalGb.toStringAsFixed(1)} GB',
          ),
          SizedBox(height: spacing.sm),
          GaugeRow(
            label: 'Swap',
            percent: snapshot.swapUsedPct.isNaN
                ? 0
                : snapshot.swapUsedPct / 100,
            value: snapshot.swapTotalGb <= 0
                ? 'No swap'
                : '${snapshot.swapUsedGb.toStringAsFixed(1)} / ${snapshot.swapTotalGb.toStringAsFixed(1)} GB',
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            height: 100,
            child: SparklineChart(
              data: memoryHistory.isEmpty
                  ? [snapshot.memoryUsedPct]
                  : memoryHistory,
              color: scheme.secondary,
              label: 'Memory %',
            ),
          ),
        ],
      ),
    );
  }
}

/// Network panel widget
class NetworkPanel extends StatelessWidget {
  const NetworkPanel({
    super.key,
    required this.snapshot,
    required this.netInHistory,
    required this.netOutHistory,
  });

  final ResourceSnapshot snapshot;
  final List<double> netInHistory;
  final List<double> netOutHistory;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Network IO',
      subtitle:
          'Inbound ${snapshot.netInMbps.toStringAsFixed(2)} Mbps · Outbound ${snapshot.netOutMbps.toStringAsFixed(2)} Mbps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: SparklineChart(
              data: netInHistory.isEmpty ? [snapshot.netInMbps] : netInHistory,
              color: scheme.tertiary,
              normalize: false,
              label: 'Inbound Mbps',
            ),
          ),
          SizedBox(height: spacing.lg),
          SizedBox(
            height: 120,
            child: SparklineChart(
              data: netOutHistory.isEmpty
                  ? [snapshot.netOutMbps]
                  : netOutHistory,
              color: scheme.primary,
              normalize: false,
              label: 'Outbound Mbps',
            ),
          ),
        ],
      ),
    );
  }
}

/// Disks panel widget
class DisksPanel extends StatelessWidget {
  const DisksPanel({
    super.key,
    required this.snapshot,
    required this.diskIoHistory,
  });

  final ResourceSnapshot snapshot;
  final List<double> diskIoHistory;

  @override
  Widget build(BuildContext context) {
    final disks = snapshot.disks;
    if (disks.isEmpty) {
      return const SectionCard(
        title: 'Disks',
        child: Text('No disks detected'),
      );
    }
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final ioChart = diskIoHistory.length < 2
        ? null
        : SizedBox(
            height: 140,
            child: SparklineChart(
              data: diskIoHistory,
              color: scheme.tertiary,
              normalize: false,
              label: 'Disk IO Mbps',
            ),
          );
    return SectionCard(
      title: 'Disks',
      subtitle: 'Aggregate IO throughput and per-device usage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ioChart != null) ...[ioChart, SizedBox(height: spacing.md)],
          Column(
            children: disks.map((disk) => DiskUsageCard(disk: disk)).toList(),
          ),
        ],
      ),
    );
  }
}
