import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableHitTestProjection', () {
    const projection = StructuredDataTableHitTestProjection();

    test('computes edge scroll delta near viewport edges', () {
      final delta = projection.edgeScrollDelta(
        localPosition: const Offset(5, 190),
        viewportSize: const Size(300, 200),
        edgeThreshold: 24,
        scrollStep: 18,
      );

      expect(delta.horizontal, -18);
      expect(delta.vertical, 18);
    });

    test('returns null row index outside the visible range', () {
      final rowIndex = projection.rowIndexForOffset(
        localPosition: const Offset(10, 500),
        rowCount: 4,
        rowExtent: 40,
        verticalOffset: 0,
      );

      expect(rowIndex, isNull);
    });

    test('maps local dx to first and last columns with offsets', () {
      expect(
        projection.columnIndexForLocalDx(
          localDx: 0,
          columnWidths: const [100, 120, 140],
          horizontalOffset: 0,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        0,
      );

      expect(
        projection.columnIndexForLocalDx(
          localDx: 400,
          columnWidths: const [100, 120, 140],
          horizontalOffset: 0,
          rowPaddingX: 16,
          gapWidth: 12,
        ),
        2,
      );
    });

    test('maps offset to cell coordinate with scroll offsets', () {
      final coordinate = projection.cellCoordinateForOffset(
        localPosition: const Offset(80, 10),
        rowCount: 10,
        columnWidths: const [100, 120, 140],
        rowExtent: 40,
        verticalOffset: 80,
        horizontalOffset: 20,
        rowPaddingX: 16,
        gapWidth: 12,
      );

      expect(
        coordinate,
        const StructuredDataCellCoordinate(rowIndex: 2, columnIndex: 0),
      );
    });

    test('returns null cell coordinate when there are no columns', () {
      final coordinate = projection.cellCoordinateForOffset(
        localPosition: const Offset(10, 10),
        rowCount: 3,
        columnWidths: const [],
        rowExtent: 40,
        verticalOffset: 0,
        horizontalOffset: 0,
        rowPaddingX: 16,
        gapWidth: 12,
      );

      expect(coordinate, isNull);
    });
  });
}
