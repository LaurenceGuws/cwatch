import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cwatch/model/services_infra/kubernetes/kubectl_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class KubernetesResourcesController extends ChangeNotifier {
  KubernetesResourcesController({
    required this.kubectl,
    required this.contextName,
    required this.configPath,
    this.pollInterval = const Duration(seconds: 15),
  });

  final KubectlService kubectl;
  final String contextName;
  final String configPath;
  final Duration pollInterval;

  KubeResourceSnapshot? snapshot;
  bool loading = true;
  String? error;
  Timer? _pollTimer;

  final Map<String, List<double>> nodeCpuHistory = {};
  final Map<String, List<double>> nodeMemHistory = {};
  static const int historyLimit = 90;

  String? namespaceFilter;
  bool includeSystemNamespaces = false;
  int podLimit = 50;
  PodSortMetric podSortMetric = PodSortMetric.cpu;

  int nodeSortColumn = 1;
  bool nodeSortAscending = false;
  int podSortColumn = 2;
  bool podSortAscending = false;

  Future<void> initialize() async {
    await loadResources(initial: true);
    startPolling();
  }

  Future<void> loadResources({bool initial = false}) async {
    if (initial) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final newSnapshot = await kubectl.fetchResources(
        contextName: contextName,
        configPath: configPath,
      );
      snapshot = newSnapshot;
      loading = false;
      error = null;
      recordHistory(newSnapshot);
      notifyListeners();
    } catch (e, stackTrace) {
      AppLogger().warn(
        'Failed to load Kubernetes resources',
        tag: 'Kubernetes',
        error: e,
        stackTrace: stackTrace,
      );
      error = e.toString();
      loading = false;
      notifyListeners();
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      loadResources();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void recordHistory(KubeResourceSnapshot snapshot) {
    void record(Map<String, List<double>> target, String key, double? value) {
      if (value == null) return;
      final series = target.putIfAbsent(key, () => []);
      series.add(value);
      if (series.length > historyLimit) {
        series.removeRange(0, series.length - historyLimit);
      }
    }

    for (final node in snapshot.nodes) {
      record(nodeCpuHistory, node.name, node.cpuPercent ?? node.cpuCores ?? 0);
      record(
        nodeMemHistory,
        node.name,
        (node.memoryBytes ?? 0) / (1024 * 1024),
      );
    }
  }

  void setNamespaceFilter(String? value) {
    namespaceFilter = value;
    notifyListeners();
  }

  void setIncludeSystemNamespaces(bool value) {
    includeSystemNamespaces = value;
    notifyListeners();
  }

  void setPodLimit(int value) {
    podLimit = value;
    notifyListeners();
  }

  void setPodSortMetric(PodSortMetric value) {
    podSortMetric = value;
    podSortColumn = switch (value) {
      PodSortMetric.cpu => 2,
      PodSortMetric.memory => 3,
      PodSortMetric.name => 1,
      PodSortMetric.namespace => 0,
    };
    podSortAscending = false;
    notifyListeners();
  }

  void setNodeSort(int columnIndex, bool ascending) {
    nodeSortColumn = columnIndex;
    nodeSortAscending = ascending;
    notifyListeners();
  }

  void setPodSort(int columnIndex, bool ascending) {
    podSortColumn = columnIndex;
    podSortAscending = ascending;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

enum PodSortMetric { cpu, memory, name, namespace }
