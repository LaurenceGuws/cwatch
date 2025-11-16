import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';

class ConnectivityTab extends StatefulWidget {
  const ConnectivityTab({super.key, required this.host});

  final SshHost host;

  @override
  State<ConnectivityTab> createState() => _ConnectivityTabState();
}

class _ConnectivityTabState extends State<ConnectivityTab> {
  late ConnectivityStats _stats;
  final List<ConnectivityStats> _history = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _streaming = true;
  Timer? _streamTimer;
  static const int _historyCapacity = 16;
  static const Duration _historyWindow = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;
    final typography = appTheme.typography;
    return SingleChildScrollView(
      padding: spacing.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connectivity', style: typography.sectionTitle),
                  Text(widget.host.hostname, style: typography.caption),
                ],
              ),
              Wrap(
                spacing: spacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _toggleStreaming,
                    icon: Icon(
                      _streaming
                          ? NerdIcon.accessPoint.data
                          : NerdIcon.servers.data,
                    ),
                    label: Text(_streaming ? 'Pause stream' : 'Resume stream'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _refreshStats,
                    icon: Icon(
                      _refreshing ? NerdIcon.settings.data : NerdIcon.refresh.data,
                    ),
                    label: Text(
                      _refreshing ? 'Refreshing...' : 'Manual refresh',
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last updated ${_stats.formattedTimestamp}',
                      style: typography.caption,
                    ),
                    SizedBox(height: spacing.md),
                    _buildStatGrid(context),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;
    final series = _seriesWindow();
    final stats = [
      _StatDisplay(
        label: 'Latency',
        value: '${_stats.latencyMs.toStringAsFixed(1)} ms',
        trend: _stats.latencyTrend,
        icon: NerdIcon.accessPoint.data,
        color: Colors.blueAccent,
        sparkline: series.latency,
      ),
      _StatDisplay(
        label: 'Jitter',
        value: '${_stats.jitterMs.toStringAsFixed(1)} ms',
        trend: _stats.jitterTrend,
        icon: NerdIcon.fileCode.data,
        color: Colors.purpleAccent,
        sparkline: series.jitter,
      ),
      _StatDisplay(
        label: 'Packet loss',
        value: '${_stats.packetLossPct.toStringAsFixed(2)} %',
        trend: _stats.packetLossTrend,
        icon: NerdIcon.alert.data,
        color: Colors.orangeAccent,
        sparkline: series.packetLoss,
      ),
      _StatDisplay(
        label: 'Throughput',
        value: '${_stats.throughputMbps.toStringAsFixed(1)} Mbps',
        trend: _stats.throughputTrend,
        icon: NerdIcon.servers.data,
        color: Colors.greenAccent,
        sparkline: series.throughput,
      ),
      _StatDisplay(
        label: 'Uptime',
        value: _stats.uptimeDisplay,
        trend: null,
        icon: NerdIcon.settings.data,
      ),
      _StatDisplay(
        label: 'Availability',
        value: _stats.availability,
        trend: null,
        icon: NerdIcon.checkCircle.data,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing.md,
            crossAxisSpacing: spacing.md,
            childAspectRatio: 3.0,
          ),
          itemBuilder: (context, index) => _StatCard(display: stats[index]),
        );
      },
    );
  }

  Future<void> _loadStats() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final first = ConnectivityStats.generate();
    setState(() {
      _stats = first;
      _history
        ..clear()
        ..add(first);
      _loading = false;
    });
    _startStreaming();
  }

  Future<void> _refreshStats() async {
    setState(() {
      _refreshing = true;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      final next = ConnectivityStats.generate(baseline: _stats);
      _stats = next;
      _pushHistory(next);
      _refreshing = false;
    });
  }

  void _startStreaming() {
    _streamTimer?.cancel();
    if (!_streaming) {
      return;
    }
    _streamTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _tickStream(),
    );
  }

  void _toggleStreaming() {
    setState(() {
      _streaming = !_streaming;
      if (_streaming) {
        _startStreaming();
      } else {
        _streamTimer?.cancel();
      }
    });
  }

  void _tickStream() {
    if (!mounted) return;
    setState(() {
      final next = ConnectivityStats.generate(baseline: _stats);
      _stats = next;
      _pushHistory(next);
    });
  }

  void _pushHistory(ConnectivityStats stat) {
    if (_history.length >= _historyCapacity) {
      _history.removeAt(0);
    }
    _history.add(stat);
    _history.removeWhere(
      (sample) => DateTime.now().difference(sample.timestamp) > _historyWindow,
    );
  }

  List<ConnectivityStats> _recentHistory() {
    final cutoff = DateTime.now().subtract(_historyWindow);
    return _history.where((stat) => stat.timestamp.isAfter(cutoff)).toList();
  }

  _SeriesWindow _seriesWindow() {
    final samples = _recentHistory();
    final source = samples.isNotEmpty ? samples : _history;
    List<double> mapValues(double Function(ConnectivityStats) pick) =>
        source.map(pick).toList();
    return _SeriesWindow(
      latency: mapValues((stat) => stat.latencyMs),
      jitter: mapValues((stat) => stat.jitterMs),
      packetLoss: mapValues((stat) => stat.packetLossPct),
      throughput: mapValues((stat) => stat.throughputMbps),
    );
  }
}

