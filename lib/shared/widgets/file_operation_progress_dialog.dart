import 'dart:async';

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';

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
    this.transferredBytes = 0,
    this.status = FileOperationStatus.pending,
  });

  final String label;
  final int sizeBytes;
  int transferredBytes;
  FileOperationStatus status;
}

class FileOperationProgressController {
  FileOperationProgressController({
    required this.operation,
    required this.totalItems,
    required int maxConcurrency,
    List<FileOperationItem>? items,
  }) : items = items ?? [] {
    _totalBytes = this.items.fold<int>(0, (sum, item) => sum + item.sizeBytes);
    _lastSampleTime = _startTime;
    _maxConcurrency = _sanitizeConcurrency(maxConcurrency);
  }

  final String operation;
  final int totalItems;
  final List<FileOperationItem> items;
  int _completedItems = 0;
  int _completedBytes = 0;
  int _totalBytes = 0;
  late int _maxConcurrency;
  String? _currentItem;
  double? _currentItemProgress;
  VoidCallback? _onUpdate;
  VoidCallback? _onDismiss;
  bool _cancelled = false;
  bool _dismissed = false;
  DateTime _lastUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  final DateTime _startTime = DateTime.now();
  late DateTime _lastSampleTime;
  int _lastSampleBytes = 0;
  final List<SpeedSample> _speedSamples = [];
  static const Duration _minUpdateInterval = Duration(milliseconds: 120);

  int get completedItems => _completedItems;
  int get completedBytes => _completedBytes;
  int get totalBytes => _totalBytes;
  int get maxConcurrency => _maxConcurrency;
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

  void setDismissCallback(VoidCallback callback) {
    _onDismiss = callback;
  }

  void setMaxConcurrency(int value) {
    final next = _sanitizeConcurrency(value);
    if (next == _maxConcurrency) return;
    _maxConcurrency = next;
    _onUpdate?.call();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _onDismiss?.call();
  }

  void cancel() {
    _cancelled = true;
    _notify(force: true);
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
    _notify();
  }

  void increment({int bytes = 0}) {
    _completedItems++;
    _completedBytes += bytes;
    _notify(force: true);
  }

  void addBytes(int bytes) {
    if (bytes <= 0) return;
    _completedBytes += bytes;
    _notify();
  }

  void addItemBytes(int index, int bytes) {
    if (bytes <= 0) return;
    if (index < 0 || index >= items.length) return;
    items[index].transferredBytes += bytes;
    _completedBytes += bytes;
    _notify();
  }

  void markInProgress(int index) {
    if (index < 0 || index >= items.length) return;
    items[index].status = FileOperationStatus.inProgress;
    _currentItem = items[index].label;
    _notify(force: true);
  }

  void markCompleted(int index, {bool addSize = true}) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    item.status = FileOperationStatus.completed;
    _completedItems++;
    if (addSize) {
      _completedBytes += item.sizeBytes;
    }
    if (!addSize &&
        item.sizeBytes > 0 &&
        item.transferredBytes < item.sizeBytes) {
      _completedBytes += item.sizeBytes - item.transferredBytes;
      item.transferredBytes = item.sizeBytes;
    }
    _currentItem = null;
    _currentItemProgress = null;
    _notify(force: true);
  }

  void markFailed(int index) {
    if (index < 0 || index >= items.length) return;
    items[index].status = FileOperationStatus.failed;
    _completedItems++;
    _notify(force: true);
  }

  void markSkipped(int index) {
    if (index < 0 || index >= items.length) return;
    items[index].status = FileOperationStatus.skipped;
    _completedItems++;
    _notify(force: true);
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
    if (remainingBytes <= 0) return null;
    final seconds = remainingBytes / avgBps;
    return Duration(seconds: seconds.ceil());
  }

  static int _sanitizeConcurrency(int value) {
    if (value < 1) return 1;
    if (value > 15) return 15;
    return value;
  }

  void _notify({bool force = false}) {
    if (_onUpdate == null) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastUpdateAt) < _minUpdateInterval) {
      return;
    }
    _lastUpdateAt = now;
    _onUpdate?.call();
  }
}

