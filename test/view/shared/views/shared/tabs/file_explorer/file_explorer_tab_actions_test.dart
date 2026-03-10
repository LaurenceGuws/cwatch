import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/clipboard_operations_handler.dart';
import 'package:cwatch/controller/adapters/delete_operations_handler.dart';
import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/adapters/file_operations_ui_handler.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services/file_editing_service.dart';
import 'package:cwatch/model/services/file_operations_service.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_actions.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/selection_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileExplorerTabActions', () {
    testWidgets('promptRename routes move refresh and snackbar on success', (
      tester,
    ) async {
      final harness = await _buildHarness(tester);
      harness.uiAdapter.renameResponse = 'renamed.txt';

      await harness.actions.promptRename(_file('old.txt'));

      expect(harness.shell.movedPaths, [('/srv/old.txt', '/srv/renamed.txt')]);
      expect(harness.controller.refreshCount, 1);
      expect(harness.snackBars.single, 'Renamed old.txt to renamed.txt');
    });

    testWidgets('promptRename reports failure without refreshing', (tester) async {
      final harness = await _buildHarness(tester);
      harness.uiAdapter.renameResponse = 'renamed.txt';
      harness.shell.throwOnMove = true;

      await harness.actions.promptRename(_file('old.txt'));

      expect(harness.controller.refreshCount, 0);
      expect(harness.snackBars.single, contains('Failed to rename:'));
    });

    testWidgets('handlePaste delegates to file operations ui handler', (
      tester,
    ) async {
      final harness = await _buildHarness(tester);

      await harness.actions.handlePaste(targetDirectory: '/target');

      expect(harness.fileOpsUiHandler.pasteTargets, ['/target']);
    });

    testWidgets('handleDropDone delegates dropped paths and surfaces snackbar', (
      tester,
    ) async {
      final harness = await _buildHarness(tester);
      final droppedFile = DropItemFile('/tmp/example.txt');
      final details = DropDoneDetails(
        files: [droppedFile],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      );

      await harness.actions.handleDropDone(details);

      expect(harness.fileOpsUiHandler.droppedTargetDirectories, ['/srv']);
      expect(harness.fileOpsUiHandler.droppedPaths.single, ['/tmp/example.txt']);
      expect(harness.snackBars.single, contains('Uploading 1 dropped item'));
    });
  });
}

const _host = SshHost(
  name: 'test-host',
  hostname: 'example.com',
  port: 22,
  available: true,
);

const _context = ExplorerContext(
  id: 'server:test-host',
  host: _host,
  kind: ExplorerContextKind.server,
  label: 'test-host',
);

RemoteFileEntry _file(String name) => RemoteFileEntry(
  name: name,
  isDirectory: false,
  sizeBytes: 1,
  modified: DateTime(2024),
);

class _ActionsHarness {
  const _ActionsHarness({
    required this.actions,
    required this.controller,
    required this.shell,
    required this.uiAdapter,
    required this.fileOpsUiHandler,
    required this.snackBars,
  });

  final FileExplorerTabActions actions;
  final _ActionsTestController controller;
  final _FakeRemoteShellService shell;
  final _FakeExplorerUiAdapter uiAdapter;
  final _FakeFileOperationsUiHandler fileOpsUiHandler;
  final List<String> snackBars;
}

Future<_ActionsHarness> _buildHarness(WidgetTester tester) async {
  final appSettingsController = AppSettingsController();
  final shell = _FakeRemoteShellService();
  final snackBars = <String>[];
  late BuildContext context;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  final uiAdapter = _FakeExplorerUiAdapter(context: context, snackBars: snackBars);
  final controller = _ActionsTestController(
    host: _host,
    explorerContext: _context,
    shellService: shell,
    settingsController: appSettingsController,
    trashManager: ExplorerTrashManager(),
    uiAdapter: uiAdapter,
  );
  final fileOpsUiHandler = _FakeFileOperationsUiHandler(
    uiAdapter: uiAdapter,
    settingsController: appSettingsController,
    shellService: shell,
  );
  controller.fileOpsUiHandler = fileOpsUiHandler;

  final actions = FileExplorerTabActions(
    controller: controller,
    selectionController: SelectionController(state: controller.selectionState),
    scrollController: ScrollController(),
    isMounted: () => true,
    showSnackBar: snackBars.add,
  );

  return _ActionsHarness(
    actions: actions,
    controller: controller,
    shell: shell,
    uiAdapter: uiAdapter,
    fileOpsUiHandler: fileOpsUiHandler,
    snackBars: snackBars,
  );
}

