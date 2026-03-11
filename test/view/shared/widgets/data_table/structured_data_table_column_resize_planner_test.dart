import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  group('StructuredDataTableColumnResizePlanner', () {
    const planner = StructuredDataTableColumnResizePlanner<String>();

    StructuredDataColumn<String> column({
      required String label,
      String Function(String row)? autoFitText,
      double? autoFitExtraWidth,
    }) {
      return StructuredDataColumn<String>(
        label: label,
        autoFitText: autoFitText,
        autoFitExtraWidth: autoFitExtraWidth,
        cellBuilder: (context, row) => const SizedBox.shrink(),
      );
    }

    test('clamps resized width to provided bounds', () {
      expect(
        planner.resizedWidth(
          currentWidth: 120,
          delta: -100,
          minWidth: 80,
          maxWidth: 300,
        ),
        80,
      );

      expect(
        planner.resizedWidth(
          currentWidth: 120,
          delta: 400,
          minWidth: 80,
          maxWidth: 300,
        ),
        300,
      );
    });

    test('auto fit uses widest measured row and extra width', () {
      final result = planner.autoFitWidth(
        column: column(
          label: 'Images',
          autoFitText: (row) => row,
          autoFitExtraWidth: 10,
        ),
        visibleRows: const ['a', 'bbb', 'cc'],
        cachedMeasuredWidth: 0,
        measureText: (text, style) => text.length * 10,
        headerStyle: const TextStyle(),
        cellStyle: const TextStyle(),
        widthExtractor: null,
        maxSamples: 400,
      );

      expect(result.maxMeasuredWidth, 60);
      expect(result.targetWidth, 80);
    });

    test('auto fit respects cached measurement and custom width extractor', () {
      final result = planner.autoFitWidth(
        column: column(label: 'CPU'),
        visibleRows: const ['x', 'y'],
        cachedMeasuredWidth: 140,
        measureText: (text, style) => text.length * 10,
        headerStyle: const TextStyle(),
        cellStyle: const TextStyle(),
        widthExtractor: (row) => row == 'x' ? 90 : 120,
        maxSamples: 400,
      );

      expect(result.maxMeasuredWidth, 140);
      expect(result.targetWidth, 150);
    });
  });
}
