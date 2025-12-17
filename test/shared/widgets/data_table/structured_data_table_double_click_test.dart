import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';

class _Row {
  const _Row(this.value);

  final String value;
}

void main() {
  testWidgets('primary double-click triggers onRowDoubleTap', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final theme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[
        AppThemeTokens.light(scheme),
      ],
    );

    _Row? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 220,
            child: StructuredDataTable<_Row>(
              rows: const [_Row('alpha')],
              columns: [
                StructuredDataColumn<_Row>(
                  label: 'Name',
                  autoFitText: (row) => row.value,
                  cellBuilder: (context, row) => Text(row.value),
                ),
              ],
              onRowDoubleTap: (row) => opened = row,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('alpha'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('alpha'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(opened?.value, 'alpha');
  });
}

