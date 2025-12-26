import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/services/logging/app_logger.dart';

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
  String? _error;
  _NetSample? _lastNetSample;

  static const int _historyCapacity = 16;
  static const Duration _historyWindow = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    AppLogger.d(
      'Loading connectivity stats for ${widget.host.name}',
      tag: 'Connectivity',
    );
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final infoColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connectivity', style: typography.sectionTitle),
                Text(widget.host.hostname, style: typography.caption),
              ],
            );

            final actionButtons = Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              alignment: WrapAlignment.end,
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
                    _refreshing
                        ? NerdIcon.settings.data
                        : NerdIcon.refresh.data,
                  ),
                  label: Text(_refreshing ? 'Refreshing…' : 'Manual refresh'),
                ),
              ],
            );

            if (constraints.maxWidth < 540) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoColumn,
                  SizedBox(height: spacing.sm),
                  actionButtons,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: infoColumn),
                SizedBox(width: spacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: actionButtons,
                ),
              ],
            );
          },
        ),
        SizedBox(height: spacing.md),
        if (_error != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: spacing.all(2),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_loading)
          Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.base * 8),
              child: const CircularProgressIndicator(),
            ),
          )
        else
          Column(
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
    );
  }

  Widget _buildStatGrid(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final series = _seriesWindow();
    final stats = [
      _StatDisplay(
        label: 'Latency',
        value: '${_stats.latencyMs.toStringAsFixed(1)} ms',
        trend: _stats.latencyTrend,
        icon: NerdIcon.accessPoint.data,
        color: scheme.primary,
        sparkline: series.latency,
      ),
      _StatDisplay(
        label: 'Jitter',
        value: '${_stats.jitterMs.toStringAsFixed(1)} ms',
        trend: _stats.jitterTrend,
        icon: NerdIcon.fileCode.data,
        color: scheme.secondary,
        sparkline: series.jitter,
      ),
      _StatDisplay(
        label: 'Packet loss',
        value: '${_stats.packetLossPct.toStringAsFixed(2)} %',
        trend: _stats.packetLossTrend,
        icon: NerdIcon.alert.data,
        color: scheme.error,
        sparkline: series.packetLoss,
      ),
      _StatDisplay(
        label: 'Throughput',
        value: '${_stats.throughputMbps.toStringAsFixed(1)} Mbps',
        trend: _stats.throughputTrend,
        icon: NerdIcon.servers.data,
        color: scheme.tertiary,
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final first = await _collectStats();
      if (!mounted) return;
      setState(() {
        _stats = first;
        _history
          ..clear()
          ..add(first);
        _loading = false;
      });
      AppLogger.d(
        'Initial connectivity stats loaded for ${widget.host.name}',
        tag: 'Connectivity',
      );
      _startStreaming();
    } catch (error) {
      AppLogger.w(
        'Failed to load connectivity stats for ${widget.host.name}',
        tag: 'Connectivity',
        error: error,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refreshStats() async {
    if (_loading) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final next = await _collectStats();
      if (!mounted) return;
      setState(() {
        _stats = next;
        _pushHistory(next);
        _refreshing = false;
      });
      AppLogger.d(
        'Connectivity stats refreshed for ${widget.host.name}',
        tag: 'Connectivity',
      );
    } catch (error) {
      AppLogger.w(
        'Refresh failed for ${widget.host.name}',
        tag: 'Connectivity',
        error: error,
      );
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = error.toString();
      });
    }
  }

  Future<ConnectivityStats> _collectStats() async {
    final previous = _history.isNotEmpty ? _history.last : null;
    final pingResult = await _PingProbe.collect(widget.host.hostname);
    final uptime = await _readRemoteUptime();
    final netSample = await _readNetSample();
    final throughput = _calculateThroughput(netSample);
    final availability = (100 - pingResult.packetLossPct).clamp(0, 100);

    return ConnectivityStats(
      latencyMs: pingResult.latencyMs,
      jitterMs: pingResult.jitterMs,
      packetLossPct: pingResult.packetLossPct,
      throughputMbps: throughput,
      uptime: uptime ?? Duration.zero,
      availability: '${availability.toStringAsFixed(2)} %',
      timestamp: DateTime.now(),
      latencyTrend: _compareTrend(pingResult.latencyMs, previous?.latencyMs),
      jitterTrend: _compareTrend(pingResult.jitterMs, previous?.jitterMs),
      packetLossTrend: _compareTrend(
        pingResult.packetLossPct,
        previous?.packetLossPct,
      ),
      throughputTrend: _compareTrend(throughput, previous?.throughputMbps),
    );
  }

  double _calculateThroughput(_NetSample? sample) {
    double throughput = 0;
    if (sample != null && _lastNetSample != null) {
      final deltaBytes = sample.totalBytes - _lastNetSample!.totalBytes;
      final elapsed =
          sample.timestamp
              .difference(_lastNetSample!.timestamp)
              .inMilliseconds /
          1000;
      if (deltaBytes > 0 && elapsed > 0) {
        throughput = (deltaBytes * 8 / elapsed) / 1e6;
      }
    }
    if (sample != null) {
      _lastNetSample = sample;
    }
    return throughput;
  }

  Future<Duration?> _readRemoteUptime() async {
    final output = await _runSshCommand('cat /proc/uptime');
    if (output == null || output.isEmpty) {
      return null;
    }
    final parts = output.split(RegExp(r'\s+'));
    final seconds = double.tryParse(parts.first);
    if (seconds == null) {
      return null;
    }
    return Duration(seconds: seconds.floor());
  }

  Future<_NetSample?> _readNetSample() async {
    final output = await _runSshCommand('cat /proc/net/dev');
    if (output == null) {
      return null;
    }
    final lines = const LineSplitter().convert(output);
    var totalBytes = 0;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.contains(':')) continue;
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final interfaceName = parts.first.trim();
      if (interfaceName.isEmpty || interfaceName == 'lo') continue;
      final metrics = parts[1].trim().split(RegExp(r'\s+'));
      if (metrics.length < 16) continue;
      final rxBytes = int.tryParse(metrics[0]) ?? 0;
      final txBytes = int.tryParse(metrics[8]) ?? 0;
      totalBytes += rxBytes + txBytes;
    }
    if (totalBytes <= 0) {
      return null;
    }
    return _NetSample(totalBytes, DateTime.now());
  }

  Future<String?> _runSshCommand(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final result = await Process.run(
        'ssh',
        [
          '-o',
          'BatchMode=yes',
          '-o',
          'StrictHostKeyChecking=no',
          widget.host.name,
          command,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);
      if (result.exitCode != 0) {
        return null;
      }
      final output = (result.stdout as String?)?.trim();
      return (output == null || output.isEmpty) ? null : output;
    } catch (_) {
      return null;
    }
  }

  TrendDirection _compareTrend(double current, double? previous) {
    if (previous == null) {
      return TrendDirection.flat;
    }
    final delta = current - previous;
    if (delta.abs() < 0.1) {
      return TrendDirection.flat;
    }
    return delta > 0 ? TrendDirection.up : TrendDirection.down;
  }

  void _startStreaming() {
    _streamTimer?.cancel();
    if (!_streaming) {
      return;
    }
    _streamTimer = Timer.periodic(
      const Duration(seconds: 6),
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

  Future<void> _tickStream() async {
    if (!mounted || !_streaming) return;
    try {
      final next = await _collectStats();
      if (!mounted) return;
      setState(() {
        _stats = next;
        _pushHistory(next);
        _error = null;
      });
    } catch (error) {
      AppLogger.w(
        'Streaming tick failed for ${widget.host.name}',
        tag: 'Connectivity',
        error: error,
      );
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  void _pushHistory(ConnectivityStats stat) {
    if (_history.length >= _historyCapacity) {
      _history.removeAt(0);
    }
    _history.add(stat);
    final cutoff = DateTime.now().subtract(_historyWindow);
    _history.removeWhere((sample) => sample.timestamp.isBefore(cutoff));
  }

  _SeriesWindow _seriesWindow() {
    final samples = _history.isNotEmpty ? _history : [_stats];
    List<double> mapValues(double Function(ConnectivityStats) pick) =>
        samples.map(pick).toList();
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
        padding: spacing.all(0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    display.icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        display.label,
                        style: appTheme.typography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        display.value,
                        style: typography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                padding: EdgeInsets.only(top: spacing.xs),
                child: SizedBox(
                  height: 28,
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
      TrendDirection.up => colorScheme.error,
      TrendDirection.down => colorScheme.primary,
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
    final minValue = data.reduce(min);
    final maxValue = data.reduce(max);
    final range = (maxValue - minValue).abs();
    final normalized = <double>[
      for (final value in data)
        range == 0 ? 50 : ((value - minValue) / range) * 100,
    ];
    final spots = <FlSpot>[
      for (var i = 0; i < normalized.length; i++)
        FlSpot(i.toDouble(), normalized[i]),
    ];
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(spots.last.x, 1),
        minY: 0,
        maxY: 100,
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
  const ConnectivityStats({
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
    final minutes = uptime.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedTimestamp {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

enum TrendDirection { up, down, flat }

class _NetSample {
  const _NetSample(this.totalBytes, this.timestamp);

  final int totalBytes;
  final DateTime timestamp;
}

class _PingProbe {
  const _PingProbe({
    required this.latencyMs,
    required this.jitterMs,
    required this.packetLossPct,
  });

  final double latencyMs;
  final double jitterMs;
  final double packetLossPct;

  static Future<_PingProbe> collect(String host) async {
    final result = await Process.run(
      'ping',
      ['-c', '5', host],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    );

    final output = '${result.stdout}${result.stderr}';
    if (result.exitCode != 0 && output.isEmpty) {
      throw Exception('Ping failed (${result.exitCode}).');
    }

    final responseTimes = <double>[];
    double? avgLatency;
    double? jitter;
    double? packetLoss;

    final lines = const LineSplitter().convert(output);
    for (final line in lines) {
      final timeMatch = RegExp(r'time[=<]([\d\.]+)\s*ms').firstMatch(line);
      if (timeMatch != null) {
        responseTimes.add(double.tryParse(timeMatch.group(1) ?? '') ?? 0);
      }
      final lossMatch = RegExp(r'([\d\.]+)% packet loss').firstMatch(line);
      if (lossMatch != null) {
        packetLoss = double.tryParse(lossMatch.group(1)!);
      }
      final rttMatch = RegExp(
        r'=\s*([\d\.]+)/([\d\.]+)/([\d\.]+)/([\d\.]+)',
      ).firstMatch(line);
      if (rttMatch != null) {
        avgLatency = double.tryParse(rttMatch.group(2)!);
        jitter = double.tryParse(rttMatch.group(4)!);
      }
    }

    avgLatency ??= responseTimes.isNotEmpty
        ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
        : double.nan;

    jitter ??= _stdDev(responseTimes);
    packetLoss ??= _inferLoss(output);

    if (avgLatency.isNaN) {
      throw Exception('Ping returned no latency data.');
    }

    return _PingProbe(
      latencyMs: avgLatency,
      jitterMs: jitter.isNaN ? 0 : jitter,
      packetLossPct: packetLoss ?? 100,
    );
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) {
      return 0;
    }
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((value) => pow(value - mean, 2)).reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance);
  }

  static double? _inferLoss(String output) {
    final match = RegExp(
      r'(\d+)\s+packets transmitted,\s+(\d+)\s+received',
    ).firstMatch(output);
    if (match == null) return null;
    final transmitted = double.tryParse(match.group(1)!);
    final received = double.tryParse(match.group(2)!);
    if (transmitted == null || transmitted == 0 || received == null) {
      return null;
    }
    final lost = transmitted - received;
    return (lost / transmitted) * 100;
  }
}
