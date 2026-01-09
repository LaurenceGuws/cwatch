import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/remote_file_entry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/settings/settings_storage.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/terminal_session.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/app/adapters/explorer_ui_adapter.dart';
import 'package:cwatch/app/adapters/file_operations_ui_handler.dart';
import 'package:cwatch/app/services/explorer_clipboard.dart';
import 'package:cwatch/app/services/file_operations_service.dart';

class CopyCall {
  const CopyCall(this.source, this.destination, this.recursive);

  final String source;
  final String destination;
  final bool recursive;
}

class MoveCall {
  const MoveCall(this.source, this.destination);

  final String source;
  final String destination;
}

class DeleteCall {
  const DeleteCall(this.path);

  final String path;
}

class DownloadCall {
  const DownloadCall(this.remotePath, this.localDestination, this.recursive);

  final String remotePath;
  final String localDestination;
  final bool recursive;
}

class UploadCall {
  const UploadCall(this.localPath, this.remoteDestination, this.recursive);

  final String localPath;
  final String remoteDestination;
  final bool recursive;
}

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

  final List<CopyCall> copyCalls = [];
  final List<MoveCall> moveCalls = [];
  final List<DeleteCall> deleteCalls = [];
  final List<DownloadCall> downloadCalls = [];
  final List<UploadCall> uploadCalls = [];

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
  }) async {
    moveCalls.add(MoveCall(source, destination));
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) async {
    copyCalls.add(CopyCall(source, destination, recursive));
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) async {
    deleteCalls.add(DeleteCall(path));
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
  }) async {
    downloadCalls.add(DownloadCall(remotePath, localDestination, recursive));
    final dir = Directory(localDestination);
    await dir.create(recursive: true);
    final target = p.join(localDestination, p.basename(remotePath));
    if (recursive) {
      await Directory(target).create(recursive: true);
    } else {
      await File(target).writeAsString('fake');
    }
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
  }) async {
    uploadCalls.add(UploadCall(localPath, remoteDestination, recursive));
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
  Future<String> runCommandStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    return _FakeTerminalSession();
  }
}

class _FakeTerminalSession implements TerminalSession {
  @override
  Stream<Uint8List> get output => const Stream<Uint8List>.empty();

  @override
  Future<int> get exitCode => Future.value(0);

  @override
  void write(Uint8List data) {}

  @override
  void resize(int rows, int cols) {}

  @override
  void kill() {}
}

AppSettingsController _settingsController() {
  return AppSettingsController(storage: FakeSettingsStorage());
}

SshHost _host(String name) {
  return SshHost(name: name, hostname: 'localhost', port: 22, available: true);
}

FileOperationsService _serviceFor({
  required FakeRemoteShellService shell,
  required ExplorerContext context,
}) {
  return FileOperationsService(
    shellService: shell,
    host: context.host,
    settingsController: _settingsController(),
    trashManager: ExplorerTrashManager(),
    runShellWrapper: <T>(action) => action(),
    explorerContext: context,
  );
}

void main() {
  tearDown(ExplorerClipboard.clear);

  test('copyPath delegates to the remote shell', () async {
    final shell = FakeRemoteShellService();
    final host = _host('alpha');
    final context = ExplorerContext.server(host);
    final service = _serviceFor(shell: shell, context: context);

    await service.copyPath('/source', '/dest', recursive: true);

    expect(shell.copyCalls, hasLength(1));
    expect(shell.copyCalls.single.source, '/source');
    expect(shell.copyCalls.single.destination, '/dest');
    expect(shell.copyCalls.single.recursive, isTrue);
  });

  test('movePath delegates to the remote shell', () async {
    final shell = FakeRemoteShellService();
    final host = _host('alpha');
    final context = ExplorerContext.server(host);
    final service = _serviceFor(shell: shell, context: context);

    await service.movePath('/from', '/to');

    expect(shell.moveCalls, hasLength(1));
    expect(shell.moveCalls.single.source, '/from');
    expect(shell.moveCalls.single.destination, '/to');
  });

  test('deletePath delegates to the remote shell', () async {
    final shell = FakeRemoteShellService();
    final host = _host('alpha');
    final context = ExplorerContext.server(host);
    final service = _serviceFor(shell: shell, context: context);

    await service.deletePath('/danger');

    expect(shell.deleteCalls, hasLength(1));
    expect(shell.deleteCalls.single.path, '/danger');
  });

  testWidgets('handlePaste copies within the same context', (tester) async {
    final shell = FakeRemoteShellService();
    final host = _host('alpha');
    final context = ExplorerContext.server(host);
    final service = _serviceFor(shell: shell, context: context);

    ExplorerClipboard.setEntry(
      ExplorerClipboardEntry(
        context: context,
        remotePath: '/remote/file.txt',
        displayName: 'file.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.copy,
        shellService: shell,
      ),
    );

    BuildContext? widgetContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              widgetContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final uiHandler = FileOperationsUiHandler(
      service: service,
      uiAdapter: ExplorerUiAdapter(context: widgetContext!),
    );
    var refreshed = false;
    await tester.runAsync(() async {
      await uiHandler.handlePaste(
        targetDirectory: '/dest',
        currentPath: '/dest',
        joinPath: (a, b) => '$a/$b',
        normalizePath: (value) => value,
        refreshCurrentPath: () async {
          refreshed = true;
        },
      );
    });

    expect(refreshed, isTrue);
    expect(shell.copyCalls, hasLength(1));
    expect(shell.copyCalls.single.source, '/remote/file.txt');
    expect(shell.copyCalls.single.destination, '/dest/file.txt');
  });

  testWidgets('handlePaste moves across contexts via temp download', (
    tester,
  ) async {
    final sourceShell = FakeRemoteShellService();
    final destShell = FakeRemoteShellService();
    final sourceHost = _host('alpha');
    final destHost = _host('beta');
    final sourceContext = ExplorerContext.server(sourceHost);
    final destContext = ExplorerContext.server(destHost);
    final service = _serviceFor(shell: destShell, context: destContext);

    ExplorerClipboard.setEntry(
      ExplorerClipboardEntry(
        context: sourceContext,
        remotePath: '/remote/a.txt',
        displayName: 'a.txt',
        isDirectory: false,
        operation: ExplorerClipboardOperation.cut,
        shellService: sourceShell,
      ),
    );

    BuildContext? widgetContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              widgetContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final uiHandler = FileOperationsUiHandler(
      service: service,
      uiAdapter: ExplorerUiAdapter(context: widgetContext!),
    );

    await tester.runAsync(() async {
      await uiHandler.handlePaste(
        targetDirectory: '/dest',
        currentPath: '/other',
        joinPath: (a, b) => '$a/$b',
        normalizePath: (value) => value,
        refreshCurrentPath: () async {},
      );
    });

    expect(sourceShell.downloadCalls, hasLength(1));
    expect(sourceShell.downloadCalls.single.remotePath, '/remote/a.txt');
    expect(destShell.uploadCalls, hasLength(1));
    expect(destShell.uploadCalls.single.remoteDestination, '/dest/a.txt');
    expect(sourceShell.deleteCalls, hasLength(1));
    expect(sourceShell.deleteCalls.single.path, '/remote/a.txt');
    expect(ExplorerClipboard.entries, isEmpty);
  });
}
