import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_actions.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_entry_interactions.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/selection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileExplorerTabEntryInteractions', () {
    testWidgets('routes paste through actions with current path', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final harness = _ExplorerInteractionHarness(
        context: context,
        selectionMode: _SelectionMode.paste,
      );

      final result = harness.interactions.handleListKeyEvent(
        FocusNode(),
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.keyV,
          logicalKey: LogicalKeyboardKey.keyV,
        ),
        _entries,
      );

      expect(result, KeyEventResult.handled);
      expect(harness.actions.pasteTargets, ['/workspace']);
    });

    testWidgets('routes multi delete through actions using selected entries', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final harness = _ExplorerInteractionHarness(
        context: context,
        selectionMode: _SelectionMode.delete,
      );
      harness.selectionState.selectedPaths.addAll({
        '/workspace/alpha.txt',
        '/workspace/beta.txt',
      });

      final result = harness.interactions.handleListKeyEvent(
        FocusNode(),
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.delete,
          logicalKey: LogicalKeyboardKey.delete,
        ),
        _entries,
      );

      expect(result, KeyEventResult.handled);
      expect(
        harness.actions.multiDeleteTargets,
        [
          ['alpha.txt', 'beta.txt'],
        ],
      );
    });

    testWidgets('routes rename through actions for primary selected entry', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final harness = _ExplorerInteractionHarness(
        context: context,
        selectionMode: _SelectionMode.rename,
      );
      harness.selectionState.selectedPaths.add('/workspace/beta.txt');

      final result = harness.interactions.handleListKeyEvent(
        FocusNode(),
        const KeyDownEvent(
          timeStamp: Duration.zero,
          physicalKey: PhysicalKeyboardKey.f2,
          logicalKey: LogicalKeyboardKey.f2,
        ),
        _entries,
      );

      expect(result, KeyEventResult.handled);
      expect(harness.actions.renamedEntryNames, ['beta.txt']);
    });
  });
}

const _host = SshHost(
  name: 'alpha',
  hostname: 'alpha.example.com',
  port: 22,
  available: true,
);

final _entries = [
  RemoteFileEntry(
    name: 'alpha.txt',
    isDirectory: false,
    sizeBytes: 1,
    modified: DateTime(2024, 1, 1),
  ),
  RemoteFileEntry(
    name: 'beta.txt',
    isDirectory: false,
    sizeBytes: 2,
    modified: DateTime(2024, 1, 2),
  ),
];

enum _SelectionMode { paste, delete, rename }

class _ExplorerInteractionHarness {
  _ExplorerInteractionHarness({
    required BuildContext context,
    required _SelectionMode selectionMode,
  }) : selectionState = ExplorerSelectionState(
         currentPath: '/workspace',
         joinPath: _joinPath,
       ),
       controller = FileExplorerController(
         host: _host,
         explorerContext: ExplorerContext.server(_host),
         shellService: _FakeRemoteShellService(),
         settingsController: AppSettingsController(),
         trashManager: ExplorerTrashManager(),
         uiAdapter: ExplorerUiAdapter(context: context),
         initialPath: '/workspace',
       ) {
    selectionController = _FakeSelectionController(
      state: selectionState,
      mode: selectionMode,
    );
    actions = _FakeFileExplorerTabActions(
      controller: controller,
      selectionController: selectionController,
    );
    interactions = FileExplorerTabEntryInteractions(
      controller: controller,
      selectionController: selectionController,
      actions: actions,
      listFocusNode: FocusNode(),
      scrollController: ScrollController(),
      markNeedsBuild: () {},
    );
  }

  final ExplorerSelectionState selectionState;
  final FileExplorerController controller;
  late final _FakeSelectionController selectionController;
  late final _FakeFileExplorerTabActions actions;
  late final FileExplorerTabEntryInteractions interactions;
}

class _FakeSelectionController extends SelectionController {
  _FakeSelectionController({required super.state, required this.mode});

  final _SelectionMode mode;

  @override
  KeyEventResult handleListKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<RemoteFileEntry> entries,
    VoidCallback setState,
    VoidCallback onCopy,
    VoidCallback onCut,
    VoidCallback onPaste,
    VoidCallback onDelete,
    VoidCallback onRename,
  ) {
    switch (mode) {
      case _SelectionMode.paste:
        onPaste();
      case _SelectionMode.delete:
        onDelete();
      case _SelectionMode.rename:
        onRename();
    }
    return KeyEventResult.handled;
  }
}

class _FakeFileExplorerTabActions extends FileExplorerTabActions {
  _FakeFileExplorerTabActions({
    required super.controller,
    required super.selectionController,
  }) : super(
         scrollController: ScrollController(),
         isMounted: () => true,
         showSnackBar: (_) {},
       );

  final List<String> pasteTargets = [];
  final List<List<String>> multiDeleteTargets = [];
  final List<String> renamedEntryNames = [];

  @override
  Future<void> handlePaste({required String targetDirectory}) async {
    pasteTargets.add(targetDirectory);
  }

  @override
  Future<void> confirmMultiDelete(
    List<RemoteFileEntry> entries, {
    bool permanent = false,
  }) async {
    multiDeleteTargets.add(entries.map((entry) => entry.name).toList());
  }

  @override
  Future<void> promptRename(RemoteFileEntry entry) async {
    renamedEntryNames.add(entry.name);
  }
}

class _FakeRemoteShellService extends RemoteShellService {
  const _FakeRemoteShellService();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _joinPath(String base, String name) {
  if (base.endsWith('/')) {
    return '$base$name';
  }
  return '$base/$name';
}
