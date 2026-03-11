import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';

void main() {
  StructuredDataTable<String> buildTable({
    required ValueChanged<List<String>> onSelectionChanged,
    ValueChanged<Offset>? onBackgroundContextMenu,
  }) {
    return StructuredDataTable<String>(
      rows: const ['alpha', 'beta'],
      columns: [
        StructuredDataColumn<String>(
          label: 'Name',
          cellBuilder: (context, row) => Text(row),
          sortValue: (row) => row,
        ),
      ],
      rowActions: [
        StructuredDataAction<String>(
          label: 'Open',
          icon: Icons.open_in_new,
          onSelected: (_) {},
        ),
      ],
      onSelectionChanged: onSelectionChanged,
      onBackgroundContextMenu: onBackgroundContextMenu,
    );
  }

  Future<void> pumpTable(
    WidgetTester tester, {
    required ValueChanged<List<String>> onSelectionChanged,
    ValueChanged<Offset>? onBackgroundContextMenu,
  }) async {
    final theme = ThemeFactory.build(
      settings: const AppSettings(),
      brightness: Brightness.light,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 320,
              child: buildTable(
                onSelectionChanged: onSelectionChanged,
                onBackgroundContextMenu: onBackgroundContextMenu,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('secondary click selects the clicked row before opening menu', (
    tester,
  ) async {
    var selectedRows = <String>[];
    await pumpTable(
      tester,
      onSelectionChanged: (rows) => selectedRows = rows,
    );

    final betaCenter = tester.getCenter(find.text('beta'));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(betaCenter);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedRows, ['beta']);
    expect(find.text('Open'), findsOneWidget);
  });


  testWidgets('secondary click on blank table space clears selection before background menu', (
    tester,
  ) async {
    var selectedRows = <String>[];
    Offset? backgroundMenuAnchor;
    await pumpTable(
      tester,
      onSelectionChanged: (rows) => selectedRows = rows,
      onBackgroundContextMenu: (position) => backgroundMenuAnchor = position,
    );

    final alphaCenter = tester.getCenter(find.text('alpha'));
    final selectGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await selectGesture.down(alphaCenter);
    await selectGesture.up();
    await tester.pumpAndSettle();

    expect(selectedRows, ['alpha']);

    final tableRect = tester.getRect(find.byType(StructuredDataTable<String>));
    final blankPosition = Offset(tableRect.center.dx, tableRect.bottom - 8);
    final menuGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await menuGesture.down(blankPosition);
    await menuGesture.up();
    await tester.pumpAndSettle();

    expect(selectedRows, isEmpty);
    expect(backgroundMenuAnchor, isNotNull);
  });

  testWidgets('primary click on blank table space clears selection', (
    tester,
  ) async {
    var selectedRows = <String>[];
    await pumpTable(
      tester,
      onSelectionChanged: (rows) => selectedRows = rows,
    );

    final alphaCenter = tester.getCenter(find.text('alpha'));
    final selectGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await selectGesture.down(alphaCenter);
    await selectGesture.up();
    await tester.pumpAndSettle();

    expect(selectedRows, ['alpha']);

    final tableRect = tester.getRect(find.byType(StructuredDataTable<String>));
    final blankPosition = Offset(tableRect.center.dx, tableRect.bottom - 8);
    final clearGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await clearGesture.down(blankPosition);
    await clearGesture.up();
    await tester.pumpAndSettle();

    expect(selectedRows, isEmpty);
  });
}
