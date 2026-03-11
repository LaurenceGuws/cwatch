import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableColumnReorderProjection', () {
    const projection = StructuredDataTableColumnReorderProjection<String>();

    StructuredDataColumn<String> column(String label) {
      return StructuredDataColumn<String>(
        label: label,
        cellBuilder: (context, row) => const SizedBox.shrink(),
      );
    }

    test('rejects drop onto same column index', () {
      expect(
        projection.canAcceptDrop(sourceIndex: 1, targetIndex: 1),
        isFalse,
      );
      expect(
        projection.canAcceptDrop(sourceIndex: 1, targetIndex: 2),
        isTrue,
      );
    });

    test('reorders columns and width overrides together', () {
      final result = projection.reorder(
        columns: [column('A'), column('B'), column('C')],
        columnWidthOverrides: const [100, 200, 300],
        fromIndex: 0,
        targetIndex: 2,
      );

      expect(result.columns.map((column) => column.label).toList(), [
        'B',
        'C',
        'A',
      ]);
      expect(result.columnWidthOverrides, [200, 300, 100]);
      expect(result.resetSort, isTrue);
    });

    test('returns unchanged copies for invalid reorder input', () {
      final columns = [column('A'), column('B')];
      final overrides = [100.0, 200.0];
      final result = projection.reorder(
        columns: columns,
        columnWidthOverrides: overrides,
        fromIndex: -1,
        targetIndex: 1,
      );

      expect(result.columns.map((column) => column.label).toList(), ['A', 'B']);
      expect(result.columnWidthOverrides, [100.0, 200.0]);
      expect(identical(result.columns, columns), isFalse);
      expect(identical(result.columnWidthOverrides, overrides), isFalse);
      expect(result.resetSort, isFalse);
    });
  });
}
