import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cwatch/app/services/resource_parser.dart';
import 'package:cwatch/app/services/resource_utils.dart';
import 'package:cwatch/data/models/resource_models.dart';
import 'package:cwatch/services/logging/app_logger.dart';

class ResourcesController extends ChangeNotifier {
  ResourcesController({
    required this.parser,
    required this.historyManager,
    required this.networkRateCalculator,
    this.pollInterval = const Duration(seconds: 5),
  });

  final ResourceParser parser;
  final HistoryManager historyManager;
  final NetworkRateCalculator networkRateCalculator;
  final Duration pollInterval;

  ResourceSnapshot? snapshot;
  bool loading = true;
  String? error;
  Timer? _pollTimer;

  Future<void> initialize() async {
    await loadResources();
  }

  Future<void> loadResources() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rawSnapshot = await parser.collectSnapshot();
      _applySnapshot(rawSnapshot);
      _startPolling();
    } catch (err, stackTrace) {
      AppLogger().warn(
        'Failed to load resources',
        tag: 'Resources',
        error: err,
        stackTrace: stackTrace,
      );
      error = err.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      final rawSnapshot = await parser.collectSnapshot();
      _applySnapshot(rawSnapshot);
      error = null;
      notifyListeners();
    } catch (err, stackTrace) {
      AppLogger().warn(
        'Resource refresh failed',
        tag: 'Resources',
        error: err,
        stackTrace: stackTrace,
      );
      error = err.toString();
      notifyListeners();
    }
  }

  void _applySnapshot(ResourceSnapshot rawSnapshot) {
    final netRates = networkRateCalculator.computeNetRates(
      rawSnapshot.netTotals,
    );
    snapshot = ResourceSnapshot(
      cpuUsage: rawSnapshot.cpuUsage,
      load1: rawSnapshot.load1,
      load5: rawSnapshot.load5,
      load15: rawSnapshot.load15,
      memoryTotalGb: rawSnapshot.memoryTotalGb,
      memoryUsedGb: rawSnapshot.memoryUsedGb,
      memoryUsedPct: rawSnapshot.memoryUsedPct,
      swapTotalGb: rawSnapshot.swapTotalGb,
      swapUsedGb: rawSnapshot.swapUsedGb,
      swapUsedPct: rawSnapshot.swapUsedPct,
      disks: rawSnapshot.disks,
      processes: rawSnapshot.processes,
      netInMbps: netRates.$1,
      netOutMbps: netRates.$2,
      totalDiskIo: rawSnapshot.totalDiskIo,
      netTotals: rawSnapshot.netTotals,
    );
    historyManager.appendCpu(rawSnapshot.cpuUsage);
    historyManager.appendMemory(rawSnapshot.memoryUsedPct);
    historyManager.appendDiskIo(rawSnapshot.totalDiskIo);
    historyManager.appendNetIn(netRates.$1);
    historyManager.appendNetOut(netRates.$2);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
