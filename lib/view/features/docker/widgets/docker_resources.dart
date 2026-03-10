import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:cwatch/controller/controllers/docker_resources_controller.dart';
import 'package:cwatch/model/models/docker_container_stat.dart';
import 'package:cwatch/view/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import '../docker_tab_builder.dart';

class DockerResources extends StatefulWidget {
  const DockerResources({
    super.key,
    required this.controller,
    this.onOpenTab,
    this.onCloseTab,
    this.optionsController,
    required this.tabBuilder,
  });

  final DockerResourcesController controller;
  final void Function(WorkspaceTab tab)? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final TabOptionsController? optionsController;
  final DockerTabBuilder tabBuilder;

  @override
  State<DockerResources> createState() => _DockerResourcesState();
}

class _DockerResourcesState extends State<DockerResources>
    with TabOptionsMixin {
  late final DockerResourcesController _controller;
  late final VoidCallback _controllerListener;
  AppIcons get _icons => context.appTheme.icons;
  AppDockerTokens get _dockerTheme => context.appTheme.docker;
  bool _tabOptionsRegistered = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _controller.addListener(_controllerListener);
    _controller.initialize();
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
    queueTabOptions(widget.optionsController, [
      TabChipOption(
        label: 'Open `docker stats`',
        icon: NerdIcon.terminal.data,
        onSelected: _openStatsTab,
      ),
      TabChipOption(
        label: 'Refresh',
        icon: icons.refresh,
        onSelected: () => _controller.loadStats(),
      ),
    ]);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final loading = _controller.loading;
    final error = _controller.error;
    final stats = _sortedStats();
    return Padding(
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.md),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text('Failed to load stats: $error'))
                : stats.isEmpty
                ? const StandardEmptyState(message: 'No container stats found.')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        children: [
                          _buildCharts(constraints.maxWidth),
                          SizedBox(height: spacing.xl),
                          _buildContainerTable(constraints.maxWidth, stats),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<DockerContainerStat> _sortedStats() {
    final stats = [..._controller.stats];
    final comparator = _comparatorForColumn(_controller.sortColumnIndex);
    stats.sort((a, b) {
      final result = comparator(a, b);
      return _controller.sortAscending ? result : -result;
    });
    return stats;
  }

  Widget _buildCharts(double maxCardWidth) {
    final spacing = context.appTheme.spacing;
    final memUsageScaled = _scaleForBytes(
      _seriesFromMap(_controller.memUsageHistoryByContainer),
    );
    final netIoScaled = _scaleForBytes(
      _seriesFromMap(_controller.netIoHistoryByContainer),
    );
    final blockIoScaled = _scaleForBytes(
      _seriesFromMap(_controller.blockIoHistoryByContainer),
    );
    final charts = [
      (
        title: 'CPU %',
        subtitle: 'CPU percent by container',
        series: _seriesFromMap(_controller.cpuHistoryByContainer),
        unit: null,
      ),
      (
        title: 'Memory %',
        subtitle: 'Memory percent by container',
        series: _seriesFromMap(_controller.memPercentHistoryByContainer),
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
        SizedBox(height: spacing.md),
        ...charts.map(
          (chart) => Padding(
            padding: EdgeInsets.only(bottom: spacing.lg),
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

  Widget _buildContainerTable(
    double maxCardWidth,
    List<DockerContainerStat> stats,
  ) {
    final spacing = context.appTheme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Container stats', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: spacing.md),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: maxCardWidth),
              child: DataTable(
                sortColumnIndex: _controller.sortColumnIndex,
                sortAscending: _controller.sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('Container'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('CPU'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Mem'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Net I/O'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('Block I/O'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                  DataColumn(
                    numeric: true,
                    label: const Text('PIDs'),
                    onSort: (index, ascending) =>
                        _controller.setSort(index, ascending),
                  ),
                ],
                rows: stats
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

  int Function(DockerContainerStat a, DockerContainerStat b)
  _comparatorForColumn(int column) {
    switch (column) {
      case 1:
        return (a, b) => _compareNum(_cpuPercent(a), _cpuPercent(b));
      case 2:
        return (a, b) => _compareNum(_memPercent(a), _memPercent(b));
      case 3:
        return (a, b) => _compareNum(
          _controller.parseBytePair(a.netIO),
          _controller.parseBytePair(b.netIO),
        );
      case 4:
        return (a, b) => _compareNum(
          _controller.parseBytePair(a.blockIO),
          _controller.parseBytePair(b.blockIO),
        );
      case 5:
        return (a, b) => _compareNum(
          double.tryParse(a.pids) ?? 0,
          double.tryParse(b.pids) ?? 0,
        );
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

  void _openStatsTab() {
    if (widget.onOpenTab == null) return;
    final contextName = _controller.contextName;
    final contextFlag = contextName != null && contextName.isNotEmpty
        ? '--context $contextName '
        : '';
    final command =
        'docker ${contextFlag}stats --no-stream --format "{{json .}}"; exit';
    final tabId = 'dstat-${DateTime.now().microsecondsSinceEpoch}';
    widget.onOpenTab!(
      widget.tabBuilder.commandTerminal(
        id: tabId,
        title: 'docker stats',
        label: 'docker stats',
        command: command,
        icon: NerdIcon.terminal.data,
        host: _controller.remoteHost,
        shellService: _controller.shellService,
        onExit: () => widget.onCloseTab?.call(tabId),
      ),
    );
  }

  Widget _lineChartCard({
    required String title,
    required String subtitle,
    required List<_LineSeries> series,
    required double maxWidth,
    String? unitSuffix,
  }) {
    final spacing = context.appTheme.spacing;
    final hasPoints = series.any((s) => s.values.isNotEmpty);
    return SizedBox(
      width: maxWidth,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: spacing.xs),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: spacing.md),
              Wrap(
                spacing: spacing.lg,
                runSpacing: spacing.sm,
                children: series
                    .map((s) => _ChartLegend(label: s.label, color: s.color))
                    .toList(),
              ),
              SizedBox(height: spacing.md),
              SizedBox(
                height: context.scale(240),
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
    final tooltipBackground = _dockerTheme.chartGridAlt.withValues(alpha: 0.9);
    final tooltipBorderColor = _dockerTheme.chartGrid.withValues(alpha: 0.6);
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
          getTooltipColor: (_) => tooltipBackground,
          tooltipBorder: BorderSide(color: tooltipBorderColor),
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
    final spacing = context.appTheme.spacing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.scale(12),
          height: context.scale(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2 * context.zoomFactor),
          ),
        ),
        SizedBox(width: spacing.base * 1.5),
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
