import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableColumnWidthPlanner', () {
    const planner = StructuredDataTableColumnWidthPlanner<String>();

    StructuredDataColumn<String> column({
      required String label,
      int flex = 0,
      double? width,
      double? minWidth,
    }) {
      return StructuredDataColumn<String>(
        label: label,
        flex: flex,
        width: width,
        minWidth: minWidth,
        cellBuilder: (context, row) => const SizedBox.shrink(),
      );
    }

    test('computes fixed and flex widths', () {
      final widths = planner.computeColumnWidths(
        StructuredDataTableColumnWidthPlanInput<String>(
          columns: [
            column(label: 'Fixed', width: 120),
            column(label: 'Flex A', flex: 1, minWidth: 80),
            column(label: 'Flex B', flex: 2, minWidth: 100),
          ],
          columnWidthOverrides: const [null, null, null],
          availableWidth: 600,
          fitColumnsToWidth: false,
          minColumnWidth: 72,
          maxWidthForColumn: (_) => double.infinity,
          gapWidth: 0,
        ),
      );

      expect(widths[0], 120);
      expect(widths[1], closeTo(160, 0.001));
      expect(widths[2], closeTo(320, 0.001));
    });

    test('promotes widthless columns to flex when fitting to width', () {
      final widths = planner.computeColumnWidths(
        StructuredDataTableColumnWidthPlanInput<String>(
          columns: [
            column(label: 'A', minWidth: 80),
            column(label: 'B', minWidth: 90),
          ],
          columnWidthOverrides: const [null, null],
          availableWidth: 300,
          fitColumnsToWidth: true,
          minColumnWidth: 72,
          maxWidthForColumn: (_) => double.infinity,
          gapWidth: 0,
        ),
      );

      expect(widths[0], closeTo(150, 0.001));
      expect(widths[1], closeTo(150, 0.001));
    });

    test('respects manual overrides and max width caps', () {
      final widths = planner.computeColumnWidths(
        StructuredDataTableColumnWidthPlanInput<String>(
          columns: [
            column(label: 'A', minWidth: 80),
            column(label: 'B', flex: 1, minWidth: 90),
          ],
          columnWidthOverrides: const [200, null],
          availableWidth: 500,
          fitColumnsToWidth: false,
          minColumnWidth: 72,
          maxWidthForColumn: (index) => index == 0 ? 180 : double.infinity,
          gapWidth: 0,
        ),
      );

      expect(widths[0], 200);
      expect(widths[1], 300);
    });

    test('adds trailing slack to last column in fit mode', () {
      final widths = planner.computeColumnWidths(
        StructuredDataTableColumnWidthPlanInput<String>(
          columns: [
            column(label: 'A', width: 100),
            column(label: 'B', width: 100),
          ],
          columnWidthOverrides: const [null, null],
          availableWidth: 260,
          fitColumnsToWidth: true,
          minColumnWidth: 72,
          maxWidthForColumn: (_) => double.infinity,
          gapWidth: 0,
        ),
      );

      expect(widths, [100, 160]);
    });

    test('computes total content width with gaps', () {
      final width = planner.tableContentWidth([100, 120, 80], 12);
      expect(width, 324);
    });
  });
}
