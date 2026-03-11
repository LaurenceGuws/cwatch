import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';

void main() {
  const host = SshHost(
    name: 'server',
    hostname: 'server.local',
    port: 22,
    available: true,
  );

  Future<void> pumpChip(
    WidgetTester tester, {
    required bool selected,
    required VoidCallback onSelect,
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
            child: TabChip(
              host: host,
              label: 'Server',
              title: 'Server',
              icon: Icons.folder_outlined,
              selected: selected,
              onSelect: onSelect,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('secondary click selects unselected tab before opening menu', (
    tester,
  ) async {
    var selectCalls = 0;
    await pumpChip(
      tester,
      selected: false,
      onSelect: () => selectCalls++,
    );

    final center = tester.getCenter(find.byType(TabChip));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(center);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectCalls, 1);
    expect(find.text('Rename tab'), findsOneWidget);
  });

  testWidgets('secondary click on selected tab does not reselect', (
    tester,
  ) async {
    var selectCalls = 0;
    await pumpChip(
      tester,
      selected: true,
      onSelect: () => selectCalls++,
    );

    final center = tester.getCenter(find.byType(TabChip));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(center);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectCalls, 0);
    expect(find.text('Rename tab'), findsOneWidget);
  });
}
