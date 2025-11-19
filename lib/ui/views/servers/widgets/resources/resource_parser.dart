import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../../../models/ssh_host.dart';
import 'resource_models.dart';

/// Service for parsing resource data from SSH output
class ResourceParser {
  ResourceParser({
    required this.host,
    required this.sampleWindowSeconds,
  });

  final SshHost host;
  final double sampleWindowSeconds;

  /// Collect resource snapshot by running SSH script
  Future<ResourceSnapshot> collectSnapshot() async {
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
sleep $sampleWindowSeconds
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
      sampleWindowSeconds,
    );
    final disks = _parseDisks(diskUsageLines, diskIoRates);
    final totalMemoryBytes =
        (memStats.totalGb * pow(1024, 3)).toDouble();
    final processes = _parseProcesses(procLines, totalMemoryBytes);
    final netTotals = _parseNetworkTotals(netLines);
    final diskIoTotal = diskIoRates.values.fold<double>(
      0,
      (sum, rate) => sum + rate.readMbps + rate.writeMbps,
    );

    return ResourceSnapshot(
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
      netInMbps: 0, // Will be computed by caller
      netOutMbps: 0, // Will be computed by caller
      totalDiskIo: diskIoTotal,
      netTotals: netTotals,
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

  MemStats _parseMemInfo(List<String> lines) {
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

    return MemStats(
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

  Map<String, DiskIoRate> _parseDiskIoRates(
    List<String> beforeLines,
    List<String> afterLines,
    double intervalSeconds,
  ) {
    Map<String, DiskStatSample> parse(List<String> lines) {
      final samples = <String, DiskStatSample>{};
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 14) continue;
        final name = parts[2];
        final readSectors = int.tryParse(parts[5]) ?? 0;
        final writeSectors = int.tryParse(parts[9]) ?? 0;
        samples[name] = DiskStatSample(
          readSectors: readSectors,
          writeSectors: writeSectors,
        );
      }
      return samples;
    }

    final before = parse(beforeLines);
    final after = parse(afterLines);
    final rates = <String, DiskIoRate>{};
    for (final entry in after.entries) {
      final beforeSample = before[entry.key];
      if (beforeSample == null) continue;
      final readSectors =
          max(0, entry.value.readSectors - beforeSample.readSectors);
      final writeSectors =
          max(0, entry.value.writeSectors - beforeSample.writeSectors);
      final readBytesPerSecond = (readSectors * 512) / intervalSeconds;
      final writeBytesPerSecond = (writeSectors * 512) / intervalSeconds;
      rates[entry.key] = DiskIoRate(
        readMbps: (readBytesPerSecond * 8) / 1e6,
        writeMbps: (writeBytesPerSecond * 8) / 1e6,
      );
    }
    return rates;
  }

  List<DiskUsage> _parseDisks(
    List<String> lines,
    Map<String, DiskIoRate> ioRates,
  ) {
    final disks = <DiskUsage>[];
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
        DiskUsage(
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

  List<ProcessInfo> _parseProcesses(
    List<String> lines,
    double totalMemoryBytes,
  ) {
    final processes = <ProcessInfo>[];
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
        ProcessInfo(
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

  NetTotals _parseNetworkTotals(List<String> lines) {
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
    return NetTotals(rxBytes: rx, txBytes: tx, timestamp: DateTime.now());
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
          host.name,
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
}

extension<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
  E? elementAtOrNull(int index) => index >= length ? null : this[index];
}

