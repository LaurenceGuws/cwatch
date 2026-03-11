import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableScrollProjection', () {
    const projection = StructuredDataTableScrollProjection();

    test('computes page step from viewport and row extent', () {
      expect(
        projection.pageStep(viewport: 305, rowExtent: 40, fallback: 10),
        7,
      );
      expect(
        projection.pageStep(viewport: 0, rowExtent: 40, fallback: 10),
        10,
      );
    });

    test('reveals row above and below viewport', () {
      expect(
        projection.revealRowOffset(
          rowIndex: 1,
          rowExtent: 40,
          currentOffset: 120,
          viewport: 100,
          minOffset: 0,
          maxOffset: 400,
        ),
        40,
      );

      expect(
        projection.revealRowOffset(
          rowIndex: 7,
          rowExtent: 40,
          currentOffset: 120,
          viewport: 100,
          minOffset: 0,
          maxOffset: 400,
        ),
        220,
      );
    });

    test('reveals column left and right of viewport', () {
      expect(
        projection.revealColumnOffset(
          columnIndex: 0,
          columnWidths: const [100, 120, 140],
          currentOffset: 80,
          viewport: 150,
          minOffset: 0,
          maxOffset: 400,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        16,
      );

      expect(
        projection.revealColumnOffset(
          columnIndex: 2,
          columnWidths: const [100, 120, 140],
          currentOffset: 0,
          viewport: 150,
          minOffset: 0,
          maxOffset: 400,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        250,
      );
    });

    test('clamps column reveal to bounds and ignores invalid index', () {
      expect(
        projection.revealColumnOffset(
          columnIndex: 10,
          columnWidths: const [100, 120],
          currentOffset: 50,
          viewport: 100,
          minOffset: 0,
          maxOffset: 200,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        50,
      );

      expect(
        projection.revealColumnOffset(
          columnIndex: 1,
          columnWidths: const [100, 120],
          currentOffset: 0,
          viewport: 80,
          minOffset: 0,
          maxOffset: 100,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        100,
      );
    });
  });
}
