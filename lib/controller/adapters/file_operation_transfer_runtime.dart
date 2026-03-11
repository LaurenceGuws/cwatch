import 'package:flutter/widgets.dart';

import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';

import 'file_operation_transfer_session.dart';

class FileOperationTransferRuntime {
  FileOperationTransferRuntime({
    required this.progressController,
    required this.session,
  });

  final FileOperationProgressController progressController;
  final FileOperationTransferSession session;

  static FileOperationTransferRuntime show({
    required BuildContext context,
    required String operation,
    required int totalItems,
    required List<FileOperationItem>? items,
    required int maxConcurrency,
    required void Function(String message) showMessage,
  }) {
    late final FileOperationProgressController progressController;
    progressController = FileOperationProgressDialog.show(
      context,
      operation: operation,
      totalItems: totalItems,
      items: items,
      maxConcurrency: maxConcurrency,
      showConcurrencyControls: true,
      onCancel: () {
        progressController.cancel();
      },
    );
    final session = FileOperationTransferSession(
      progressController: progressController,
      isMounted: () => context.mounted,
      showMessage: showMessage,
    );
    return FileOperationTransferRuntime(
      progressController: progressController,
      session: session,
    );
  }
}
