import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/controllers/kubernetes_resources_controller.dart';
import 'package:cwatch/model/models/kubernetes/kubernetes_resource_models.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/controller/di/bindings/kubernetes_resources_binding.dart';
import 'package:cwatch/view/shared/widgets/dashboard/dashboard_primitives.dart';

class _SeriesData {
  const _SeriesData({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

class _ScaledSeries {
  const _ScaledSeries({required this.series, required this.unit});

  final List<_SeriesData> series;
  final String unit;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    return Container(
      padding: spacing.inset(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: scheme.surface),
            ),
          ),
          SizedBox(width: spacing.base * 1.5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class KubernetesResources extends StatefulWidget {
  const KubernetesResources({
    super.key,
    required this.contextName,
    required this.configPath,
    this.optionsController,
  });

  final String contextName;
  final String configPath;
  final TabOptionsController? optionsController;

  @override
  State<KubernetesResources> createState() => _KubernetesResourcesState();
}

class _KubernetesResourcesState extends State<KubernetesResources> {
  final KubernetesResourcesBinding _binding =
      const KubernetesResourcesBinding();
  late final KubernetesResourcesController _controller;
  late final KubernetesUiAdapter _uiAdapter;
  late final VoidCallback _controllerListener;
  bool _tabOptionsRegistered = false;

  @override
  void initState() {
    super.initState();
    _uiAdapter = KubernetesUiAdapter(context: context);
    _controller = _binding.create(
      contextName: widget.contextName,
      configPath: widget.configPath,
    );
    _controllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _controller.addListener(_controllerListener);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    super.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.optionsController == null) return;
      final options = [
        TabChipOption(
          label: 'Refresh',
          icon: NerdIcon.refresh.data,
          onSelected: () => _controller.loadResources(),
        ),
        TabChipOption(
          label: 'Copy `kubectl top nodes`',
          icon: NerdIcon.copy.data,
          onSelected: () => _uiAdapter.copyToClipboard(
            'kubectl --context=${widget.contextName} --kubeconfig=${widget.configPath} top nodes',
          ),
        ),
        TabChipOption(
          label: 'Copy `kubectl top pods -A`',
          icon: NerdIcon.copy.data,
          onSelected: () => _uiAdapter.copyToClipboard(
            'kubectl --context=${widget.contextName} --kubeconfig=${widget.configPath} top pods -A',
          ),
        ),
      ];
      final controller = widget.optionsController!;
      if (controller is CompositeTabOptionsController) {
        controller.updateOverlay(options);
      } else {
        controller.update(options);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _controller.snapshot;
    final loading = _controller.loading;
    final error = _controller.error;

    Widget body;
    if (loading && snapshot == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load resources: $error'),
            SizedBox(height: spacing.lg),
            FilledButton.icon(
              onPressed: () => _controller.loadResources(initial: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (snapshot == null) {
      body = const Center(child: Text('No resource metrics available.'));
    } else {
      body = ListView(
        padding: EdgeInsets.all(spacing.sm),
        children: [
          _buildSummary(snapshot),
          SizedBox(height: spacing.base * 1.5),
          _buildControls(snapshot),
          SizedBox(height: spacing.base),
          _buildCharts(snapshot),
          SizedBox(height: spacing.base * 1.5),
          _buildNodeTable(snapshot),
          SizedBox(height: spacing.base * 1.5),
          _buildPodTable(snapshot),
          if (loading) ...[
            SizedBox(height: spacing.base * 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(scheme.primary),
                  ),
                ),
                SizedBox(width: spacing.md),
                const Text('Refreshing...'),
              ],
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base,
        vertical: spacing.base * 0.5,
      ),
      child: body,
    );
  }

  Widget _buildSummary(KubeResourceSnapshot snapshot) {
    final spacing = context.appTheme.spacing;
    final cards = [
      (
        title: 'Nodes',
        value: snapshot.nodes.length.toString(),
        icon: Icons.storage,
      ),
      (
        title: 'Pods',
        value: snapshot.pods.length.toString(),
        icon: Icons.podcasts,
      ),
      (
        title: 'Context',
        value: widget.contextName,
        icon: NerdIcon.kubernetes.data,
      ),
      (
        title: 'Updated',
        value: _formatTimestamp(snapshot.collectedAt),
        icon: Icons.schedule,
      ),
    ];
    return Wrap(
      spacing: spacing.base,
      runSpacing: spacing.base,
      children: cards
          .map(
            (card) => SizedBox(
              width: 220,
              child: DashboardMetricCard(
                title: card.title,
                value: card.value,
                icon: card.icon,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildControls(KubeResourceSnapshot snapshot) {
    final spacing = context.appTheme.spacing;
    final namespaces = snapshot.pods.map((p) => p.namespace).toSet().toList()
      ..sort();
    final selectedNamespace = _controller.namespaceFilter ?? 'All';
    return Wrap(
      spacing: spacing.base,
      runSpacing: spacing.base * 0.6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Namespace'),
            SizedBox(width: spacing.md),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedNamespace,
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All')),
                  ...namespaces.map(
                    (ns) => DropdownMenuItem(value: ns, child: Text(ns)),
                  ),
                ],
                onChanged: (value) {
                  _controller.setNamespaceFilter(value == 'All' ? null : value);
                },
              ),
            ),
          ],
        ),
        FilterChip(
          label: const Text('Include system namespaces'),
          selected: _controller.includeSystemNamespaces,
          onSelected: (value) {
            _controller.setIncludeSystemNamespaces(value);
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Top pods'),
            SizedBox(width: spacing.md),
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _controller.podLimit,
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                  DropdownMenuItem(value: 200, child: Text('200')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _controller.setPodLimit(value);
                },
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pod sort'),
            SizedBox(width: spacing.md),
            SegmentedButton<PodSortMetric>(
              segments: const [
                ButtonSegment(
                  value: PodSortMetric.cpu,
                  label: Text('CPU'),
                  icon: Icon(Icons.memory),
                ),
                ButtonSegment(
                  value: PodSortMetric.memory,
                  label: Text('Memory'),
                  icon: Icon(Icons.storage),
                ),
                ButtonSegment(
                  value: PodSortMetric.name,
                  label: Text('Name'),
                  icon: Icon(Icons.sort_by_alpha),
                ),
              ],
              selected: {_controller.podSortMetric},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                _controller.setPodSortMetric(selection.first);
              },
            ),
            IconButton(
              tooltip: _controller.podSortAscending
                  ? 'Descending'
                  : 'Ascending',
              icon: Icon(
                _controller.podSortAscending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
              ),
              onPressed: () {
                _controller.setPodSort(
                  _controller.podSortColumn,
                  !_controller.podSortAscending,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNodeTable(KubeResourceSnapshot snapshot) {
    final nodes = [...snapshot.nodes];
    nodes.sort((a, b) {
      int result;
      switch (_controller.nodeSortColumn) {
        case 0:
          result = a.name.compareTo(b.name);
          break;
        case 1:
          result = _safeCompare(a.cpuCores, b.cpuCores);
          break;
        case 2:
          result = _safeCompare(a.cpuPercent, b.cpuPercent);
          break;
        case 3:
          result = _safeCompare(a.memoryBytes, b.memoryBytes);
          break;
        case 4:
          result = _safeCompare(a.memoryPercent, b.memoryPercent);
          break;
        default:
          result = 0;
      }
      return _controller.nodeSortAscending ? result : -result;
    });

    return DashboardSectionCard(
      title: 'Nodes',
      subtitle: '${nodes.length} nodes in the current sample',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _controller.nodeSortColumn,
          sortAscending: _controller.nodeSortAscending,
          columns: [
            _sortableColumn('Node', 0, onSort: _controller.setNodeSort),
            _sortableColumn('CPU (cores)', 1, onSort: _controller.setNodeSort),
            _sortableColumn('CPU %', 2, onSort: _controller.setNodeSort),
            _sortableColumn('Memory', 3, onSort: _controller.setNodeSort),
            _sortableColumn('Memory %', 4, onSort: _controller.setNodeSort),
          ],
          rows: nodes
              .map(
                (node) => DataRow(
                  cells: [
                    DataCell(Text(node.name)),
                    DataCell(Text(_formatCpu(node.cpuCores))),
                    DataCell(Text(_formatPercent(node.cpuPercent))),
                    DataCell(Text(_formatBytes(node.memoryBytes))),
                    DataCell(Text(_formatPercent(node.memoryPercent))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPodTable(KubeResourceSnapshot snapshot) {
    final pods = _filterPods(snapshot);
    pods.sort((a, b) {
      int result;
      switch (_controller.podSortMetric) {
        case PodSortMetric.namespace:
          result = a.namespace.compareTo(b.namespace);
          break;
        case PodSortMetric.name:
          result = a.name.compareTo(b.name);
          break;
        case PodSortMetric.cpu:
          result = _safeCompare(a.cpuCores, b.cpuCores);
          break;
        case PodSortMetric.memory:
          result = _safeCompare(a.memoryBytes, b.memoryBytes);
          break;
      }
      return _controller.podSortAscending ? result : -result;
    });
    final topPods = pods.take(_controller.podLimit).toList();
    return DashboardSectionCard(
      title: 'Pods',
      subtitle: '${topPods.length} pods after filters',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _controller.podSortColumn,
          sortAscending: _controller.podSortAscending,
          columns: [
            _sortableColumn('Namespace', 0, onSort: _controller.setPodSort),
            _sortableColumn('Pod', 1, onSort: _controller.setPodSort),
            _sortableColumn('CPU (cores)', 2, onSort: _controller.setPodSort),
            _sortableColumn('Memory', 3, onSort: _controller.setPodSort),
          ],
          rows: topPods
              .map(
                (pod) => DataRow(
                  cells: [
                    DataCell(Text(pod.namespace)),
                    DataCell(Text(pod.name)),
                    DataCell(Text(_formatCpu(pod.cpuCores))),
                    DataCell(Text(_formatBytes(pod.memoryBytes))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  DataColumn _sortableColumn(
    String label,
    int index, {
    required void Function(int columnIndex, bool ascending) onSort,
  }) {
    return DataColumn(
      label: Text(label),
      onSort: (columnIndex, ascending) => onSort(columnIndex, ascending),
    );
  }

  List<KubePodStat> _filterPods(KubeResourceSnapshot snapshot) {
    final systemNamespaces = {'kube-system', 'kube-public', 'kube-node-lease'};
    final pods = snapshot.pods.where((pod) {
      if (!_controller.includeSystemNamespaces &&
          systemNamespaces.contains(pod.namespace)) {
        return false;
      }
      if (_controller.namespaceFilter != null &&
          _controller.namespaceFilter!.isNotEmpty) {
        return pod.namespace == _controller.namespaceFilter;
      }
      return true;
    }).toList();
    return pods;
  }

  Widget _buildCharts(KubeResourceSnapshot snapshot) {
    if (_controller.nodeCpuHistory.isEmpty &&
        _controller.nodeMemHistory.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.appTheme.spacing;
    final memScaled = _scaleForBytes(_controller.nodeMemHistory);
    final charts = [
      (
        title: 'CPU usage',
        subtitle: 'Node CPU percent over time',
        series: _seriesFromHistory(_controller.nodeCpuHistory),
        unit: '%',
        maxY: 100.0,
      ),
      (
        title: 'Memory',
        subtitle: 'Node memory usage (${memScaled.unit})',
        series: memScaled.series,
        unit: memScaled.unit,
        maxY: null,
      ),
    ];
    return Column(
      children: charts
          .map(
            (chart) => Padding(
              padding: EdgeInsets.only(bottom: spacing.base),
              child: _lineChartCard(
                title: chart.title,
                subtitle: chart.subtitle,
                series: chart.series,
                unit: chart.unit,
                maxY: chart.maxY,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _lineChartCard({
    required String title,
    required String subtitle,
    required List<_SeriesData> series,
    String? unit,
    double? maxY,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    if (series.isEmpty || series.every((s) => s.values.isEmpty)) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(spacing.sm),
          child: Row(
            children: [
              Icon(Icons.show_chart, color: scheme.onSurfaceVariant),
              SizedBox(width: spacing.base),
              Text('Waiting for metrics...'),
            ],
          ),
        ),
      );
    }
    final maxPoints = series.fold<int>(
      0,
      (acc, s) => acc = acc > s.values.length ? acc : s.values.length,
    );
    final maxValue =
        maxY ??
        series.fold<double>(
          0,
          (acc, s) => s.values.fold(acc, (m, v) => v > m ? v : m),
        );
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: scheme.primary),
                SizedBox(width: spacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (unit != null)
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: spacing.base),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (maxPoints - 1).toDouble().clamp(0, double.infinity),
                  minY: 0,
                  maxY: (maxValue * 1.2).clamp(1, double.infinity),
                  clipData: const FlClipData.horizontal(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxValue == 0
                        ? 1
                        : (maxValue / 4).clamp(1, double.infinity),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: maxValue == 0
                            ? 1
                            : (maxValue / 4).clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) {
                          final text = unit == null
                              ? value.toStringAsFixed(0)
                              : '$value${unit == '%' ? unit : ''}';
                          return Text(
                            text,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: series.map(_toBar).toList(),
                ),
              ),
            ),
            SizedBox(height: spacing.base),
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm * 0.5,
              children: series
                  .map((s) => _LegendChip(label: s.label, color: s.color))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _toBar(_SeriesData series) {
    final spots = <FlSpot>[];
    for (var i = 0; i < series.values.length; i++) {
      spots.add(FlSpot(i.toDouble(), series.values[i]));
    }
    return LineChartBarData(
      spots: spots,
      color: series.color,
      isCurved: true,
      curveSmoothness: 0.35,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: series.color.withValues(alpha: 0.12),
      ),
    );
  }

  List<_SeriesData> _seriesFromHistory(Map<String, List<double>> history) {
    final colors = _seriesColors();
    final entries = <_SeriesData>[];
    var colorIndex = 0;
    for (final entry in history.entries) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      entries.add(
        _SeriesData(
          label: entry.key,
          values: List<double>.from(entry.value),
          color: color,
        ),
      );
    }
    return entries;
  }

  _ScaledSeries _scaleForBytes(Map<String, List<double>> history) {
    double maxValue = 0;
    for (final entry in history.values) {
      for (final value in entry) {
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }
    const units = ['MiB', 'GiB', 'TiB'];
    var unitIndex = 0;
    var divisor = 1.0;
    while (maxValue >= 1024 && unitIndex < units.length - 1) {
      maxValue /= 1024;
      divisor *= 1024;
      unitIndex++;
    }
    final scaled = <String, List<double>>{};
    history.forEach((key, values) {
      scaled[key] = values.map((v) => v / divisor).toList();
    });
    return _ScaledSeries(
      series: _seriesFromHistory(scaled),
      unit: units[unitIndex],
    );
  }

  List<Color> _seriesColors() {
    final scheme = Theme.of(context).colorScheme;
    return [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.primaryContainer,
      scheme.secondaryContainer,
    ];
  }

  int _safeCompare(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  String _formatCpu(double? cores) {
    if (cores == null) return '--';
    if (cores < 1) {
      return '${(cores * 1000).toStringAsFixed(0)}m';
    }
    return cores.toStringAsFixed(2);
  }

  String _formatPercent(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)}%';
  }

  String _formatBytes(double? bytes) {
    if (bytes == null) return '--';
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var value = bytes;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final digits = value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  String _formatTimestamp(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}
