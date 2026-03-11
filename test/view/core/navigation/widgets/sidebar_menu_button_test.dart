import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/core/navigation/widgets/sidebar_menu_button.dart';

void main() {
  Future<void> pumpButton(WidgetTester tester) async {
    final theme = ThemeFactory.build(
      settings: const AppSettings(),
      brightness: Brightness.light,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SidebarMenuButton(
              collapsed: false,
              onShowOptions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationFor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(SidebarMenuButton),
        matching: find.byType(Container),
      ).first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('hovering adds bordered hover chrome to sidebar menu button', (
    tester,
  ) async {
    await pumpButton(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
      location: tester.getCenter(find.byType(SidebarMenuButton)),
    );
    await tester.pump();

    final decoration = decorationFor(tester);
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.border, isNotNull);
  });
}