class _SeriesWindow {
  const _SeriesWindow({
    required this.latency,
    required this.jitter,
    required this.packetLoss,
    required this.throughput,
  });

  final List<double> latency;
  final List<double> jitter;
  final List<double> packetLoss;
  final List<double> throughput;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.display});

  final _StatDisplay display;

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;
    final typography = appTheme.typography;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: appTheme.section.cardRadius),
      child: Padding(
        padding: spacing.all(1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    display.icon,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(display.label, style: appTheme.typography.caption),
                      Text(
                        display.value,
                        style: typography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (display.trend != null)
                  _TrendIndicator(trend: display.trend!),
              ],
            ),
            if (display.sparkline != null && display.sparkline!.length >= 2)
              Padding(
                padding: EdgeInsets.only(top: spacing.sm),
                child: SizedBox(
                  height: 64,
                  child: _StatSparkline(
                    data: display.sparkline!,
                    color:
                        display.color ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatDisplay {
  const _StatDisplay({
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.sparkline,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final TrendDirection? trend;
  final List<double>? sparkline;
  final Color? color;
}

class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.trend});

  final TrendDirection trend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (trend) {
      TrendDirection.up => Colors.redAccent,
      TrendDirection.down => Colors.greenAccent,
      TrendDirection.flat => colorScheme.outline,
    };
    final icon = switch (trend) {
      TrendDirection.up => NerdIcon.alert.data,
      TrendDirection.down => NerdIcon.checkCircle.data,
      TrendDirection.flat => NerdIcon.fileCode.data,
    };
    return Row(children: [Icon(icon, color: color)]);
  }
}

class _StatSparkline extends StatelessWidget {
  const _StatSparkline({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const SizedBox.expand();
    }
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];
    final minValue = data.reduce(min);
    final maxValue = data.reduce(max);
    final padding = max(1, maxValue - minValue) * 0.2;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(spots.last.x, 1),
        minY: minValue - padding,
        maxY: maxValue + padding,
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
    );
  }
}

class ConnectivityStats {
  ConnectivityStats({
    required this.latencyMs,
    required this.jitterMs,
    required this.packetLossPct,
    required this.throughputMbps,
    required this.uptime,
    required this.availability,
    required this.timestamp,
    required this.latencyTrend,
    required this.jitterTrend,
    required this.packetLossTrend,
    required this.throughputTrend,
  });

  final double latencyMs;
  final double jitterMs;
  final double packetLossPct;
  final double throughputMbps;
  final Duration uptime;
  final String availability;
  final DateTime timestamp;
  final TrendDirection latencyTrend;
  final TrendDirection jitterTrend;
  final TrendDirection packetLossTrend;
  final TrendDirection throughputTrend;

  String get uptimeDisplay {
    final days = uptime.inDays;
    final hours = uptime.inHours % 24;
    return '${days}d ${hours}h';
  }

  String get formattedTimestamp =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  static ConnectivityStats generate({ConnectivityStats? baseline}) {
    final random = Random();
    double jitter(double base, [double variance = 5]) =>
        base + random.nextDouble() * variance - variance / 2;
    final latency = jitter(
      baseline?.latencyMs ?? 24,
      10,
    ).clamp(5, 120).toDouble();
    final jitterVal = jitter(
      baseline?.jitterMs ?? 3,
      6,
    ).clamp(0.2, 40).toDouble();
    final packet = (baseline?.packetLossPct ?? random.nextDouble())
        .clamp(0, 5)
        .toDouble();
    final throughput = jitter(
      baseline?.throughputMbps ?? 180,
      50,
    ).clamp(50, 500).toDouble();
    TrendDirection compare(double current, double previous) {
      if ((current - previous).abs() < 1) return TrendDirection.flat;
      return current > previous ? TrendDirection.up : TrendDirection.down;
    }

    return ConnectivityStats(
      latencyMs: latency,
      jitterMs: jitterVal,
      packetLossPct: packet,
      throughputMbps: throughput,
      uptime: Duration(days: 42, hours: random.nextInt(24)),
      availability: '${(99 + random.nextDouble()).toStringAsFixed(2)} %',
      timestamp: DateTime.now(),
      latencyTrend: compare(latency, baseline?.latencyMs ?? latency),
      jitterTrend: compare(jitterVal, baseline?.jitterMs ?? jitterVal),
      packetLossTrend: compare(packet, baseline?.packetLossPct ?? packet),
      throughputTrend: compare(
        throughput,
        baseline?.throughputMbps ?? throughput,
      ),
    );
  }
}

enum TrendDirection { up, down, flat }
