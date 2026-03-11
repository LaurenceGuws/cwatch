import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/core/navigation/widgets/window_controls.dart';

void main() {
  Future<void> pumpControls(WidgetTester tester) async {
    final theme = ThemeFactory.build(
      settings: const AppSettings(),
      brightness: Brightness.light,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WindowControls(
            isMaximized: false,
            onDrag: () {},
            onToggleMaximize: () {},
            onMinimize: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationForCaptionButton(WidgetTester tester, int index) {
    final finder = find
        .descendant(
          of: find.byType(WindowControls),
          matching: find.byType(Container),
        )
        .at(index);
    final container = tester.widget<Container>(finder);
    return container.decoration! as BoxDecoration;
  }

  testWidgets('hovering non-destructive caption button adds bordered hover chrome', (
    tester,
  ) async {
    await pumpControls(tester);

    final minimizeIcon = find.byIcon(Icons.remove_rounded);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(minimizeIcon));
    await tester.pump();

    final decoration = decorationForCaptionButton(tester, 1);
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.border, isNotNull);
  });
}
