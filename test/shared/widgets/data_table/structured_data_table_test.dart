import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';

class _Row {
  const _Row(this.label);

  final String label;
}

void main() {
  testWidgets('auto-fit uses autoFitWidth to avoid under-fitting', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final theme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[AppThemeTokens.light(scheme)],
    );

    const expectedContentWidth = 420.0;
    const baselineChrome = 6 * 1.5 + 8; // mirrors StructuredDataTable baseline
    const expectedMinWidth = expectedContentWidth + baselineChrome;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 240,
            child: StructuredDataTable<_Row>(
              rows: const [_Row('row')],
              columns: [
                StructuredDataColumn<_Row>(
                  label: 'Meta',
                  autoFitWidth: (context, row) => expectedContentWidth,
                  cellBuilder: (context, row) => Text(row.label),
                ),
                StructuredDataColumn<_Row>(
                  label: 'Other',
                  width: 200,
                  cellBuilder: (context, row) => const Text('x'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final headerCell = find.byKey(
      const ValueKey('structured_data_table.header_cell.0'),
    );
    final resizeHandle = find.byKey(
      const ValueKey('structured_data_table.resize.0'),
    );

    expect(headerCell, findsOneWidget);
    expect(resizeHandle, findsOneWidget);

    final before = tester.getSize(headerCell).width;

    await tester.tap(resizeHandle);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(resizeHandle);
    await tester.pump(const Duration(milliseconds: 300));

    final after = tester.getSize(headerCell).width;

    expect(after, greaterThanOrEqualTo(expectedMinWidth - 1));
    expect(after, lessThanOrEqualTo(before));
  });
}
