import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key, required this.host});

  final SshHost host;

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  final _ProcessTreeController _processTreeController =
      _ProcessTreeController();
  _ResourceSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  final List<double> _cpuHistory = [];
  final List<double> _memoryHistory = [];
  final List<double> _diskIoHistory = [];
  final List<double> _netInHistory = [];
  final List<double> _netOutHistory = [];
  _NetTotals? _lastNetTotals;

  static const _historyCapacity = 30;
  static const double _sampleWindowSeconds = 0.4;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _collectSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _appendHistory(_cpuHistory, snapshot.cpuUsage);
        _appendHistory(_memoryHistory, snapshot.memoryUsedPct);
        _appendHistory(
          _diskIoHistory,
          snapshot.totalDiskIo,
          clampTo100: false,
        );
        _appendHistory(
          _netInHistory,
          snapshot.netInMbps,
          clampTo100: false,
        );
        _appendHistory(
          _netOutHistory,
          snapshot.netOutMbps,
          clampTo100: false,
        );
      });
      _startPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final snapshot = await _collectSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _appendHistory(_cpuHistory, snapshot.cpuUsage);
        _appendHistory(_memoryHistory, snapshot.memoryUsedPct);
        _appendHistory(
          _diskIoHistory,
          snapshot.totalDiskIo,
          clampTo100: false,
        );
        _appendHistory(
          _netInHistory,
          snapshot.netInMbps,
          clampTo100: false,
        );
        _appendHistory(
          _netOutHistory,
          snapshot.netOutMbps,
          clampTo100: false,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: spacing.all(2),
        children: [
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: spacing.all(2),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    SizedBox(width: spacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_snapshot != null) ...[
            _buildCpuPanel(context),
            SizedBox(height: spacing.lg),
            _buildMemoryPanel(context),
            SizedBox(height: spacing.lg),
            _buildNetworkAndLoadRow(context),
            SizedBox(height: spacing.lg),
            _buildDisksPanel(context),
            SizedBox(height: spacing.lg),
            _buildProcessList(context),
          ],
        ],
      ),
    );
  }

  Widget _buildCpuPanel(BuildContext context) {
    final snapshot = _snapshot!;
    final color = Theme.of(context).colorScheme.primary;
    final history = _cpuHistory.isEmpty ? [snapshot.cpuUsage] : _cpuHistory;
    return _SectionCard(
      title: 'CPU Usage',
      subtitle:
          'Load avg ${snapshot.load1.toStringAsFixed(2)} / ${snapshot.load5.toStringAsFixed(2)} / ${snapshot.load15.toStringAsFixed(2)}',
      trailing: Text('${snapshot.cpuUsage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleLarge),
      child: SizedBox(
        height: 150,
        child: _SparklineChart(
          data: history,
          color: color,
          label: 'CPU %',
        ),
      ),
    );
  }

  Widget _buildMemoryPanel(BuildContext context) {
    final snapshot = _snapshot!;
    final spacing = context.appTheme.spacing;
    return _SectionCard(
      title: 'Memory & Swap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GaugeRow(
            label: 'Memory',
            percent: snapshot.memoryUsedPct / 100,
            value:
                '${snapshot.memoryUsedGb.toStringAsFixed(1)} / ${snapshot.memoryTotalGb.toStringAsFixed(1)} GB',
          ),
          SizedBox(height: spacing.sm),
          _GaugeRow(
            label: 'Swap',
            percent:
                snapshot.swapUsedPct.isNaN ? 0 : snapshot.swapUsedPct / 100,
            value: snapshot.swapTotalGb <= 0
                ? 'No swap'
                : '${snapshot.swapUsedGb.toStringAsFixed(1)} / ${snapshot.swapTotalGb.toStringAsFixed(1)} GB',
          ),
          SizedBox(height: spacing.md),
          SizedBox(
            height: 100,
            child: _SparklineChart(
              data: _memoryHistory.isEmpty
                  ? [snapshot.memoryUsedPct]
                  : _memoryHistory,
              color: Colors.tealAccent,
              label: 'Memory %',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkAndLoadRow(BuildContext context) {
    final snapshot = _snapshot!;
    return _SectionCard(
      title: 'Network IO',
      subtitle:
          'Inbound ${snapshot.netInMbps.toStringAsFixed(2)} Mbps · Outbound ${snapshot.netOutMbps.toStringAsFixed(2)} Mbps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: _SparklineChart(
              data: _netInHistory.isEmpty
                  ? [snapshot.netInMbps]
                  : _netInHistory,
              color: Colors.lightBlueAccent,
              normalize: false,
              label: 'Inbound Mbps',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: _SparklineChart(
              data: _netOutHistory.isEmpty
                  ? [snapshot.netOutMbps]
                  : _netOutHistory,
              color: Colors.orangeAccent,
              normalize: false,
              label: 'Outbound Mbps',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisksPanel(BuildContext context) {
    final disks = _snapshot!.disks;
    if (disks.isEmpty) {
      return const _SectionCard(
        title: 'Disks',
        child: Text('No disks detected'),
      );
    }
    final spacing = context.appTheme.spacing;
    final ioChart = _diskIoHistory.length < 2
        ? null
        : SizedBox(
            height: 140,
            child: _SparklineChart(
              data: _diskIoHistory,
              color: Colors.amberAccent,
              normalize: false,
              label: 'Disk IO Mbps',
            ),
          );
    return _SectionCard(
      title: 'Disks',
      subtitle: 'Aggregate IO throughput and per-device usage',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ioChart != null) ...[ioChart, SizedBox(height: spacing.md)],
          Column(
            children: disks.map((disk) => _DiskUsageCard(disk: disk)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessList(BuildContext context) {
    final processes = _snapshot!.processes;
    return _SectionCard(
      title: 'Top Processes',
      subtitle: processes.isEmpty
          ? null
          : '${processes.length} sampled processes',
      trailing: processes.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Expand all',
                  icon: const Icon(Icons.unfold_more),
                  onPressed: _processTreeController.expandAll,
                ),
                IconButton(
                  tooltip: 'Collapse all',
                  icon: const Icon(Icons.unfold_less),
                  onPressed: _processTreeController.collapseAll,
                ),
              ],
            ),
      child: processes.isEmpty
          ? const Text('No process information available.')
          : _ProcessTreeView(
              processes: processes,
              controller: _processTreeController,
            ),
    );
  }

  Future<_ResourceSnapshot> _collectSnapshot() async {
    const cpuMarker = '__CW_CPU__';
    const memMarker = '__CW_MEM__';
    const loadMarker = '__CW_LOAD__';
    const diskUsageMarker = '__CW_DISKS__';
    const diskStatsBeforeMarker = '__CW_DISK_BEFORE__';
    const diskStatsAfterMarker = '__CW_DISK_AFTER__';
    const procMarker = '__CW_PROC__';
    const netMarker = '__CW_NET__';
    final script = '''
disk_stats_before=\$(cat /proc/diskstats)
cpu_before=\$(head -n1 /proc/stat)
sleep $_sampleWindowSeconds
cpu_after=\$(head -n1 /proc/stat)
disk_stats_after=\$(cat /proc/diskstats)
echo $cpuMarker
echo "\$cpu_before"
echo "\$cpu_after"
echo $memMarker
cat /proc/meminfo
echo $loadMarker
cat /proc/loadavg
echo $diskUsageMarker
df -B1 --output=source,size,used,pcent,target -x tmpfs -x devtmpfs -x squashfs
echo $procMarker
ps -eo pid,ppid,comm,%cpu,%mem --sort=-%cpu
echo $netMarker
cat /proc/net/dev
echo $diskStatsBeforeMarker
echo "\$disk_stats_before"
echo $diskStatsAfterMarker
echo "\$disk_stats_after"
''';
    final raw = await _runSsh(script, timeout: const Duration(seconds: 8));
    if (raw == null || raw.isEmpty) {
      throw Exception('No resource data available.');
    }
    final sections = _splitSections(
      raw,
      markers: {
        cpuMarker,
        memMarker,
        loadMarker,
        diskUsageMarker,
        diskStatsBeforeMarker,
        diskStatsAfterMarker,
        procMarker,
        netMarker,
      },
    );
    final cpuLines = sections[cpuMarker] ?? [];
    final memLines = sections[memMarker] ?? [];
    final loadLine = sections[loadMarker]?.firstOrNull ?? '';
    final diskUsageLines = sections[diskUsageMarker] ?? [];
    final diskStatsBefore = sections[diskStatsBeforeMarker] ?? [];
    final diskStatsAfter = sections[diskStatsAfterMarker] ?? [];
    final procLines = sections[procMarker] ?? [];
    final netLines = sections[netMarker] ?? [];

    final cpuUsage = _parseCpuUsage(cpuLines);
    final memStats = _parseMemInfo(memLines);
    final loads = _parseLoad(loadLine);
    final diskIoRates = _parseDiskIoRates(
      diskStatsBefore,
      diskStatsAfter,
      _sampleWindowSeconds,
    );
    final disks = _parseDisks(diskUsageLines, diskIoRates);
    final totalMemoryBytes =
        (memStats.totalGb * pow(1024, 3)).toDouble();
    final processes = _parseProcesses(procLines, totalMemoryBytes);
    final netTotals = _parseNetworkTotals(netLines);
    final netRates = _computeNetRates(netTotals);
    final diskIoTotal = diskIoRates.values.fold<double>(
      0,
      (sum, rate) => sum + rate.readMbps + rate.writeMbps,
    );

    return _ResourceSnapshot(
      cpuUsage: cpuUsage,
      load1: loads.$1,
      load5: loads.$2,
      load15: loads.$3,
      memoryTotalGb: memStats.totalGb,
      memoryUsedGb: memStats.usedGb,
      memoryUsedPct: memStats.usedPct,
      swapTotalGb: memStats.swapTotalGb,
      swapUsedGb: memStats.swapUsedGb,
      swapUsedPct: memStats.swapUsedPct,
      disks: disks,
      processes: processes,
      netInMbps: netRates.$1,
      netOutMbps: netRates.$2,
      totalDiskIo: diskIoTotal,
    );
  }

  Map<String, List<String>> _splitSections(
    String raw, {
    required Set<String> markers,
  }) {
    final lines = const LineSplitter().convert(raw);
    final result = <String, List<String>>{};
    String? current;
    for (final line in lines) {
      final trimmed = line.trim();
      if (markers.contains(trimmed)) {
        current = trimmed;
        result[current] = [];
        continue;
      }
      if (current != null) {
        result[current]!.add(line);
      }
    }
    return result;
  }

  double _parseCpuUsage(List<String> lines) {
    if (lines.length < 2) return 0;
    List<int> parseLine(String line) {
      final parts = line.split(RegExp(r'\s+'));
      return parts
          .where((part) => part != 'cpu' && part.isNotEmpty)
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
    }

    final first = parseLine(lines[0]);
    final second = parseLine(lines[1]);
    final total1 = first.fold(0, (sum, value) => sum + value);
    final total2 = second.fold(0, (sum, value) => sum + value);
    final idle1 = (first.length > 3 ? first[3] : 0) + (first.length > 4 ? first[4] : 0);
    final idle2 = (second.length > 3 ? second[3] : 0) + (second.length > 4 ? second[4] : 0);
    final totalDiff = max(1, total2 - total1);
    final idleDiff = max(0, idle2 - idle1);
    return ((totalDiff - idleDiff) / totalDiff) * 100;
  }

  _MemStats _parseMemInfo(List<String> lines) {
    double parseValue(String key) {
      final line = lines.firstWhere(
        (entry) => entry.startsWith(key),
        orElse: () => '',
      );
      if (line.isEmpty) return 0;
      final match = RegExp(r'(\d+)').firstMatch(line);
      if (match == null) return 0;
      return (double.tryParse(match.group(1) ?? '0') ?? 0) * 1024;
    }

    final total = parseValue('MemTotal');
    final available = parseValue('MemAvailable');
    final used = max(0, total - available);
    final swapTotal = parseValue('SwapTotal');
    final swapFree = parseValue('SwapFree');
    final swapUsed = max(0, swapTotal - swapFree);

    return _MemStats(
      totalGb: total / pow(1024, 3),
      usedGb: used / pow(1024, 3),
      usedPct: total > 0 ? (used / total) * 100 : 0,
      swapTotalGb: swapTotal / pow(1024, 3),
      swapUsedGb: swapUsed / pow(1024, 3),
      swapUsedPct: swapTotal > 0 ? (swapUsed / swapTotal) * 100 : double.nan,
    );
  }

  (double, double, double) _parseLoad(String line) {
    final parts = line.split(RegExp(r'\s+'));
    final load1 = double.tryParse(parts.elementAtOrNull(0) ?? '') ?? 0;
    final load5 = double.tryParse(parts.elementAtOrNull(1) ?? '') ?? 0;
    final load15 = double.tryParse(parts.elementAtOrNull(2) ?? '') ?? 0;
    return (load1, load5, load15);
  }

  Map<String, _DiskIoRate> _parseDiskIoRates(
    List<String> beforeLines,
    List<String> afterLines,
    double intervalSeconds,
  ) {
    Map<String, _DiskStatSample> parse(List<String> lines) {
      final samples = <String, _DiskStatSample>{};
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 14) continue;
        final name = parts[2];
        final readSectors = int.tryParse(parts[5]) ?? 0;
        final writeSectors = int.tryParse(parts[9]) ?? 0;
        samples[name] = _DiskStatSample(
          readSectors: readSectors,
          writeSectors: writeSectors,
        );
      }
      return samples;
    }

    final before = parse(beforeLines);
    final after = parse(afterLines);
    final rates = <String, _DiskIoRate>{};
    for (final entry in after.entries) {
      final beforeSample = before[entry.key];
      if (beforeSample == null) continue;
      final readSectors =
          max(0, entry.value.readSectors - beforeSample.readSectors);
      final writeSectors =
          max(0, entry.value.writeSectors - beforeSample.writeSectors);
      final readBytesPerSecond = (readSectors * 512) / intervalSeconds;
      final writeBytesPerSecond = (writeSectors * 512) / intervalSeconds;
      rates[entry.key] = _DiskIoRate(
        readMbps: (readBytesPerSecond * 8) / 1e6,
        writeMbps: (writeBytesPerSecond * 8) / 1e6,
      );
    }
    return rates;
  }

  List<_DiskUsage> _parseDisks(
    List<String> lines,
    Map<String, _DiskIoRate> ioRates,
  ) {
    final disks = <_DiskUsage>[];
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      final total = double.tryParse(parts[1]) ?? 0;
      final used = double.tryParse(parts[2]) ?? 0;
      final percent = parts[3].replaceAll('%', '');
      final device = _deviceKey(parts[0]);
      final rate = ioRates[device] ?? ioRates[_stripPartition(device)];
      disks.add(
        _DiskUsage(
          filesystem: parts[0],
          usedGb: used / pow(1024, 3),
          totalGb: total / pow(1024, 3),
          usedPct: double.tryParse(percent) ?? 0,
          readMbps: rate?.readMbps ?? 0,
          writeMbps: rate?.writeMbps ?? 0,
        ),
      );
    }
    return disks;
  }
  String _deviceKey(String filesystem) {
    return filesystem.startsWith('/dev/')
        ? filesystem.substring(5)
        : filesystem;
  }

  String _stripPartition(String device) {
    return device.replaceFirst(RegExp(r'p?\d+$'), '');
  }

  List<_ProcessInfo> _parseProcesses(
    List<String> lines,
    double totalMemoryBytes,
  ) {
    final processes = <_ProcessInfo>[];
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      final pid = int.tryParse(parts[0]) ?? 0;
      final ppid = int.tryParse(parts[1]) ?? 0;
      final cmd = parts[2];
      final cpu = double.tryParse(parts[3]) ?? 0;
      final memPercent = double.tryParse(parts[4]) ?? 0;
      final memBytes =
          totalMemoryBytes > 0 ? (memPercent / 100) * totalMemoryBytes : 0.0;
      processes.add(
        _ProcessInfo(
          pid: pid,
          ppid: ppid,
          command: cmd,
          cpu: cpu,
          memoryPercent: memPercent,
          memoryBytes: memBytes,
        ),
      );
    }
    return processes;
  }

  _NetTotals _parseNetworkTotals(List<String> lines) {
    var rx = 0;
    var tx = 0;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.contains(':')) continue;
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final iface = parts[0].trim();
      if (iface == 'lo' || iface.isEmpty) continue;
      final metrics = parts[1].trim().split(RegExp(r'\s+'));
      if (metrics.length < 9) continue;
      rx += int.tryParse(metrics[0]) ?? 0;
      tx += int.tryParse(metrics[8]) ?? 0;
    }
    return _NetTotals(rxBytes: rx, txBytes: tx, timestamp: DateTime.now());
  }

  (double, double) _computeNetRates(_NetTotals totals) {
    double inbound = 0;
    double outbound = 0;
    if (_lastNetTotals != null) {
      final elapsed = totals.timestamp
              .difference(_lastNetTotals!.timestamp)
              .inMilliseconds /
          1000;
      if (elapsed > 0) {
        final rxDiff = max(0, totals.rxBytes - _lastNetTotals!.rxBytes);
        final txDiff = max(0, totals.txBytes - _lastNetTotals!.txBytes);
        inbound = (rxDiff * 8 / elapsed) / 1e6;
        outbound = (txDiff * 8 / elapsed) / 1e6;
      }
    }
    _lastNetTotals = totals;
    return (inbound, outbound);
  }

  Future<String?> _runSsh(
    String script, {
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
          script,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);
      if (result.exitCode != 0) {
        throw Exception(
          (result.stderr as String?)?.trim().isNotEmpty == true
              ? (result.stderr as String).trim()
              : 'SSH exited with ${result.exitCode}',
        );
      }
      return (result.stdout as String?)?.trim();
    } catch (error) {
      throw Exception('SSH command failed: $error');
    }
  }

  void _appendHistory(
    List<double> history,
    double value, {
    bool clampTo100 = true,
  }) {
    history.add(clampTo100 ? value.clamp(0, 100) : value);
    if (history.length > _historyCapacity) {
      history.removeAt(0);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({
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

class _DiskUsageCard extends StatelessWidget {
  const _DiskUsageCard({required this.disk});

  final _DiskUsage disk;

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
          _UsedFreeBar(
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
              _IoMetric(
                label: 'Read',
                value: '${disk.readMbps.toStringAsFixed(1)} Mbps',
                icon: Icons.download,
              ),
              SizedBox(width: spacing.sm),
              _IoMetric(
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

class _UsedFreeBar extends StatelessWidget {
  const _UsedFreeBar({
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

class _IoMetric extends StatelessWidget {
  const _IoMetric({
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

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({
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

class _ResourceSnapshot {
  const _ResourceSnapshot({
    required this.cpuUsage,
    required this.load1,
    required this.load5,
    required this.load15,
    required this.memoryTotalGb,
    required this.memoryUsedGb,
    required this.memoryUsedPct,
    required this.swapTotalGb,
    required this.swapUsedGb,
    required this.swapUsedPct,
    required this.disks,
    required this.processes,
    required this.netInMbps,
    required this.netOutMbps,
    required this.totalDiskIo,
  });

  final double cpuUsage;
  final double load1;
  final double load5;
  final double load15;
  final double memoryTotalGb;
  final double memoryUsedGb;
  final double memoryUsedPct;
  final double swapTotalGb;
  final double swapUsedGb;
  final double swapUsedPct;
  final List<_DiskUsage> disks;
  final List<_ProcessInfo> processes;
  final double netInMbps;
  final double netOutMbps;
  final double totalDiskIo;
}

class _DiskUsage {
  const _DiskUsage({
    required this.filesystem,
    required this.usedGb,
    required this.totalGb,
    required this.usedPct,
    required this.readMbps,
    required this.writeMbps,
  });

  final String filesystem;
  final double usedGb;
  final double totalGb;
  final double usedPct;
  final double readMbps;
  final double writeMbps;

  String get name => filesystem.split('/').last;
  double get freeGb => max(0, totalGb - usedGb);
}

class _ProcessInfo {
  const _ProcessInfo({
    required this.pid,
    required this.ppid,
    required this.command,
    required this.cpu,
    required this.memoryPercent,
    required this.memoryBytes,
  });

  final int pid;
  final int ppid;
  final String command;
  final double cpu;
  final double memoryPercent;
  final double memoryBytes;
}

class _MemStats {
  const _MemStats({
    required this.totalGb,
    required this.usedGb,
    required this.usedPct,
    required this.swapTotalGb,
    required this.swapUsedGb,
    required this.swapUsedPct,
  });

  final double totalGb;
  final double usedGb;
  final double usedPct;
  final double swapTotalGb;
  final double swapUsedGb;
  final double swapUsedPct;
}

class _NetTotals {
  const _NetTotals({
    required this.rxBytes,
    required this.txBytes,
    required this.timestamp,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime timestamp;
}

class _DiskIoRate {
  const _DiskIoRate({required this.readMbps, required this.writeMbps});

  final double readMbps;
  final double writeMbps;
}

class _DiskStatSample {
  const _DiskStatSample({
    required this.readSectors,
    required this.writeSectors,
  });

  final int readSectors;
  final int writeSectors;
}

class _ProcessNode {
  _ProcessNode(this.info);

  final _ProcessInfo info;
  final List<_ProcessNode> children = [];
}

class _ProcessTreeRowData {
  const _ProcessTreeRowData({
    required this.info,
    required this.ancestorLastFlags,
    required this.isExpandable,
    required this.isCollapsed,
    required this.totalCpu,
    required this.totalMem,
  });

  final _ProcessInfo info;
  final List<bool> ancestorLastFlags;
  final bool isExpandable;
  final bool isCollapsed;
  final double totalCpu;
  final double totalMem;

  int get depth => ancestorLastFlags.length;
}

enum _ProcessSortColumn { cpu, memory, pid, command }

extension<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
  E? elementAtOrNull(int index) => index >= length ? null : this[index];
}

class _ProcessTreeController {
  VoidCallback? _expandAll;
  VoidCallback? _collapseAll;

  void _attach({
    required VoidCallback expandAll,
    required VoidCallback collapseAll,
  }) {
    _expandAll = expandAll;
    _collapseAll = collapseAll;
  }

  void _detach() {
    _expandAll = null;
    _collapseAll = null;
  }

  void expandAll() => _expandAll?.call();
  void collapseAll() => _collapseAll?.call();
}

class _ProcessTreeView extends StatefulWidget {
  const _ProcessTreeView({required this.processes, this.controller});

  final List<_ProcessInfo> processes;
  final _ProcessTreeController? controller;

  @override
  State<_ProcessTreeView> createState() => _ProcessTreeViewState();
}

class _ProcessTreeViewState extends State<_ProcessTreeView> {
  final Set<int> _collapsedPids = {};
  int? _selectedPid;
  _ProcessSortColumn _sortColumn = _ProcessSortColumn.cpu;
  bool _sortAscending = false;
  final FocusNode _focusNode = FocusNode();
  List<_ProcessTreeRowData> _visibleRows = const [];

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(
      expandAll: _expandAll,
      collapseAll: _collapseAll,
    );
  }

  @override
  void didUpdateWidget(covariant _ProcessTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(
        expandAll: _expandAll,
        collapseAll: _collapseAll,
      );
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildProcessRowData(widget.processes);
    _visibleRows = rows;
    final rowHeight = 40.0;
    final minHeight = 200.0;
    final maxHeight = 420.0;
    final height = rows.isEmpty
        ? minHeight
        : min(maxHeight, max(minHeight, rows.length * rowHeight));
    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: false,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown):
            _MoveSelectionIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp):
            _MoveSelectionIntent(-1),
      },
      actions: {
        _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
          onInvoke: (intent) {
            _moveSelection(intent.offset);
            return null;
          },
        ),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProcessHeader(
            sortColumn: _sortColumn,
            ascending: _sortAscending,
            onSort: _handleSort,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: height,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(scrollbars: true),
                child: ListView.builder(
                  itemCount: rows.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _ProcessTreeRow(
                      row: row,
                      selected: row.info.pid == _selectedPid,
                      onTap: () {
                        _focusNode.requestFocus();
                        setState(() => _selectedPid = row.info.pid);
                      },
                      onToggleCollapse: row.isExpandable
                          ? () => setState(() {
                                if (_collapsedPids.contains(row.info.pid)) {
                                  _collapsedPids.remove(row.info.pid);
                                } else {
                                  _collapsedPids.add(row.info.pid);
                                }
                              })
                          : null,
                      onContextMenu: (position) =>
                          _showContextMenu(context, position, row.info),
                      onDoubleTap: row.isExpandable
                          ? () {
                              setState(() {
                                if (_collapsedPids.contains(row.info.pid)) {
                                  _collapsedPids.remove(row.info.pid);
                                } else {
                                  _collapsedPids.add(row.info.pid);
                                }
                              });
                            }
                          : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    _ProcessInfo info,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      items: const [
        PopupMenuItem(value: 'info', child: Text('Info')),
        PopupMenuItem(value: 'signals', child: Text('Signals')),
        PopupMenuItem(value: 'terminate', child: Text('Terminate')),
        PopupMenuItem(value: 'kill', child: Text('Kill')),
      ],
    );
    if (!context.mounted) return;
    if (selected == null) {
      return;
    }
    switch (selected) {
      case 'info':
        _showInfoDialog(context, info);
        break;
      case 'signals':
        _showSignalsDialog(context, info);
        break;
      case 'terminate':
        _showSnack(context, 'Terminate ${info.command} (${info.pid})');
        break;
      case 'kill':
        _showSnack(context, 'Kill ${info.command} (${info.pid})');
        break;
    }
  }

  void _showInfoDialog(BuildContext context, _ProcessInfo info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Process ${info.pid}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Command: ${info.command}'),
            Text('Parent PID: ${info.ppid}'),
            Text('CPU: ${info.cpu.toStringAsFixed(2)}%'),
            Text(
              'Memory: ${_formatBytes(info.memoryBytes)} '
              '(${info.memoryPercent.toStringAsFixed(2)}%)',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignalsDialog(BuildContext context, _ProcessInfo info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send signal to ${info.pid}'),
        content: SizedBox(
          width: 280,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final signal in ['HUP', 'INT', 'TERM', 'KILL', 'USR1', 'USR2'])
                ListTile(
                  title: Text('SIG$signal'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSnack(context, 'Sent SIG$signal to ${info.pid}');
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleSort(_ProcessSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column == _ProcessSortColumn.command ||
            column == _ProcessSortColumn.pid;
      }
    });
  }

  void _moveSelection(int offset) {
    if (_visibleRows.isEmpty) {
      return;
    }
    final currentIndex = _selectedPid == null
        ? -1
        : _visibleRows.indexWhere((row) => row.info.pid == _selectedPid);
    final nextIndex = (currentIndex + offset).clamp(0, _visibleRows.length - 1);
    setState(() {
      _selectedPid = _visibleRows[nextIndex].info.pid;
    });
  }

  void _collapseAll() {
    setState(() {
      _collapsedPids
        ..clear()
        ..addAll(_visibleRows
            .where((row) => row.isExpandable)
            .map((row) => row.info.pid));
    });
  }

  void _expandAll() {
    setState(() {
      _collapsedPids.clear();
    });
  }

  List<_ProcessTreeRowData> _buildProcessRowData(
    List<_ProcessInfo> processes,
  ) {
    if (processes.isEmpty) {
      return const [];
    }
    final nodes = {
      for (final info in processes) info.pid: _ProcessNode(info),
    };
    final roots = <_ProcessNode>[];
    for (final node in nodes.values) {
      final parent = nodes[node.info.ppid];
      if (parent != null && parent != node) {
        parent.children.add(node);
      } else {
        roots.add(node);
      }
    }

    double sortValueCpu(_ProcessNode node) => _aggregateCpu(node);
    double sortValueMem(_ProcessNode node) => _aggregateMem(node);

    void sortNodes(List<_ProcessNode> list) {
      list.sort((a, b) {
        int result;
        switch (_sortColumn) {
          case _ProcessSortColumn.cpu:
            result = sortValueCpu(a).compareTo(sortValueCpu(b));
            break;
          case _ProcessSortColumn.memory:
            result = sortValueMem(a).compareTo(sortValueMem(b));
            break;
          case _ProcessSortColumn.pid:
            result = a.info.pid.compareTo(b.info.pid);
            break;
          case _ProcessSortColumn.command:
            result = a.info.command
                .toLowerCase()
                .compareTo(b.info.command.toLowerCase());
            break;
        }
        return _sortAscending ? result : -result;
      });
      for (final node in list) {
        sortNodes(node.children);
      }
    }

    sortNodes(roots);
    final rows = <_ProcessTreeRowData>[];
    _ProcessTreeRowData buildRow(
      _ProcessNode node,
      List<bool> ancestorFlags,
    ) {
      final totalCpu = node.info.cpu +
          node.children.fold(
            0.0,
            (sum, child) => sum + _aggregateCpu(child),
          );
      final totalMem = node.info.memoryBytes +
          node.children.fold(
            0.0,
            (sum, child) => sum + _aggregateMem(child),
          );
      final isCollapsed = _collapsedPids.contains(node.info.pid);
      return _ProcessTreeRowData(
        info: node.info,
        ancestorLastFlags: ancestorFlags,
        isExpandable: node.children.isNotEmpty,
        isCollapsed: isCollapsed,
        totalCpu: totalCpu,
        totalMem: totalMem,
      );
    }

    void visit(_ProcessNode node, List<bool> ancestorFlags) {
      rows.add(buildRow(node, ancestorFlags));
      final isCollapsed = _collapsedPids.contains(node.info.pid);
      if (isCollapsed) {
        return;
      }
      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        final isLast = i == node.children.length - 1;
        visit(child, [...ancestorFlags, isLast]);
      }
    }

    for (final root in roots) {
      visit(root, const []);
    }
    return rows;
  }

  double _aggregateCpu(_ProcessNode node) {
    return node.info.cpu +
        node.children.fold(0.0, (sum, child) => sum + _aggregateCpu(child));
  }

  double _aggregateMem(_ProcessNode node) {
    return node.info.memoryBytes +
        node.children.fold(0.0, (sum, child) => sum + _aggregateMem(child));
  }
}

class _ProcessTreeRow extends StatelessWidget {
  const _ProcessTreeRow({
    required this.row,
    required this.selected,
    this.onTap,
    this.onDoubleTap,
    this.onToggleCollapse,
    this.onContextMenu,
  });

  final _ProcessTreeRowData row;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleCollapse;
  final ValueChanged<Offset>? onContextMenu;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    final prefix = _buildPrefix(row.ancestorLastFlags);
    final displayCpu = row.isCollapsed ? row.totalCpu : row.info.cpu;
    final displayMemBytes =
        row.isCollapsed ? row.totalMem : row.info.memoryBytes;
    final highlight = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onSecondaryTapDown: (details) =>
          onContextMenu?.call(details.globalPosition),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.base,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: highlight,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                '${row.info.pid}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    if (row.isExpandable)
                      GestureDetector(
                        onTap: onToggleCollapse,
                        child: Icon(
                          row.isCollapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      const SizedBox(width: 16),
                    if (prefix.isNotEmpty)
                      Text(
                        prefix,
                        style: textStyle?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        row.info.command,
                        style: textStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  displayCpu.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatBytes(displayMemBytes),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildPrefix(List<bool> ancestorFlags) {
    if (ancestorFlags.isEmpty) {
      return '';
    }
    const branch = '│   ';
    const empty = '    ';
    const tee = '├── ';
    const last = '╰── ';
    final buffer = StringBuffer();
    for (var i = 0; i < ancestorFlags.length; i++) {
      final isLastAncestor = ancestorFlags[i];
      final isTerminal = i == ancestorFlags.length - 1;
      if (isTerminal) {
        buffer.write(isLastAncestor ? last : tee);
      } else {
        buffer.write(isLastAncestor ? empty : branch);
      }
    }
    return buffer.toString();
  }
}

class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader({
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });

  final _ProcessSortColumn sortColumn;
  final bool ascending;
  final ValueChanged<_ProcessSortColumn> onSort;

  Widget _buildHeaderCell({
    required BuildContext context,
    required String label,
    required _ProcessSortColumn column,
    double? width,
    bool expand = false,
  }) {
    final isActive = sortColumn == column;
    final icon = isActive
        ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
        : null;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (icon != null) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 12),
        ],
      ],
    );
    final child = InkWell(
      onTap: () => onSort(column),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
    if (expand) {
      return Expanded(child: child);
    }
    return SizedBox(
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _buildHeaderCell(
                context: context,
                label: 'PID',
                column: _ProcessSortColumn.pid,
                width: 90,
              ),
              _buildHeaderCell(
                context: context,
                label: 'Command',
                column: _ProcessSortColumn.command,
                expand: true,
              ),
              _buildHeaderCell(
                context: context,
                label: 'CPU',
                column: _ProcessSortColumn.cpu,
                width: 110,
              ),
              _buildHeaderCell(
                context: context,
                label: 'Memory',
                column: _ProcessSortColumn.memory,
                width: 110,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatBytes(double bytes) {
  if (bytes.isNaN || bytes <= 0) {
    return '0 MB';
  }
  const double kb = 1024;
  const double mb = kb * 1024;
  const double gb = mb * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(0)} MB';
  }
  return '${(bytes / kb).toStringAsFixed(0)} KB';
}

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.offset);

  final int offset;
}
