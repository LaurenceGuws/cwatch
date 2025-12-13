import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum FileOperationStatus { pending, inProgress, completed, failed, skipped }

class SpeedSample {
  SpeedSample({required this.timestamp, required this.bytesPerSecond});

  final DateTime timestamp;
  final double bytesPerSecond;
}

class FileOperationItem {
  FileOperationItem({
    required this.label,
    required this.sizeBytes,
    this.status = FileOperationStatus.pending,
  });

  final String label;
  final int sizeBytes;
  FileOperationStatus status;
}

class FileOperationProgressController {
  FileOperationProgressController({
    required this.operation,
    required this.totalItems,
    List<FileOperationItem>? items,
  }) : items = items ?? [] {
    _totalBytes = this.items.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    _lastSampleTime = _startTime;
  }

  final String operation;
  final int totalItems;
  final List<FileOperationItem> items;
  int _completedItems = 0;
  int _completedBytes = 0;
  int _totalBytes = 0;
  String? _currentItem;
  double? _currentItemProgress;
  VoidCallback? _onUpdate;
  bool _cancelled = false;
  final DateTime _startTime = DateTime.now();
  late DateTime _lastSampleTime;
  int _lastSampleBytes = 0;
  final List<SpeedSample> _speedSamples = [];

  int get completedItems => _completedItems;
  int get completedBytes => _completedBytes;
  int get totalBytes => _totalBytes;
  String? get currentItem => _currentItem;
  double? get currentItemProgress => _currentItemProgress;
  bool get cancelled => _cancelled;
  List<SpeedSample> get speedSamples => List.unmodifiable(_speedSamples);

  double get overallProgress {
    if (_totalBytes > 0) {
      return (_completedBytes / _totalBytes).clamp(0.0, 1.0);
    }
    if (totalItems > 0) {
      return (_completedItems / totalItems).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  double get bytesPerSecond =>
      _speedSamples.isNotEmpty ? _speedSamples.last.bytesPerSecond : 0;

  void setUpdateCallback(VoidCallback callback) {
    _onUpdate = callback;
  }

  void cancel() {
    _cancelled = true;
    _onUpdate?.call();
  }

  void updateProgress({
    int? completedItems,
    String? currentItem,
    double? currentItemProgress,
  }) {
    if (completedItems != null) {
      _completedItems = completedItems;
    }
    if (currentItem != null) {
      _currentItem = currentItem;
    }
    if (currentItemProgress != null) {
      _currentItemProgress = currentItemProgress;
    }
    _onUpdate?.call();
  }

  void increment({int bytes = 0}) {
    _completedItems++;
    _completedBytes += bytes;
    _onUpdate?.call();
  }

  void addBytes(int bytes) {
    if (bytes <= 0) return;
    _completedBytes += bytes;
    _onUpdate?.call();
  }

  void markInProgress(int index) {
    if (index < 0 || index >= items.length) return;
    items[index].status = FileOperationStatus.inProgress;
    _currentItem = items[index].label;
    _onUpdate?.call();
  }

  void markCompleted(int index, {bool addSize = true}) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    item.status = FileOperationStatus.completed;
    _completedItems++;
    if (addSize) {
      _completedBytes += item.sizeBytes;
    }
    _currentItem = null;
    _currentItemProgress = null;
    _onUpdate?.call();
  }

  void markFailed(int index) {
    if (index < 0 || index >= items.length) return;
    items[index].status = FileOperationStatus.failed;
    _completedItems++;
    _onUpdate?.call();
  }

  void recordSpeedSample() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastSampleTime).inMilliseconds;
    if (elapsed <= 0) return;
    final deltaBytes = _completedBytes - _lastSampleBytes;
    final bps = deltaBytes / (elapsed / 1000);
    _speedSamples.add(SpeedSample(timestamp: now, bytesPerSecond: bps));
    if (_speedSamples.length > 120) {
      _speedSamples.removeAt(0);
    }
    _lastSampleTime = now;
    _lastSampleBytes = _completedBytes;
  }

  Duration? estimatedRemaining() {
    if (_totalBytes <= 0) return null;
    final avgBps = _speedSamples.isEmpty
        ? (_completedBytes /
              DateTime.now()
                  .difference(_startTime)
                  .inSeconds
                  .clamp(1, double.maxFinite.toInt()))
        : _speedSamples
                  .map((s) => s.bytesPerSecond)
                  .fold<double>(0, (a, b) => a + b) /
              _speedSamples.length;
    if (avgBps <= 0) return null;
    final remainingBytes = _totalBytes - _completedBytes;
    final seconds = remainingBytes / avgBps;
    return Duration(seconds: seconds.ceil());
  }
}

