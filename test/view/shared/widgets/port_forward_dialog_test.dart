import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/shared/widgets/port_forward_dialog.dart';

void main() {
  group('PortForwardDialog', () {
    testWidgets('blocks submit when local ports are duplicated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _DialogHarness(
          initialRequests: [
            PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 8080,
              localPort: 8080,
              label: 'api',
            ),
          ],
          portValidator: (_) async => true,
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add mapping'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate local port'), findsNWidgets(2));
      expect(find.text('Result: none'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('returns only enabled mappings on apply', (tester) async {
      await tester.pumpWidget(
        _DialogHarness(
          initialRequests: [
            PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 8080,
              localPort: 18080,
              label: 'api',
            ),
            PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 9090,
              localPort: 19090,
              label: 'metrics',
            ),
          ],
          portValidator: (_) async => true,
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Result count: 1'), findsOneWidget);
      expect(find.text('Ports: 18080->8080'), findsOneWidget);
    });
  });
}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness({
    required this.initialRequests,
    required this.portValidator,
  });

  final List<PortForwardRequest> initialRequests;
  final PortValidator portValidator;

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  List<PortForwardRequest>? _result;

  Future<void> _openDialog(BuildContext context) async {
    final result = await showPortForwardDialog(
      context: context,
      title: 'Port forward',
      requests: widget.initialRequests,
      portValidator: widget.portValidator,
    );
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeFactory.build(
      settings: const AppSettings(),
      brightness: Brightness.light,
    );
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (dialogContext) => Column(
            children: [
              ElevatedButton(
                onPressed: () => _openDialog(dialogContext),
                child: const Text('Open dialog'),
              ),
              Text(
                _result == null
                    ? 'Result: none'
                    : 'Result count: ${_result!.length}',
              ),
              if (_result != null)
                Text(
                  'Ports: ${_result!.map((r) => '${r.localPort}->${r.remotePort}').join(', ')}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
