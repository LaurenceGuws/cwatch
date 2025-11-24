import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../models/docker_container_stat.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/docker/docker_client_service.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../theme/nerd_fonts.dart';
import '../../shared/engine_tab.dart';
import 'docker_command_terminal.dart';

class DockerResourcesDashboard extends StatefulWidget {
  const DockerResourcesDashboard({
    super.key,
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
    this.onOpenTab,
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final void Function(EngineTab tab)? onOpenTab;

  @override
  State<DockerResourcesDashboard> createState() => _DockerResourcesDashboardState();
}

class _DockerResourcesDashboardState extends State<DockerResourcesDashboard> {
  Timer? _poller;
  bool _loading = true;
  String? _error;
  List<DockerContainerStat> _stats = const [];
  final List<double> _totalCpuHistory = [];
  final List<double> _totalMemHistory = [];
  final List<double> _avgCpuHistory = [];
  final List<double> _avgMemHistory = [];
  final List<double> _containerCountHistory = [];
  final Map<String, List<double>> _cpuHistoryByContainer = {};
  final Map<String, List<double>> _memHistoryByContainer = {};
  static const _historyLimit = 60;

  @override
  void initState() {
    super.initState();
    _refreshStats(initial: true);
    _startPolling();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshStats();
    });
  }

  Future<List<DockerContainerStat>> _load() async {
    if (widget.remoteHost != null && widget.shellService != null) {
      final output = await widget.shellService!.runCommand(
        widget.remoteHost!,
        "docker stats --no-stream --format '{{json .}}'",
        timeout: const Duration(seconds: 8),
      );
      return _parseStats(output);
    }
    return widget.docker.listContainerStats(context: widget.contextName);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contextName ?? widget.remoteHost?.name ?? 'Resources';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Resources • $title',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Open `docker stats`',
                icon: Icon(NerdIcon.terminal.data),
                onPressed: _openStatsTab,
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => _refreshStats(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Failed to load stats: $_error'))
                    : _stats.isEmpty
                        ? const Center(child: Text('No container stats found.'))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;
                              final cardWidth = isWide
                                  ? (constraints.maxWidth - 24) / 2
                                  : constraints.maxWidth;
                              return ListView(
                                children: [
                                  _buildCharts(cardWidth),
                                  const SizedBox(height: 12),
                                  _buildSummary(_stats, cardWidth),
                                  const SizedBox(height: 16),
                                  _buildContainerTable(cardWidth),
                                ],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<DockerContainerStat> stats, double maxCardWidth) {
    final cpuValues = stats.map(_cpuPercent).whereType<double>().toList();
    final memValues = stats.map(_memPercent).whereType<double>().toList();
    final totalCpu = cpuValues.fold<double>(0, (a, b) => a + b);
    final totalMem = memValues.fold<double>(0, (a, b) => a + b);
    final topCpu = _topBy(stats, _cpuPercent);
    final topMem = _topBy(stats, _memPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resource usage',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryCard(
              'CPU (total)',
              '${totalCpu.toStringAsFixed(1)}%',
              history: _totalCpuHistory,
              color: Theme.of(context).colorScheme.primary,
              maxWidth: maxCardWidth,
            ),
            _summaryCard(
              'Memory (total)',
              '${totalMem.toStringAsFixed(1)}%',
              history: _totalMemHistory,
              color: Colors.teal,
              maxWidth: maxCardWidth,
            ),
            if (topCpu != null)
              _summaryCard(
                'Top CPU',
                '${_nameOf(topCpu)} (${topCpu.cpu})',
                maxWidth: maxCardWidth,
              ),
            if (topMem != null)
              _summaryCard(
                'Top Mem',
                '${_nameOf(topMem)} (${topMem.memPercent})',
                maxWidth: maxCardWidth,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharts(double maxCardWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resource trends',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _lineChartCard(
              title: 'CPU vs Memory',
              subtitle: 'Totals over time',
              series: [
                _LineSeries(
                  label: 'CPU %',
                  values: _totalCpuHistory,
                  color: Theme.of(context).colorScheme.primary,
                ),
                _LineSeries(
                  label: 'Mem %',
                  values: _totalMemHistory,
                  color: Colors.teal,
                ),
              ],
              maxWidth: maxCardWidth,
            ),
            _lineChartCard(
              title: 'CPU by container',
              subtitle: 'Each container as its own series',
              series: _seriesFromMap(_cpuHistoryByContainer),
              maxWidth: maxCardWidth,
            ),
            _lineChartCard(
              title: 'Memory by container',
              subtitle: 'Each container as its own series',
              series: _seriesFromMap(_memHistoryByContainer),
              maxWidth: maxCardWidth,
            ),
            _lineChartCard(
              title: 'Per-container averages',
              subtitle: 'Averages with container count overlay',
              series: [
                _LineSeries(
                  label: 'CPU avg %',
                  values: _avgCpuHistory,
                  color: Colors.orange,
                ),
                _LineSeries(
                  label: 'Mem avg %',
                  values: _avgMemHistory,
                  color: Colors.purple,
                ),
                _LineSeries(
                  label: 'Containers',
                  values: _containerCountHistory,
                  color: Colors.blueGrey,
                ),
              ],
              maxWidth: maxCardWidth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(
    String label,
    String value, {
    List<double>? history,
    Color? color,
    double? maxWidth,
  }) {
    return SizedBox(
      width: maxWidth ?? 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (history != null && history.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Sparkline(
                  values: history,
                  color: color ?? Theme.of(context).colorScheme.primary,
                  height: 48,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContainerTable(double maxCardWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Container stats',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: maxCardWidth,
              ),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Container')),
                  DataColumn(label: Text('CPU')),
                  DataColumn(label: Text('Mem')),
                  DataColumn(label: Text('Net I/O')),
                  DataColumn(label: Text('Block I/O')),
                  DataColumn(label: Text('PIDs')),
                ],
                rows: _stats
                    .map(
                      (stat) => DataRow(
                        cells: [
                          DataCell(Text(_nameOf(stat))),
                          DataCell(Text(stat.cpu)),
                          DataCell(Text('${stat.memUsage} (${stat.memPercent})')),
                          DataCell(Text(stat.netIO)),
                          DataCell(Text(stat.blockIO)),
                          DataCell(Text(stat.pids)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _nameOf(DockerContainerStat stat) =>
      stat.name.isNotEmpty ? stat.name : stat.id;

  double? _cpuPercent(DockerContainerStat stat) {
    final value = stat.cpu.replaceAll('%', '');
    return double.tryParse(value);
  }

  double? _memPercent(DockerContainerStat stat) {
    final value = stat.memPercent.replaceAll('%', '');
    return double.tryParse(value);
  }

  DockerContainerStat? _topBy(
    List<DockerContainerStat> stats,
    double? Function(DockerContainerStat) picker,
  ) {
    DockerContainerStat? best;
    double bestValue = -1;
    for (final s in stats) {
      final v = picker(s);
      if (v != null && v > bestValue) {
        bestValue = v;
        best = s;
      }
    }
    return best;
  }

  List<DockerContainerStat> _parseStats(String output) {
    final items = <DockerContainerStat>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(
            DockerContainerStat(
              id: (decoded['Container'] as String?)?.trim() ?? '',
              name: (decoded['Name'] as String?)?.trim() ?? '',
              cpu: (decoded['CPUPerc'] as String?)?.trim() ?? '',
              memUsage: (decoded['MemUsage'] as String?)?.trim() ?? '',
              memPercent: (decoded['MemPerc'] as String?)?.trim() ?? '',
              netIO: (decoded['NetIO'] as String?)?.trim() ?? '',
              blockIO: (decoded['BlockIO'] as String?)?.trim() ?? '',
              pids: (decoded['PIDs'] as String?)?.trim() ?? '',
            ),
          );
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  void _openStatsTab() {
    if (widget.onOpenTab == null) return;
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
            ? '--context ${widget.contextName!} '
            : '';
    final command = 'docker ${contextFlag}stats --no-stream --format "{{json .}}"';
    widget.onOpenTab!(
      EngineTab(
        id: 'dstat-${DateTime.now().microsecondsSinceEpoch}',
        title: 'docker stats',
        label: 'docker stats',
        icon: NerdIcon.terminal.data,
        body: DockerCommandTerminal(
          command: command,
          title: 'docker stats',
          host: widget.remoteHost,
          shellService: widget.shellService,
        ),
        canDrag: true,
      ),
    );
  }

  Future<void> _refreshStats({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stats = await _load();
      final totalCpu = stats
          .map(_cpuPercent)
          .whereType<double>()
          .fold<double>(0, (a, b) => a + b);
      final totalMem = stats
          .map(_memPercent)
          .whereType<double>()
          .fold<double>(0, (a, b) => a + b);
      setState(() {
        _stats = stats;
        _error = null;
        _loading = false;
        _appendHistory(_totalCpuHistory, totalCpu);
        _appendHistory(_totalMemHistory, totalMem);
        _appendHistory(
          _avgCpuHistory,
          stats.isNotEmpty ? totalCpu / stats.length : 0,
        );
        _appendHistory(
          _avgMemHistory,
          stats.isNotEmpty ? totalMem / stats.length : 0,
        );
        _appendHistory(_containerCountHistory, stats.length.toDouble());
        for (final stat in stats) {
          final name = _nameOf(stat);
          _appendHistoryFor(
            _cpuHistoryByContainer,
            name,
            _cpuPercent(stat) ?? 0,
          );
          _appendHistoryFor(
            _memHistoryByContainer,
            name,
            _memPercent(stat) ?? 0,
          );
        }
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _appendHistory(List<double> list, double value) {
    list.add(value);
    if (list.length > _historyLimit) {
      list.removeAt(0);
    }
  }

  void _appendHistoryFor(
    Map<String, List<double>> map,
    String key,
    double value,
  ) {
    final list = map.putIfAbsent(key, () => <double>[]);
    list.add(value);
    if (list.length > _historyLimit) {
      list.removeAt(0);
    }
  }

  Widget _lineChartCard({
    required String title,
    required String subtitle,
    required List<_LineSeries> series,
    required double maxWidth,
  }) {
    final hasPoints = series.any((s) => s.values.isNotEmpty);
    return SizedBox(
      width: maxWidth,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: series
                    .map(
                      (s) => _ChartLegend(
                        label: s.label,
                        color: s.color,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: hasPoints
                    ? LineChart(
                        _lineChartData(series),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                    : const Center(child: Text('No history yet')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_LineSeries> _seriesFromMap(Map<String, List<double>> map) {
    final labels = map.keys.toList()..sort();
    return labels
        .map(
          (label) => _LineSeries(
            label: label,
            values: map[label] ?? const [],
            color: _colorForLabel(label),
          ),
        )
        .toList();
  }

  Color _colorForLabel(String label) {
    // Deterministic palette assignment so the same container keeps its color.
    const palette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.brown,
    ];
    final hash = label.hashCode;
    return palette[hash.abs() % palette.length];
  }

  LineChartData _lineChartData(List<_LineSeries> series) {
    final allValues = series.expand((s) => s.values).toList();
    final double maxY = allValues.isNotEmpty
        ? math.max(allValues.reduce(math.max) * 1.1, 10).toDouble()
        : 10;
    final double maxX = series
        .map((s) => (s.values.length - 1).toDouble())
        .fold<double>(0, math.max);
    return LineChartData(
      minY: 0,
      maxY: maxY,
      minX: 0,
      maxX: math.max(1, maxX),
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: math.max(1, maxX / 4),
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: maxY / 4,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideVertically: true,
          fitInsideHorizontally: true,
        ),
      ),
      lineBarsData: series
          .map(
            (s) => LineChartBarData(
              isCurved: true,
              preventCurveOverShooting: true,
              color: s.color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: s.color.withValues(alpha: 0.12),
              ),
              spots: _spotsOf(s.values),
            ),
          )
          .toList(),
    );
  }

  List<FlSpot> _spotsOf(List<double> values) {
    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    return spots;
  }
}

class _LineSeries {
  const _LineSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({
    required this.values,
    required this.color,
    this.height = 32.0,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color),
        size: Size.infinite,
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
    if (values.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).clamp(1e-3, double.infinity);
    final dx = values.length > 1
        ? size.width / (values.length - 1)
        : size.width;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length > 1 ? i * dx : 0.0;
      final norm = (values[i] - min) / range;
      final y = size.height - (norm * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
