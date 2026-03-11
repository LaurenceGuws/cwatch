import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';

class DockerContainerPeekStateController {
  DockerContainerPeekStateController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Future<Map<String, Map<String, double>>>? _allStatsFuture;
  Map<String, Map<String, double>>? _cachedStats;

  Map<String, List<DockerContainer>> groupContainers(
    List<DockerContainer> containers,
  ) {
    final map = <String, List<DockerContainer>>{};
    for (final container in containers) {
      final key = container.composeProject?.isNotEmpty == true
          ? 'Compose: ${container.composeProject}'
          : 'Standalone';
      map.putIfAbsent(key, () => []).add(container);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Standalone') return 1;
        if (b == 'Standalone') return -1;
        return a.compareTo(b);
      });
    return {for (final key in sortedKeys) key: map[key]!};
  }

  int? flatIndexFor(
    List<DockerContainer> containers,
    DockerContainer container,
  ) {
    final index = containers.indexWhere((item) => item.id == container.id);
    return index == -1 ? null : index;
  }

  String runningLabel(DockerContainer container) {
    if (container.startedAt != null) {
      final diff = _now().difference(container.startedAt!.toLocal());
      if (diff.inDays >= 1) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        return 'Running for ${days}d ${hours}h';
      }
      if (diff.inHours >= 1) {
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        return 'Running for ${hours}h ${mins}m';
      }
      if (diff.inMinutes >= 1) {
        final mins = diff.inMinutes;
        final secs = diff.inSeconds % 60;
        return 'Running for ${mins}m ${secs}s';
      }
      return 'Running for ${diff.inSeconds}s';
    }
    if (container.createdAt != null && container.createdAt!.isNotEmpty) {
      return 'Running for ${container.createdAt}';
    }
    return 'Running';
  }

  Future<Map<String, Map<String, double>>> fetchAllStats({
    required DockerClientService? dockerService,
    String? contextName,
  }) async {
    if (_cachedStats != null) {
      return _cachedStats!;
    }
    if (_allStatsFuture != null) {
      return _allStatsFuture!;
    }
    _allStatsFuture = _loadAllStats(
      dockerService: dockerService,
      contextName: contextName,
    );
    final stats = await _allStatsFuture!;
    _cachedStats = stats;
    return stats;
  }

  Future<Map<String, Map<String, double>>> _loadAllStats({
    required DockerClientService? dockerService,
    String? contextName,
  }) async {
    if (dockerService == null) {
      return {};
    }
    try {
      final stats = await dockerService.listContainerStats(context: contextName);
      final statsMap = <String, Map<String, double>>{};
      for (final stat in stats) {
        final cpu = double.tryParse(stat.cpu.replaceAll('%', '').trim()) ?? 0.0;
        final ram =
            double.tryParse(stat.memPercent.replaceAll('%', '').trim()) ?? 0.0;
        statsMap[stat.id] = {'cpu': cpu, 'ram': ram};
        statsMap[stat.name] = {'cpu': cpu, 'ram': ram};
      }
      return statsMap;
    } catch (_) {
      return {};
    }
  }

  Map<String, double> getContainerStats(
    Map<String, Map<String, double>>? allStats,
    DockerContainer container,
  ) {
    if (allStats == null) {
      return {'cpu': 0.0, 'ram': 0.0};
    }
    return allStats[container.id] ??
        allStats[container.name] ??
        {'cpu': 0.0, 'ram': 0.0};
  }

  void clearStatsCache() {
    _allStatsFuture = null;
    _cachedStats = null;
  }
}
