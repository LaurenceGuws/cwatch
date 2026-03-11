import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/file_operation_item_progress.dart';
import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';

void main() {
  group('FileOperationItemProgress', () {
    test('tracks indexed item lifecycle with byte updates', () {
      final controller = FileOperationProgressController(
        operation: 'Uploading',
        totalItems: 1,
        maxConcurrency: 1,
        items: [FileOperationItem(label: 'a.txt', sizeBytes: 10)],
      );
      final progress = FileOperationItemProgress(
        controller: controller,
        label: 'a.txt',
        itemIndex: 0,
      );

      progress.start();
      progress.onBytes(4);
      progress.complete();

      expect(controller.items.single.status, FileOperationStatus.completed);
      expect(controller.completedItems, 1);
      expect(controller.completedBytes, 10);
    });

    test(
      'falls back to current-item and increment when no item index exists',
      () {
        final controller = FileOperationProgressController(
          operation: 'Uploading',
          totalItems: 1,
          maxConcurrency: 1,
        );
        final progress = FileOperationItemProgress(
          controller: controller,
          label: 'folder',
          itemIndex: -1,
        );

        progress.start();
        progress.onBytes(5);
        progress.complete();

        expect(controller.currentItem, 'folder');
        expect(controller.completedItems, 1);
        expect(controller.completedBytes, 5);
      },
    );

    test('marks indexed item failed', () {
      final controller = FileOperationProgressController(
        operation: 'Downloading',
        totalItems: 1,
        maxConcurrency: 1,
        items: [FileOperationItem(label: 'b.txt', sizeBytes: 7)],
      );
      final progress = FileOperationItemProgress(
        controller: controller,
        label: 'b.txt',
        itemIndex: 0,
      );

      progress.start();
      progress.fail();

      expect(controller.items.single.status, FileOperationStatus.failed);
      expect(controller.completedItems, 1);
    });
  });
}
