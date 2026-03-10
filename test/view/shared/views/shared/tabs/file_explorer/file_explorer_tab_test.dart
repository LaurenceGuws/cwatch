import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/adapters/settings_ui_adapter.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/model/shared/theme/theme_factory.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';

void main() {
  group('FileExplorerTab', () {
    testWidgets('renders loading state while explorer initialization is in progress', (
      tester,
    ) async {
      final shell = _FakeRemoteShellService();
      final homeCompleter = Completer<String>();
      shell.homeDirectoryHandler = (_) => homeCompleter.future;

      await tester.pumpWidget(_Harness(shellService: shell));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('timed out'), findsNothing);

      homeCompleter.complete('/srv');
      shell.listDirectoryHandler = (_, path) async => const [];
      await tester.pumpAndSettle();
    });

    testWidgets('renders non-timeout initialization errors inline', (
      tester,
    ) async {
      final shell = _FakeRemoteShellService();
      shell.homeDirectoryHandler = (_) async => '/srv';
      shell.listDirectoryHandler = (_, path) async => throw Exception('boom');

      await tester.pumpWidget(_Harness(shellService: shell));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('Exception: boom'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
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

class _Harness extends StatefulWidget {
  const _Harness({required this.shellService});

  final _FakeRemoteShellService shellService;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final AppSettingsController _appSettingsController;
  SettingsController? _settingsController;
  _TestFileExplorerController? _controller;

  @override
  void initState() {
    super.initState();
    _appSettingsController = AppSettingsController();
  }

  @override
  Widget build(BuildContext context) {
    _settingsController ??= SettingsController(
      settingsController: _appSettingsController,
      keyService: BuiltInSshKeyService(),
      hostsFuture: Future.value(const []),
      uiAdapter: SettingsUiAdapter(context: context),
    );
    _controller ??= _TestFileExplorerController(
      host: _host,
      explorerContext: _context,
      shellService: widget.shellService,
      settingsController: _appSettingsController,
      trashManager: ExplorerTrashManager(),
      uiAdapter: ExplorerUiAdapter(context: context),
    );

    return MaterialApp(
      theme: ThemeFactory.build(
        settings: _appSettingsController.settings,
        brightness: Brightness.light,
      ),
      home: Scaffold(
        body: FileExplorerTab(
          controller: _controller!,
          settingsController: _settingsController!,
          onOpenTrash: (_) {},
        ),
      ),
    );
  }
}

class _TestFileExplorerController extends FileExplorerController {
  _TestFileExplorerController({
    required super.host,
    required super.explorerContext,
    required super.shellService,
    required super.settingsController,
    required super.trashManager,
    required super.uiAdapter,
  }) {
    selectionState = ExplorerSelectionState(
      currentPath: currentPath,
      joinPath: PathUtils.joinPath,
    );
  }

  @override
  Future<void> initialize() async {
    state.loading = true;
    state.error = null;
    notifyListeners();

    try {
      final home = await shellService.homeDirectory(host);
      currentPath = PathUtils.normalizePath(home);
      final entries = await shellService.listDirectory(host, currentPath);
      state.entries
        ..clear()
        ..addAll(entries.where((entry) => entry.name != '.' && entry.name != '..'));
      state.loading = false;
      state.error = null;
      notifyListeners();
    } catch (error) {
      state.loading = false;
      state.error = error.toString();
      notifyListeners();
    }
  }

  @override
  List<RemoteFileEntry> currentSortedEntries() => List.unmodifiable(state.entries);
}

class _FakeRemoteShellService extends RemoteShellService {
  Future<String> Function(SshHost host)? homeDirectoryHandler;
  Future<List<RemoteFileEntry>> Function(SshHost host, String path)?
  listDirectoryHandler;

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) {
    final handler = homeDirectoryHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(host);
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    final handler = listDirectoryHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(host, path);
  }

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
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
    void Function(int exitCode)? onExit,
  }) => throw UnimplementedError();
}
