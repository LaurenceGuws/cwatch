import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/adapters/settings_ui_adapter.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/input_mode_preference.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_presenter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileExplorerTabPresenter', () {
    testWidgets('deduplicates timeout notifications', (tester) async {
      final harness = await _buildHarness(tester);
      final presenter = FileExplorerTabPresenter(
        controller: harness.controller,
        settingsController: harness.settingsController,
      );

      harness.controller.state.error = 'TimeoutException: timed out';

      expect(
        presenter.consumeTimeoutNotification(),
        'TimeoutException: timed out',
      );
      expect(presenter.consumeTimeoutNotification(), isNull);

      harness.controller.state.error = 'Request timed out again';
      expect(presenter.consumeTimeoutNotification(), 'Request timed out again');
    });

    testWidgets('shapes loading and streaming states correctly', (tester) async {
      final harness = await _buildHarness(tester);
      final presenter = FileExplorerTabPresenter(
        controller: harness.controller,
        settingsController: harness.settingsController,
      );

      harness.controller.state.loading = true;
      harness.controller.state.searchActive = false;
      harness.controller.state.searchQuery = '';

      expect(presenter.showLoadingIndicator, isTrue);
      expect(presenter.showStreamingResults, isFalse);

      harness.controller.state.searchActive = true;
      harness.controller.state.searchQuery = 'logs';

      expect(presenter.showStreamingResults, isTrue);
      expect(presenter.showLoadingIndicator, isFalse);
    });

    testWidgets('builds shortcuts only when shortcut input mode is enabled', (
      tester,
    ) async {
      final harness = await _buildHarness(tester);
      final presenter = FileExplorerTabPresenter(
        controller: harness.controller,
        settingsController: harness.settingsController,
      );

      final disabled = presenter.buildShortcuts(
        const AppSettings(inputModePreference: InputModePreference.gestures),
      );
      expect(disabled, isEmpty);

      final enabled = presenter.buildShortcuts(
        const AppSettings(inputModePreference: InputModePreference.shortcuts),
      );
      expect(enabled, isNotEmpty);
      expect(
        enabled.values.whereType<ToggleSearchIntent>().length,
        1,
      );
      expect(enabled.values.whereType<ZoomInIntent>().length, 1);
      expect(enabled.values.whereType<ZoomOutIntent>().length, 1);
      expect(
        ShortcutActions.explorerSearch,
        isNotEmpty,
      );
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

class _HarnessResult {
  const _HarnessResult({
    required this.controller,
    required this.settingsController,
  });

  final _PresenterTestController controller;
  final SettingsController settingsController;
}

Future<_HarnessResult> _buildHarness(WidgetTester tester) async {
  final appSettingsController = AppSettingsController();
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

  final settingsController = SettingsController(
    settingsController: appSettingsController,
    keyService: BuiltInSshKeyService(),
    hostsFuture: Future.value(const []),
    uiAdapter: SettingsUiAdapter(context: context),
  );
  final controller = _PresenterTestController(
    host: _host,
    explorerContext: _context,
    shellService: _FakeRemoteShellService(),
    settingsController: appSettingsController,
    trashManager: ExplorerTrashManager(),
    uiAdapter: ExplorerUiAdapter(context: context),
  );

  return _HarnessResult(
    controller: controller,
    settingsController: settingsController,
  );
}

class _PresenterTestController extends FileExplorerController {
  _PresenterTestController({
    required super.host,
    required super.explorerContext,
    required super.shellService,
    required super.settingsController,
    required super.trashManager,
    required super.uiAdapter,
  });

  @override
  Future<void> initialize() async {}

  @override
  List<RemoteFileEntry> currentSortedEntries() => const [];
}

class _FakeRemoteShellService extends RemoteShellService {
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
  }) async => '/';

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
  }) async {}

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
