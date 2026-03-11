import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';

class FileOperationTransferSession {
  FileOperationTransferSession({
    required this.progressController,
    required this.isMounted,
    required this.showMessage,
  });

  final FileOperationProgressController progressController;
  final bool Function() isMounted;
  final void Function(String message) showMessage;

  Future<void> complete({
    required int successCount,
    required int failCount,
    required String successVerb,
    required String cancelledMessage,
    required Future<void> Function() refresh,
    bool refreshOnSuccessOnly = false,
  }) async {
    if (!isMounted()) return;
    progressController.dismiss();

    final shouldRefresh = refreshOnSuccessOnly ? successCount > 0 : true;
    if (shouldRefresh) {
      await refresh();
    }

    if (!isMounted()) return;
    if (progressController.cancelled) {
      showMessage(cancelledMessage);
      return;
    }

    if (failCount == 0) {
      showMessage(
        '$successVerb $successCount item${successCount == 1 ? '' : 's'}',
      );
      return;
    }

    showMessage(
      '$successVerb $successCount item${successCount == 1 ? '' : 's'}. $failCount failed.',
    );
  }

  void fail(Object error, {required String failedVerb}) {
    if (!isMounted()) return;
    progressController.dismiss();
    if (!isMounted()) return;
    showMessage('$failedVerb failed: $error');
  }
}
