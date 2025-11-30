import 'dart:math';

import 'resource_models.dart';

/// Service for calculating network rates from network totals
class NetworkRateCalculator {
  NetTotals? _lastNetTotals;

  /// Compute network rates from current totals
  (double, double) computeNetRates(NetTotals totals) {
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

  void reset() {
    _lastNetTotals = null;
  }
}

/// Manages history lists for resource metrics
class HistoryManager {
  HistoryManager({required this.capacity});

  final int capacity;
  final List<double> _cpuHistory = [];
  final List<double> _memoryHistory = [];
  final List<double> _diskIoHistory = [];
  final List<double> _netInHistory = [];
  final List<double> _netOutHistory = [];

  List<double> get cpuHistory => List.unmodifiable(_cpuHistory);
  List<double> get memoryHistory => List.unmodifiable(_memoryHistory);
  List<double> get diskIoHistory => List.unmodifiable(_diskIoHistory);
  List<double> get netInHistory => List.unmodifiable(_netInHistory);
  List<double> get netOutHistory => List.unmodifiable(_netOutHistory);

  void appendCpu(double value) => _appendHistory(_cpuHistory, value);
  void appendMemory(double value) => _appendHistory(_memoryHistory, value);
  void appendDiskIo(double value) => _appendHistory(_diskIoHistory, value, clampTo100: false);
  void appendNetIn(double value) => _appendHistory(_netInHistory, value, clampTo100: false);
  void appendNetOut(double value) => _appendHistory(_netOutHistory, value, clampTo100: false);

  void _appendHistory(
    List<double> history,
    double value, {
    bool clampTo100 = true,
  }) {
    history.add(clampTo100 ? value.clamp(0, 100) : value);
    if (history.length > capacity) {
      history.removeAt(0);
    }
  }
}