class FileOperationProgressDialog extends StatefulWidget {
  const FileOperationProgressDialog({
    super.key,
    required this.controller,
    this.onCancel,
  });

  final FileOperationProgressController controller;
  final VoidCallback? onCancel;

  @override
  State<FileOperationProgressDialog> createState() =>
      _FileOperationProgressDialogState();

  static FileOperationProgressController show(
    BuildContext context, {
    required String operation,
    required int totalItems,
    List<FileOperationItem>? items,
    VoidCallback? onCancel,
  }) {
    final controller = FileOperationProgressController(
      operation: operation,
      totalItems: totalItems,
      items: items,
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileOperationProgressDialog(
        controller: controller,
        onCancel: onCancel,
      ),
    );
    return controller;
  }
}

class _FileOperationProgressDialogState
    extends State<FileOperationProgressDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.setUpdateCallback(() {
      if (mounted) {
        setState(() {});
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        widget.controller.recordSpeedSample();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final overallProgress = controller.overallProgress;
    final speed = controller.bytesPerSecond;
    final eta = controller.estimatedRemaining();
    final hasItems = controller.items.isNotEmpty;
    final media = MediaQuery.of(context);
    final width = (media.size.width * 0.7).clamp(520.0, 900.0);
    final height = (media.size.height * 0.7).clamp(420.0, 800.0);

    return AlertDialog(
      title: Text(controller.operation),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${controller.completedItems} / ${controller.totalItems}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  speed > 0 ? '${_formatBytes(speed)}/s' : '--/s',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            if (eta != null) ...[
              const SizedBox(height: 4),
              Text(
                'Est. time remaining: ${_formatDuration(eta)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(value: overallProgress, minHeight: 10),
            const SizedBox(height: 16),
            if (controller.speedSamples.isNotEmpty) ...[
              SizedBox(
                height: 140,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _SpeedChart(samples: controller.speedSamples),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (hasItems)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    itemCount: controller.items.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_formatBytes(item.sizeBytes.toDouble())),
                        leading: _statusIcon(item.status),
                        trailing: item.status == FileOperationStatus.inProgress
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              )
            else if (controller.currentItem != null) ...[
              Text(
                'Current: ${controller.currentItem}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (controller.currentItemProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.currentItemProgress,
                  minHeight: 6,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (widget.onCancel != null)
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }

  static Widget _statusIcon(FileOperationStatus status) {
    switch (status) {
      case FileOperationStatus.pending:
        return const Icon(Icons.pause_circle_outline, size: 20);
      case FileOperationStatus.inProgress:
        return const Icon(Icons.upload, size: 20);
      case FileOperationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case FileOperationStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red, size: 20);
      case FileOperationStatus.skipped:
        return const Icon(Icons.skip_next, size: 20);
    }
  }

  static String _formatBytes(double bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 10 || value < 1 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.samples});

  final List<SpeedSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const SizedBox.shrink();
    }
    final curved = samples.length > 3;
    final maxMbps = samples
        .map((s) => s.bytesPerSecond / 1024 / 1024)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final spots = List.generate(samples.length, (i) {
      return FlSpot(i.toDouble(), samples[i].bytesPerSecond / 1024 / 1024);
    });
    return LineChart(
      LineChartData(
        minY: 0,
        minX: 0,
        maxX: samples.length <= 1 ? 1 : (samples.length - 1).toDouble(),
        maxY: (maxMbps * 1.2).clamp(0.1, double.infinity),
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: curved,
            dotData: const FlDotData(show: false),
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
          ),
        ],
      ),
    );
  }
}
