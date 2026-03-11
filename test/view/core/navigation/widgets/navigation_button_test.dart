import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/core/navigation/widgets/navigation_button.dart';

void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required bool selected,
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
            child: NavigationButton(
              destinationId: 'servers',
              icon: NerdIcon.servers,
              label: 'Servers',
              selected: selected,
              onSelect: (_) {},
              vertical: true,
              verticalWidth: 56,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationFor(WidgetTester tester) {
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(NavigationButton),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    return animated.decoration! as BoxDecoration;
  }

  testWidgets('hovering adds bordered hover chrome to unselected nav button', (
    tester,
  ) async {
    await pumpButton(tester, selected: false);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.byType(NavigationButton)));
    await tester.pump();

    final decoration = decorationFor(tester);
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.border, isNotNull);
  });

  testWidgets('selected nav button keeps selected background', (tester) async {
    await pumpButton(tester, selected: true);

    final decoration = decorationFor(tester);
    expect(decoration.color, isNot(Colors.transparent));
  });
}
