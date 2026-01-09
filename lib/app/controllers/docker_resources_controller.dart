import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:cwatch/models/docker_container_stat.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';

class DockerResourcesController extends ChangeNotifier {
  DockerResourcesController({
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
    this.pollInterval = const Duration(seconds: 5),
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final Duration pollInterval;

  List<DockerContainerStat> stats = const [];
  bool loading = true;
  String? error;
  Timer? _pollTimer;

  int sortColumnIndex = 0;
  bool sortAscending = true;

  final Map<String, List<double>> cpuHistoryByContainer = {};
  final Map<String, List<double>> memPercentHistoryByContainer = {};
  final Map<String, List<double>> memUsageHistoryByContainer = {};
  final Map<String, List<double>> netIoHistoryByContainer = {};
  final Map<String, List<double>> blockIoHistoryByContainer = {};
  static const int historyLimit = 60;

  Future<void> initialize() async {
    await loadStats(initial: true);
    startPolling();
  }

  Future<void> loadStats({bool initial = false}) async {
    if (initial) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final newStats = await _load();
      stats = newStats;
      loading = false;
      error = null;
      recordHistory(newStats);
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger().warn(
        'Failed to refresh docker stats',
        tag: 'Docker',
        error: e,
        stackTrace: stackTrace,
      );
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  Future<List<DockerContainerStat>> _load() async {
    if (remoteHost != null && shellService != null) {
      final output = await shellService!.runCommand(
        remoteHost!,
        "docker stats --no-stream --format '{{json .}}'",
        timeout: const Duration(seconds: 8),
      );
      return _parseStats(output);
    }
    return docker.listContainerStats(context: contextName);
  }

  List<DockerContainerStat> _parseStats(String output) {
    final stats = <DockerContainerStat>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          stats.add(
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
      } catch (e, stackTrace) {
        AppLogger().warn(
          'Failed to parse docker stats line',
          tag: 'Docker',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    return stats;
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      loadStats();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void recordHistory(List<DockerContainerStat> newStats) {
    void record(
      Map<String, List<double>> target,
      String key,
      double? value,
    ) {
      if (value == null) return;
      final series = target.putIfAbsent(key, () => []);
      series.add(value);
      if (series.length > historyLimit) {
        series.removeRange(0, series.length - historyLimit);
      }
    }

    for (final stat in newStats) {
      final name = stat.name.isNotEmpty ? stat.name : stat.id;
      record(cpuHistoryByContainer, name, _cpuPercent(stat));
      record(memPercentHistoryByContainer, name, _memPercent(stat));
      record(memUsageHistoryByContainer, name, _memUsageBytes(stat) ?? 0);
      record(netIoHistoryByContainer, name, parseBytePair(stat.netIO));
      record(blockIoHistoryByContainer, name, parseBytePair(stat.blockIO));
    }
  }

  double? _cpuPercent(DockerContainerStat stat) {
    final value = stat.cpu.replaceAll('%', '');
    return double.tryParse(value);
  }

  double? _memPercent(DockerContainerStat stat) {
    final value = stat.memPercent.replaceAll('%', '');
    return double.tryParse(value);
  }

  double? _memUsageBytes(DockerContainerStat stat) {
    return _parseBytes(stat.memUsage);
  }


  double? _parseBytes(String value) {
    final used = value.split('/').first.trim();
    return _parseByteValue(used);
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

  void setSort(int columnIndex, bool ascending) {
    sortColumnIndex = columnIndex;
    sortAscending = ascending;
    notifyListeners();
  }

  double parseBytePair(String value) {
    final parts = value.split('/');
    final double first = parts.isNotEmpty
        ? (_parseByteValue(parts[0].trim()) ?? 0)
        : 0;
    final double second = parts.length > 1
        ? (_parseByteValue(parts[1].trim()) ?? 0)
        : 0;
    return first + second;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
