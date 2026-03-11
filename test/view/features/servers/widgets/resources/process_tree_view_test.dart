import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/data/models/resource_models.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/features/servers/widgets/resources/process_tree_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester) async {
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
              width: 700,
              height: 320,
              child: ProcessTreeView(
                processes: const [
                  ProcessInfo(
                    pid: 1,
                    ppid: 0,
                    command: 'init',
                    cpu: 1.0,
                    memoryPercent: 2.0,
                    memoryBytes: 1024,
                  ),
                  ProcessInfo(
                    pid: 2,
                    ppid: 1,
                    command: 'worker',
                    cpu: 3.5,
                    memoryPercent: 4.0,
                    memoryBytes: 2048,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color? rowColor(WidgetTester tester, int pid) {
    final container = tester.widget<Container>(
      find.byKey(ValueKey('process-tree-row-$pid')),
    );
    final decoration = container.decoration as BoxDecoration?;
    return decoration?.color;
  }

  testWidgets('secondary click selects row before opening process menu', (
    tester,
  ) async {
    await pumpView(tester);

    final workerCenter = tester.getCenter(
      find.byKey(const ValueKey('process-tree-row-2')),
    );
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(workerCenter);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Info'), findsOneWidget);
    expect(rowColor(tester, 2), isNot(Colors.transparent));
  });

  testWidgets('primary click on blank surface clears process selection', (
    tester,
  ) async {
    await pumpView(tester);

    final rowCenter = tester.getCenter(
      find.byKey(const ValueKey('process-tree-row-1')),
    );
    final rowGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await rowGesture.down(rowCenter);
    await rowGesture.up();
    await tester.pumpAndSettle();
    expect(rowColor(tester, 1), isNot(Colors.transparent));

    final surface = tester.getRect(find.byKey(const ValueKey('process-tree-surface')));
    final blankPoint = Offset(surface.center.dx, surface.bottom - 8);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.down(blankPoint);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(rowColor(tester, 1), equals(Colors.transparent));
  });
}