class FileOperationProgressDialog extends StatefulWidget {
  const FileOperationProgressDialog({
    super.key,
    required this.controller,
    this.onCancel,
    required this.showConcurrencyControls,
  });

  final FileOperationProgressController controller;
  final VoidCallback? onCancel;
  final bool showConcurrencyControls;

  @override
  State<FileOperationProgressDialog> createState() =>
      _FileOperationProgressDialogState();

  static FileOperationProgressController show(
    BuildContext context, {
    required String operation,
    required int totalItems,
    int maxConcurrency = 1,
    List<FileOperationItem>? items,
    VoidCallback? onCancel,
    bool showConcurrencyControls = false,
  }) {
    final controller = FileOperationProgressController(
      operation: operation,
      totalItems: totalItems,
      maxConcurrency: maxConcurrency,
      items: items,
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FileOperationProgressDialog(
        controller: controller,
        onCancel: onCancel,
        showConcurrencyControls: showConcurrencyControls,
      ),
    );
    controller.setDismissCallback(() {
      if (entry.mounted) {
        entry.remove();
      }
    });
    overlay.insert(entry);
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
    final spacing = context.appTheme.spacing;
    return Stack(
      children: [
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            minimum: EdgeInsets.all(spacing.lg),
            child: _TransferToast(
              controller: widget.controller,
              onCancel: widget.onCancel,
              showConcurrencyControls: widget.showConcurrencyControls,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferToast extends StatelessWidget {
  const _TransferToast({
    required this.controller,
    this.onCancel,
    required this.showConcurrencyControls,
  });

  final FileOperationProgressController controller;
  final VoidCallback? onCancel;
  final bool showConcurrencyControls;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final colorScheme = Theme.of(context).colorScheme;
    final section = context.appTheme.section;
    final surface = section.surface;
    final typography = context.appTheme.typography;
    final overallProgress = controller.overallProgress;
    final speed = controller.bytesPerSecond;
    final eta = controller.estimatedRemaining();
    final items = controller.items;
    final activeItems = items
        .where(
          (item) =>
              item.status == FileOperationStatus.pending ||
              item.status == FileOperationStatus.inProgress,
        )
        .toList()
      ..sort((a, b) {
        final aActive = a.status == FileOperationStatus.inProgress ? 0 : 1;
        final bActive = b.status == FileOperationStatus.inProgress ? 0 : 1;
        return aActive.compareTo(bActive);
      });
    final doneItems = items
        .where(
          (item) =>
              item.status == FileOperationStatus.completed ||
              item.status == FileOperationStatus.failed ||
              item.status == FileOperationStatus.skipped,
        )
        .toList();
    final progressTrack = section.divider.withValues(alpha: 0.35);

    return Material(
      elevation: surface.elevation,
      color: surface.background,
      shape: RoundedRectangleBorder(
        borderRadius: surface.radius,
        side: BorderSide(color: surface.borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, minWidth: 280),
        child: Padding(
          padding: surface.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    NerdIcon.cloudUpload.data,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      controller.operation,
                      style: typography.tabLabel,
                    ),
                  ),
                  if (onCancel != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: onCancel,
                    ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Builder(
                builder: (context) {
                  final baseSize = typography.caption.fontSize ?? 12;
                  final metaStyle = typography.caption.copyWith(
                    fontSize: (baseSize - 1).clamp(10, baseSize),
                  );
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress: ${controller.completedItems} / ${controller.totalItems}',
                            style: metaStyle,
                          ),
                          Text(
                            speed > 0 ? '${_formatBytes(speed)}/s' : '--/s',
                            style: metaStyle,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (showConcurrencyControls) ...[
                SizedBox(height: spacing.xs),
                Row(
                  children: [
                    Text('Parallel', style: typography.caption),
                    SizedBox(width: spacing.sm),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      tooltip: 'Decrease',
                      onPressed: () => controller.setMaxConcurrency(
                        controller.maxConcurrency - 1,
                      ),
                    ),
                    Text(
                      '${controller.maxConcurrency}',
                      style: typography.caption,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      tooltip: 'Increase',
                      onPressed: () => controller.setMaxConcurrency(
                        controller.maxConcurrency + 1,
                      ),
                    ),
                  ],
                ),
              ],
              if (eta != null) ...[
                SizedBox(height: spacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ETA ${_formatDuration(eta)}',
                    style: typography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              SizedBox(height: spacing.sm),
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                lineHeight: 8,
                percent: overallProgress,
                animation: false,
                backgroundColor: progressTrack,
                progressColor: colorScheme.primary,
                barRadius: const Radius.circular(8),
              ),
              if (items.isEmpty && controller.currentItem != null) ...[
                SizedBox(height: spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.currentItem!,
                    style: typography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.currentItemProgress != null) ...[
                  SizedBox(height: spacing.xs),
                  LinearPercentIndicator(
                    padding: EdgeInsets.zero,
                    lineHeight: 6,
                    percent: controller.currentItemProgress!.clamp(0.0, 1.0),
                    animation: false,
                    backgroundColor: progressTrack,
                    progressColor: colorScheme.secondary,
                    barRadius: const Radius.circular(8),
                  ),
                ],
              ],
              if (items.isNotEmpty) ...[
                SizedBox(height: spacing.md),
                SizedBox(
                  height: 220,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _SectionHeader(
                          title: 'Active',
                          count: activeItems.length,
                        ),
                        if (activeItems.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: spacing.sm,
                              top: spacing.xs,
                              bottom: spacing.sm,
                            ),
                            child: Text(
                              'No active transfers',
                              style: typography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          for (final item in activeItems) ...[
                            _TransferItemRow(
                              item: item,
                            ),
                            SizedBox(height: spacing.sm),
                          ],
                        _SectionHeader(
                          title: 'Done',
                          count: doneItems.length,
                        ),
                        if (doneItems.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: spacing.sm,
                              top: spacing.xs,
                            ),
                            child: Text(
                              'Nothing completed yet',
                              style: typography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          for (final item in doneItems) ...[
                            _TransferItemRow(
                              item: item,
                            ),
                            SizedBox(height: spacing.sm),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final typography = context.appTheme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(title, style: typography.tabLabel),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: typography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferItemRow extends StatelessWidget {
  const _TransferItemRow({required this.item});

  final FileOperationItem item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final typography = context.appTheme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final section = context.appTheme.section;
    final progressTrack = section.divider.withValues(alpha: 0.35);
    final isActive = item.status == FileOperationStatus.inProgress;
    final showProgress = isActive;
    final progressValue =
        item.sizeBytes > 0 && item.transferredBytes > 0
        ? (item.transferredBytes / item.sizeBytes).clamp(0.0, 1.0)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statusIcon(item.status),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.label,
                style: typography.caption,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (showProgress) ...[
          SizedBox(height: spacing.xs),
          LinearProgressIndicator(
            value: progressValue,
            minHeight: 4,
            color: colorScheme.primary,
            backgroundColor: progressTrack,
          ),
        ],
      ],
    );
  }

  static Widget _statusIcon(FileOperationStatus status) {
    switch (status) {
      case FileOperationStatus.pending:
        return const Icon(Icons.pause_circle_outline, size: 16);
      case FileOperationStatus.inProgress:
        return const Icon(Icons.upload, size: 16);
      case FileOperationStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 16);
      case FileOperationStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red, size: 16);
      case FileOperationStatus.skipped:
        return const Icon(Icons.skip_next, size: 16);
    }
  }
}
