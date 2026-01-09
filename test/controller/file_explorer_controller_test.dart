import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/settings_storage.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';
import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/controller/controllers/file_explorer_controller.dart';

class FakeSettingsStorage extends SettingsStorage {
  AppSettings _settings = const AppSettings();

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

class FakeRemoteShellService extends RemoteShellService {
  FakeRemoteShellService() : super(debugMode: false, observer: null);

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) {
    throw UnimplementedError();
  }
}

class FakeExplorerUiAdapter extends ExplorerUiAdapter {
  FakeExplorerUiAdapter() : super(context: _FakeBuildContext());

  final List<String> _snackBarMessages = [];
  List<String> get snackBarMessages => List.unmodifiable(_snackBarMessages);

  @override
  void showSnackBar(String message, {bool isError = false}) {
    _snackBarMessages.add(message);
  }
}

class _FakeBuildContext {
  // Minimal fake BuildContext
}

void main() {
  group('FileExplorerController', () {
    late SshHost testHost;
    late ExplorerContext testContext;
    late FakeSettingsStorage storage;
    late AppSettingsController settingsController;
    late FakeRemoteShellService shellService;
    late ExplorerTrashManager trashManager;
    late FakeExplorerUiAdapter uiAdapter;

    setUp(() {
      testHost = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      testContext = ExplorerContext.server(testHost);
      storage = FakeSettingsStorage();
      settingsController = AppSettingsController(storage: storage);
      shellService = FakeRemoteShellService();
      trashManager = ExplorerTrashManager();
      uiAdapter = FakeExplorerUiAdapter();
    });

    Future<FileExplorerController> createController({
      String? initialPath,
    }) async {
      await settingsController.load();
      return FileExplorerController(
        host: testHost,
        explorerContext: testContext,
        shellService: shellService,
        settingsController: settingsController,
        trashManager: trashManager,
        uiAdapter: uiAdapter,
        initialPath: initialPath,
      );
    }

    test('initializes with default path', () async {
      final controller = await createController();

      expect(controller.currentPath, '/');
    });

    test('initializes with custom initial path', () async {
      final controller = await createController(initialPath: '/home/user');

      expect(controller.currentPath, '/home/user');
    });

    test('setShowRowHeightControl updates state', () async {
      final controller = await createController();
      await controller.initialize();

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.setShowRowHeightControl(true);

      expect(controller.state.showRowHeightControl, isTrue);
      expect(notified, isTrue);
    });

    test('setShowBreadcrumbs updates settings and state', () async {
      final controller = await createController();
      await controller.initialize();

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.setShowBreadcrumbs(false);

      expect(controller.state.showBreadcrumbs, isFalse);
      expect(settingsController.settings.explorerShowBreadcrumbs, isFalse);
      expect(notified, isTrue);
    });

    test('setRowHeight sanitizes values', () async {
      final controller = await createController();
      await controller.initialize();

      controller.setRowHeight(10); // Below minimum
      expect(controller.state.rowHeight, 24.0);

      controller.setRowHeight(100); // Above maximum
      expect(controller.state.rowHeight, 88.0);

      controller.setRowHeight(50); // Valid
      expect(controller.state.rowHeight, 50.0);
    });

    test('setRowHeight updates settings', () async {
      final controller = await createController();
      await controller.initialize();

      controller.setRowHeight(40);

      expect(settingsController.settings.explorerRowHeight, 40.0);
    });

    test('syncs from settings on initialization', () async {
      await settingsController.load();
      await settingsController.update(
        (current) => current.copyWith(
          explorerRowHeight: 50,
          explorerShowBreadcrumbs: false,
        ),
      );

      final controller = await createController();
      await controller.initialize();

      expect(controller.state.rowHeight, 50.0);
      expect(controller.state.showBreadcrumbs, isFalse);
    });

    test('syncs from settings when settings change', () async {
      final controller = await createController();
      await controller.initialize();

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      await settingsController.update(
        (current) => current.copyWith(explorerRowHeight: 60),
      );

      expect(controller.state.rowHeight, 60.0);
      expect(notified, isTrue);
    });

    test('dispose removes settings listener', () async {
      final controller = await createController();
      await controller.initialize();

      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.dispose();

      await settingsController.update(
        (current) => current.copyWith(explorerRowHeight: 70),
      );

      // Should not notify after dispose
      expect(notified, isFalse);
    });
  });
}
