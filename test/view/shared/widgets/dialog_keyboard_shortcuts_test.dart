import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';

void main() {
  group('DialogKeyboardShortcuts', () {
    testWidgets('enter confirms and escape cancels for single-line inputs', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: DialogKeyboardShortcuts(
              onConfirm: () => confirmed += 1,
              onCancel: () => cancelled += 1,
              child: const TextField(maxLines: 1, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(confirmed, 1);
      expect(cancelled, 1);
    });

    testWidgets('enter does not confirm while a multiline text field is focused', (
      tester,
    ) async {
      var confirmed = 0;
      var cancelled = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: DialogKeyboardShortcuts(
              onConfirm: () => confirmed += 1,
              onCancel: () => cancelled += 1,
              child: const TextField(maxLines: 3, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(confirmed, 0);
      expect(cancelled, 1);
    });

    testWidgets('returns child directly when no shortcuts are configured', (
      tester,
    ) async {
      const marker = Key('plain-child');

      await tester.pumpWidget(
        const MaterialApp(
          home: Material(
            child: DialogKeyboardShortcuts(
              child: SizedBox(key: marker),
            ),
          ),
        ),
      );

      expect(find.byKey(marker), findsOneWidget);
      expect(find.byType(CallbackShortcuts), findsNothing);
    });
  });
}
