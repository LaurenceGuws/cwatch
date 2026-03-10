import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/shared/widgets/explorer_dialog_builders.dart';

void main() {
  group('ExplorerDialogBuilders', () {
    testWidgets('delete dialog returns true and shows permanent delete wording', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          openDialog: (context, setResult, setMessage) async {
            final result = await ExplorerDialogBuilders.showDeleteDialog(
              context,
              _fileEntry,
              _host,
              true,
            );
            setResult(result);
            setMessage(null);
          },
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete notes.txt permanently?'), findsOneWidget);
      expect(
        find.text('This will permanently delete notes.txt from prod-host.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Result: true'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('navigate-to-subdirectory reports when none are available', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Harness(
          openDialog: (context, setResult, setMessage) async {
            final result =
                await ExplorerDialogBuilders.showNavigateToSubdirectoryDialog(
                  context,
                  const [],
                  setMessage,
                );
            setResult(result);
          },
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Message: No subdirectories available'), findsOneWidget);
      expect(find.text('Result: none'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}

typedef _OpenDialog =
    Future<void> Function(
      BuildContext context,
      void Function(Object? result) setResult,
      void Function(String? message) setMessage,
    );

class _Harness extends StatefulWidget {
  const _Harness({required this.openDialog});

  final _OpenDialog openDialog;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Object? _result;
  String? _message;

  void _setResult(Object? result) {
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
  }

  void _setMessage(String? message) {
    if (!mounted) {
      return;
    }
    setState(() => _message = message);
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
                onPressed: () =>
                    widget.openDialog(dialogContext, _setResult, _setMessage),
                child: const Text('Open dialog'),
              ),
              Text(
                _result == null ? 'Result: none' : 'Result: ${_result.toString()}',
              ),
              if (_message != null) Text('Message: $_message'),
            ],
          ),
        ),
      ),
    );
  }
}

const _host = SshHost(
  name: 'prod-host',
  hostname: 'example.com',
  port: 22,
  available: true,
);

final _fileEntry = RemoteFileEntry(
  name: 'notes.txt',
  isDirectory: false,
  sizeBytes: 42,
  modified: DateTime(2024, 1, 1),
);
