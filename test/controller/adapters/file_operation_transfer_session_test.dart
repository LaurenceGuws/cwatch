import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/file_operation_transfer_session.dart';
import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';

void main() {
  group('FileOperationTransferSession', () {
    test('completes with success message and refresh', () async {
      final controller = FileOperationProgressController(
        operation: 'Uploading',
        totalItems: 2,
        maxConcurrency: 2,
      );
      final messages = <String>[];
      var refreshCount = 0;
      final session = FileOperationTransferSession(
        progressController: controller,
        isMounted: () => true,
        showMessage: messages.add,
      );

      await session.complete(
        successCount: 2,
        failCount: 0,
        successVerb: 'Uploaded',
        cancelledMessage: 'Upload cancelled',
        refresh: () async {
          refreshCount++;
        },
      );

      expect(refreshCount, 1);
      expect(messages, ['Uploaded 2 items']);
    });

    test('completes with partial-failure message', () async {
      final controller = FileOperationProgressController(
        operation: 'Uploading',
        totalItems: 3,
        maxConcurrency: 2,
      );
      final messages = <String>[];
      final session = FileOperationTransferSession(
        progressController: controller,
        isMounted: () => true,
        showMessage: messages.add,
      );

      await session.complete(
        successCount: 1,
        failCount: 2,
        successVerb: 'Uploaded',
        cancelledMessage: 'Upload cancelled',
        refresh: () async {},
      );

      expect(messages, ['Uploaded 1 item. 2 failed.']);
    });

    test('skips refresh when configured and no successes occurred', () async {
      final controller = FileOperationProgressController(
        operation: 'Uploading',
        totalItems: 1,
        maxConcurrency: 1,
      );
      var refreshCount = 0;
      final session = FileOperationTransferSession(
        progressController: controller,
        isMounted: () => true,
        showMessage: (_) {},
      );

      await session.complete(
        successCount: 0,
        failCount: 1,
        successVerb: 'Uploaded',
        cancelledMessage: 'Upload cancelled',
        refresh: () async {
          refreshCount++;
        },
        refreshOnSuccessOnly: true,
      );

      expect(refreshCount, 0);
    });

    test('shows cancelled message when controller is cancelled', () async {
      final controller = FileOperationProgressController(
        operation: 'Downloading',
        totalItems: 1,
        maxConcurrency: 1,
      )..cancel();
      final messages = <String>[];
      final session = FileOperationTransferSession(
        progressController: controller,
        isMounted: () => true,
        showMessage: messages.add,
      );

      await session.complete(
        successCount: 0,
        failCount: 0,
        successVerb: 'Downloaded',
        cancelledMessage: 'Download cancelled',
        refresh: () async {},
      );

      expect(messages, ['Download cancelled']);
    });

    test('shows failed verb message on failure', () {
      final controller = FileOperationProgressController(
        operation: 'Downloading',
        totalItems: 1,
        maxConcurrency: 1,
      );
      final messages = <String>[];
      final session = FileOperationTransferSession(
        progressController: controller,
        isMounted: () => true,
        showMessage: messages.add,
      );

      session.fail(StateError('boom'), failedVerb: 'Download');

      expect(messages.single, startsWith('Download failed:'));
    });
  });
}
