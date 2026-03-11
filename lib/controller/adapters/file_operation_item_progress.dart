import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';

class FileOperationItemProgress {
  FileOperationItemProgress({
    required this.controller,
    required this.label,
    this.itemIndex,
  });

  final FileOperationProgressController controller;
  final String label;
  final int? itemIndex;

  bool _sawBytes = false;

  void start() {
    if (_hasItemIndex) {
      controller.markInProgress(itemIndex!);
      return;
    }
    controller.updateProgress(currentItem: label);
  }

  void onBytes(int bytes) {
    if (bytes <= 0) return;
    _sawBytes = true;
    if (_hasItemIndex) {
      controller.addItemBytes(itemIndex!, bytes);
      return;
    }
    controller.addBytes(bytes);
  }

  void complete() {
    if (_hasItemIndex) {
      controller.markCompleted(itemIndex!, addSize: !_sawBytes);
      return;
    }
    controller.increment();
  }

  void fail() {
    if (_hasItemIndex) {
      controller.markFailed(itemIndex!);
      return;
    }
    controller.increment();
  }

  bool get _hasItemIndex => itemIndex != null && itemIndex! >= 0;
}
