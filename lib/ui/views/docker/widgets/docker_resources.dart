import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../models/docker_container_stat.dart';
import '../../../../models/docker_workspace_state.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/docker/docker_client_service.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';
import '../../shared/tabs/tab_chip.dart';
import '../engine_tab.dart';
import 'docker_command_terminal.dart';

class DockerResources extends StatefulWidget {
  const DockerResources({
    super.key,
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
    this.onOpenTab,
    this.onCloseTab,
    this.optionsController,
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final void Function(EngineTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final TabOptionsController? optionsController;

  @override
  State<DockerResources> createState() => _DockerResourcesState();
}

class _DockerResourcesState extends State<DockerResources> {
  Timer? _poller;
  bool _loading = true;
  String? _error;
  List<DockerContainerStat> _stats = const [];
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  final Map<String, List<double>> _cpuHistoryByContainer = {};
  final Map<String, List<double>> _memPercentHistoryByContainer = {};
  final Map<String, List<double>> _memUsageHistoryByContainer = {};
  final Map<String, List<double>> _netIoHistoryByContainer = {};
  final Map<String, List<double>> _blockIoHistoryByContainer = {};
  static const _historyLimit = 60;
  AppIcons get _icons => context.appTheme.icons;
  AppDockerTokens get _dockerTheme => context.appTheme.docker;
  bool _tabOptionsRegistered = false;

  @override
  void initState() {
    super.initState();
    _refreshStats(initial: true);
    _startPolling();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerTabOptions();
  }

  void _registerTabOptions() {
    if (_tabOptionsRegistered || widget.optionsController == null) {
      return;
    }
    _tabOptionsRegistered = true;
    final icons = _icons;
    widget.optionsController!.update([
      TabChipOption(
        label: 'Open `docker stats`',
        icon: NerdIcon.terminal.data,
        onSelected: _openStatsTab,
      ),
      TabChipOption(
        label: 'Refresh',
        icon: icons.refresh,
        onSelected: _refreshStats,
      ),
    ]);
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
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      return ListView(
                        children: [
                          _buildCharts(constraints.maxWidth),
                          const SizedBox(height: 16),
                          _buildContainerTable(constraints.maxWidth),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharts(double maxCardWidth) {
    final memUsageScaled = _scaleForBytes(
      _seriesFromMap(_memUsageHistoryByContainer),
    );
    final netIoScaled = _scaleForBytes(
      _seriesFromMap(_netIoHistoryByContainer),
    );
    final blockIoScaled = _scaleForBytes(
      _seriesFromMap(_blockIoHistoryByContainer),
    );
    final charts = [
      (
        title: 'CPU %',
        subtitle: 'CPU percent by container',
        series: _seriesFromMap(_cpuHistoryByContainer),
        unit: null,
      ),
      (
        title: 'Memory %',
        subtitle: 'Memory percent by container',
        series: _seriesFromMap(_memPercentHistoryByContainer),
        unit: null,
      ),
      (
        title: 'Memory used',
        subtitle: 'Used memory by container (${memUsageScaled.unit})',
        series: memUsageScaled.series,
        unit: memUsageScaled.unit,
      ),
      (
        title: 'Net I/O',
        subtitle: 'Total network I/O by container (${netIoScaled.unit})',
        series: netIoScaled.series,
        unit: netIoScaled.unit,
      ),
      (
        title: 'Block I/O',
        subtitle: 'Total block I/O by container (${blockIoScaled.unit})',
        series: blockIoScaled.series,
        unit: blockIoScaled.unit,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resource trends', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...charts.map(
          (chart) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _lineChartCard(
              title: chart.title,
              subtitle: chart.subtitle,
              series: chart.series,
              maxWidth: maxCardWidth,
              unitSuffix: chart.unit,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContainerTable(double maxCardWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container stats', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: maxCardWidth),
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('Container'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('CPU'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Mem'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Net I/O'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Block I/O'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('PIDs'),
                    onSort: (index, ascending) => _sortStats(index, ascending),
                  ),
                ],
                rows: _stats
                    .map(
                      (stat) => DataRow(
                        cells: [
                          DataCell(Text(_nameOf(stat))),
                          DataCell(Text(stat.cpu)),
                          DataCell(
                            Text('${stat.memUsage} (${stat.memPercent})'),
                          ),
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

  void _sortStats(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applySort();
    });
  }

  void _applySort() {
    final comparator = _comparatorForColumn(_sortColumnIndex);
    _stats = [..._stats]
      ..sort((a, b) {
        final result = comparator(a, b);
        return _sortAscending ? result : -result;
      });
  }

  int Function(DockerContainerStat a, DockerContainerStat b)
  _comparatorForColumn(int column) {
    switch (column) {
      case 1:
        return (a, b) => _compareNum(_cpuPercent(a), _cpuPercent(b));
      case 2:
        return (a, b) => _compareNum(_memPercent(a), _memPercent(b));
      case 3:
        return (a, b) =>
            _compareNum(_parseBytePair(a.netIO), _parseBytePair(b.netIO));
      case 4:
        return (a, b) =>
            _compareNum(_parseBytePair(a.blockIO), _parseBytePair(b.blockIO));
      case 5:
        return (a, b) => _compareNum(_parsePid(a.pids), _parsePid(b.pids));
      case 0:
      default:
        return (a, b) =>
            _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase());
    }
  }

  int _compareNum(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
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
    final command =
        'docker ${contextFlag}stats --no-stream --format "{{json .}}"; exit';
    final tabId = 'dstat-${DateTime.now().microsecondsSinceEpoch}';
    widget.onOpenTab!(
      EngineTab(
        id: tabId,
        title: 'docker stats',
        label: 'docker stats',
        icon: NerdIcon.terminal.data,
        body: DockerCommandTerminal(
          command: command,
          title: 'docker stats',
          host: widget.remoteHost,
          shellService: widget.shellService,
          onExit: () => widget.onCloseTab?.call(tabId),
        ),
        canDrag: true,
        workspaceState: DockerTabState(
          id: 'docker-stats',
          kind: DockerTabKind.command,
          command: command,
          title: 'docker stats',
          hostName: widget.remoteHost?.name,
        ),
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
      setState(() {
        _stats = stats;
        _error = null;
        _loading = false;
        for (final stat in stats) {
          final name = _nameOf(stat);
          _appendHistoryFor(
            _cpuHistoryByContainer,
            name,
            _cpuPercent(stat) ?? 0,
          );
          _appendHistoryFor(
            _memPercentHistoryByContainer,
            name,
            _memPercent(stat) ?? 0,
          );
          _appendHistoryFor(
            _memUsageHistoryByContainer,
            name,
            _parseBytes(stat.memUsage) ?? 0,
          );
          _appendHistoryFor(
            _netIoHistoryByContainer,
            name,
            _parseBytePair(stat.netIO),
          );
          _appendHistoryFor(
            _blockIoHistoryByContainer,
            name,
            _parseBytePair(stat.blockIO),
          );
        }
        _applySort();
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
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

  double? _parseBytes(String value) {
    final used = value.split('/').first.trim();
    return _parseByteValue(used);
  }

  double _parseBytePair(String value) {
    final parts = value.split('/');
    final double first = parts.isNotEmpty
        ? (_parseByteValue(parts[0].trim()) ?? 0)
        : 0;
    final double second = parts.length > 1
        ? (_parseByteValue(parts[1].trim()) ?? 0)
        : 0;
    return first + second;
  }

  double? _parseByteValue(String value) {
    final match = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*([A-Za-z]+)?',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1) ?? '');
    if (number == null) return null;
    final unit = (match.group(2) ?? 'B').toLowerCase();
    const multipliers = {
      'b': 1,
      'kb': 1024,
      'kib': 1024,
      'mb': 1024 * 1024,
      'mib': 1024 * 1024,
      'gb': 1024 * 1024 * 1024,
      'gib': 1024 * 1024 * 1024,
    };
    final multiplier = multipliers[unit] ?? 1;
    return number * multiplier;
  }

  double _parsePid(String value) => double.tryParse(value) ?? 0;

  Widget _lineChartCard({
    required String title,
    required String subtitle,
    required List<_LineSeries> series,
    required double maxWidth,
    String? unitSuffix,
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
                    .map((s) => _ChartLegend(label: s.label, color: s.color))
                    .toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: hasPoints
                    ? LineChart(
                        _lineChartData(series, unitSuffix: unitSuffix),
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
    final palette = _dockerTheme.chartPalette;
    final hash = label.hashCode;
    return palette[hash.abs() % palette.length];
  }

  LineChartData _lineChartData(List<_LineSeries> series, {String? unitSuffix}) {
    final allValues = series.expand((s) => s.values).toList();
    final double maxY = allValues.isNotEmpty
        ? math.max(allValues.reduce(math.max) * 1.1, 10).toDouble()
        : 10;
    final double maxX = series
        .map((s) => (s.values.length - 1).toDouble())
        .fold<double>(0, math.max);
    final gridColor = _dockerTheme.chartGrid.withValues(alpha: 0.15);
    return LineChartData(
      minY: 0,
      maxY: maxY,
      minX: 0,
      maxX: math.max(1, maxX),
      gridData: FlGridData(
        show: true,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: gridColor, strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            FlLine(color: gridColor, strokeWidth: 1),
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
              _formatValue(value, unitSuffix),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideVertically: true,
          fitInsideHorizontally: true,
          getTooltipItems: (touchedSpots) => touchedSpots
              .map(
                (spot) => LineTooltipItem(
                  '${series[spot.barIndex].label}: ${_formatValue(spot.y, unitSuffix)}',
                  Theme.of(context).textTheme.labelLarge ??
                      const TextStyle(color: Colors.white),
                ),
              )
              .toList(),
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

  _ScaledSeries _scaleForBytes(List<_LineSeries> series) {
    final allValues = series.expand((s) => s.values).toList();
    if (allValues.isEmpty) {
      return _ScaledSeries(series: series, unit: 'B');
    }
    final maxValue = allValues.reduce(math.max);
    final units = [
      (label: 'B', factor: 1),
      (label: 'KB', factor: 1024),
      (label: 'MB', factor: 1024 * 1024),
      (label: 'GB', factor: 1024 * 1024 * 1024),
      (label: 'TB', factor: 1024 * 1024 * 1024 * 1024),
    ];
    var chosen = units.first;
    for (final unit in units) {
      if (maxValue >= unit.factor) {
        chosen = unit;
      } else {
        break;
      }
    }
    final scaledSeries = series
        .map(
          (s) => _LineSeries(
            label: s.label,
            values: s.values.map((v) => v / chosen.factor).toList(),
            color: s.color,
          ),
        )
        .toList();
    return _ScaledSeries(series: scaledSeries, unit: chosen.label);
  }

  String _formatValue(double value, String? suffix) {
    final formatted = value >= 10
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(2);
    return suffix != null ? '$formatted $suffix' : formatted;
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

class _ScaledSeries {
  const _ScaledSeries({required this.series, required this.unit});

  final List<_LineSeries> series;
  final String unit;
}
