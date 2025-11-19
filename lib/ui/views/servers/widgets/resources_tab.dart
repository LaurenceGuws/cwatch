import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../models/ssh_host.dart';
import '../../../theme/app_theme.dart';
import 'resources/resource_utils.dart';
import 'resources/process_tree_view.dart';
import 'resources/resource_models.dart';
import 'resources/resource_panels.dart';
import 'resources/resource_parser.dart';
import 'resources/resource_widgets.dart';

class ResourcesTab extends StatefulWidget {
  const ResourcesTab({super.key, required this.host});

  final SshHost host;

  @override
  State<ResourcesTab> createState() => _ResourcesTabState();
}

class _ResourcesTabState extends State<ResourcesTab> {
  final ProcessTreeController _processTreeController =
      ProcessTreeController();
  ResourceSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  late final HistoryManager _historyManager;
  late final NetworkRateCalculator _networkRateCalculator;
  late final ResourceParser _resourceParser;

  static const _historyCapacity = 30;
  static const double _sampleWindowSeconds = 0.4;

  @override
  void initState() {
    super.initState();
    _historyManager = HistoryManager(capacity: _historyCapacity);
    _networkRateCalculator = NetworkRateCalculator();
    _resourceParser = ResourceParser(
      host: widget.host,
      sampleWindowSeconds: _sampleWindowSeconds,
    );
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
      final rawSnapshot = await _resourceParser.collectSnapshot();
      final netRates = _networkRateCalculator.computeNetRates(rawSnapshot.netTotals);
      final snapshot = ResourceSnapshot(
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
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _historyManager.appendCpu(snapshot.cpuUsage);
        _historyManager.appendMemory(snapshot.memoryUsedPct);
        _historyManager.appendDiskIo(snapshot.totalDiskIo);
        _historyManager.appendNetIn(snapshot.netInMbps);
        _historyManager.appendNetOut(snapshot.netOutMbps);
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

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final rawSnapshot = await _resourceParser.collectSnapshot();
      final netRates = _networkRateCalculator.computeNetRates(rawSnapshot.netTotals);
      final snapshot = ResourceSnapshot(
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
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _historyManager.appendCpu(snapshot.cpuUsage);
        _historyManager.appendMemory(snapshot.memoryUsedPct);
        _historyManager.appendDiskIo(snapshot.totalDiskIo);
        _historyManager.appendNetIn(snapshot.netInMbps);
        _historyManager.appendNetOut(snapshot.netOutMbps);
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
            CpuPanel(
              snapshot: _snapshot!,
              cpuHistory: _historyManager.cpuHistory,
            ),
            SizedBox(height: spacing.lg),
            MemoryPanel(
              snapshot: _snapshot!,
              memoryHistory: _historyManager.memoryHistory,
            ),
            SizedBox(height: spacing.lg),
            NetworkPanel(
              snapshot: _snapshot!,
              netInHistory: _historyManager.netInHistory,
              netOutHistory: _historyManager.netOutHistory,
            ),
            SizedBox(height: spacing.lg),
            DisksPanel(
              snapshot: _snapshot!,
              diskIoHistory: _historyManager.diskIoHistory,
            ),
            SizedBox(height: spacing.lg),
            SectionCard(
              title: 'Top Processes',
              subtitle: _snapshot!.processes.isEmpty
                  ? null
                  : '${_snapshot!.processes.length} sampled processes',
              trailing: _snapshot!.processes.isEmpty
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
              child: _snapshot!.processes.isEmpty
                  ? const Text('No process information available.')
                  : ProcessTreeView(
                      processes: _snapshot!.processes,
                      controller: _processTreeController,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
