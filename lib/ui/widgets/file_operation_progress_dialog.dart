import 'package:flutter/material.dart';

class FileOperationProgressController {
  FileOperationProgressController({
    required this.operation,
    required this.totalItems,
  });

  final String operation;
  final int totalItems;
  int _completedItems = 0;
  String? _currentItem;
  double? _currentItemProgress;
  VoidCallback? _onUpdate;

  int get completedItems => _completedItems;
  String? get currentItem => _currentItem;
  double? get currentItemProgress => _currentItemProgress;

  void setUpdateCallback(VoidCallback callback) {
    _onUpdate = callback;
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

  void increment() {
    _completedItems++;
    _onUpdate?.call();
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
    VoidCallback? onCancel,
  }) {
    final controller = FileOperationProgressController(
      operation: operation,
      totalItems: totalItems,
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
  @override
  void initState() {
    super.initState();
    widget.controller.setUpdateCallback(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final overallProgress = widget.controller.totalItems > 0
        ? (widget.controller.completedItems / widget.controller.totalItems)
            .clamp(0.0, 1.0)
        : 0.0;

    return AlertDialog(
      title: Text(widget.controller.operation),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress: ${widget.controller.completedItems} / ${widget.controller.totalItems}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
            ),
            if (widget.controller.currentItem != null) ...[
              const SizedBox(height: 16),
              Text(
                'Current: ${widget.controller.currentItem}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.controller.currentItemProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: widget.controller.currentItemProgress,
                  minHeight: 6,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}