class _ActionsTestController extends FileExplorerController {
  _ActionsTestController({
    required super.host,
    required super.explorerContext,
    required super.shellService,
    required super.settingsController,
    required super.trashManager,
    required super.uiAdapter,
  }) {
    currentPath = '/srv';
    selectionState = ExplorerSelectionState(
      currentPath: currentPath,
      joinPath: PathUtils.joinPath,
    );
    clipboardHandler = ClipboardOperationsHandler(
      host: host,
      currentPath: currentPath,
      explorerContext: explorerContext,
      shellService: shellService,
      uiAdapter: uiAdapter,
    );
    deleteHandler = _FakeDeleteOperationsHandler(
      shellService: shellService,
      host: host,
      trashManager: trashManager,
      explorerContext: explorerContext,
      uiAdapter: uiAdapter,
    );
    fileEditingService = _FakeFileEditingService(
      shellService: shellService,
      host: host,
    );
  }

  int refreshCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  List<RemoteFileEntry> currentSortedEntries() => List.unmodifiable(state.entries);

  @override
  Future<void> refreshCurrentPath() async {
    refreshCount++;
  }

  @override
  Future<T> runShell<T>(Future<T> Function() action) => action();

  @override
  bool isSelfDragDrop({required List<String> paths, required String targetDirectory}) => false;
}

class _FakeExplorerUiAdapter extends ExplorerUiAdapter {
  _FakeExplorerUiAdapter({required super.context, required this.snackBars});

  final List<String> snackBars;
  String? renameResponse;

  @override
  void showSnackBar(String message) {
    snackBars.add(message);
  }

  @override
  Future<String?> showRenameDialog(RemoteFileEntry entry) async => renameResponse;
}

class _FakeFileOperationsUiHandler extends FileOperationsUiHandler {
  _FakeFileOperationsUiHandler({
    required super.uiAdapter,
    required AppSettingsController settingsController,
    required RemoteShellService shellService,
  }) : super(
         service: FileOperationsService(
           shellService: shellService,
           host: _host,
           settingsController: settingsController,
           trashManager: ExplorerTrashManager(),
           runShellWrapper: <T>(action) => action(),
           explorerContext: _context,
         ),
       );

  final List<String> pasteTargets = [];
  final List<String> droppedTargetDirectories = [];
  final List<List<String>> droppedPaths = [];

  @override
  Future<void> handlePaste({
    required String targetDirectory,
    required String currentPath,
    required String Function(String, String) joinPath,
    required String Function(String) normalizePath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    pasteTargets.add(targetDirectory);
  }

  @override
  Future<void> handleDroppedPaths({
    required String targetDirectory,
    required List<String> paths,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    droppedTargetDirectories.add(targetDirectory);
    droppedPaths.add(paths);
  }
}

class _FakeDeleteOperationsHandler extends DeleteOperationsHandler {
  _FakeDeleteOperationsHandler({
    required super.shellService,
    required super.host,
    required super.trashManager,
    required super.explorerContext,
    required super.uiAdapter,
  }) : super(
         runShellWrapper: <T>(action) => action(),
       );
}

class _FakeFileEditingService extends FileEditingService {
  _FakeFileEditingService({
    required super.shellService,
    required super.host,
  }) : super(
         cache: RemoteEditorCache(),
         runShellWrapper: <T>(action) => action(),
         promptMergeDialog: ({required remotePath, required local, required remote}) async => local,
         launchLocalApp: (_) async {},
       );
}

class _FakeRemoteShellService extends RemoteShellService {
  final List<(String, String)> movedPaths = [];
  bool throwOnMove = false;

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) async {}

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) async {}

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {}

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int p1)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {}

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) async => '/srv';

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async => const [];

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    if (throwOnMove) {
      throw Exception('move failed');
    }
    movedPaths.add((source, destination));
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async => '';

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async => '';

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
    Duration timeout = const Duration(seconds: 30),
    RunTimeoutHandler? onTimeout,
  }) async => const [];

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int p1)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {}

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {}
}
