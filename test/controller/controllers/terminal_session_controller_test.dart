import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/terminal_session_controller.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  group('TerminalSessionController', () {
    test('start creates a terminal session and forwards decoded output and exit code', () async {
      final shell = _FakeRemoteShellService();
      final session = _FakeTerminalSession();
      shell.sessionToReturn = session;
      final controller = _controller(shell);
      final outputs = <String>[];
      final exits = <int>[];

      final started = await controller.start(
        options: const TerminalSessionOptions(rows: 40, columns: 120),
        onOutput: outputs.add,
        onExit: exits.add,
      );

      expect(started, same(session));
      expect(shell.createCalls, 1);
      expect(shell.lastOptions?.rows, 40);
      expect(shell.lastOptions?.columns, 120);

      session.emitText('hello ');
      session.emitText('world');
      await pumpEventQueue();
      expect(outputs.join(), 'hello world');

      session.completeExit(7);
      await pumpEventQueue();
      expect(exits, [7]);
    });

    test('write and resize forward to the active session', () async {
      final shell = _FakeRemoteShellService();
      final session = _FakeTerminalSession();
      shell.sessionToReturn = session;
      final controller = _controller(shell);

      await controller.start(
        options: const TerminalSessionOptions(),
        onOutput: (_) {},
        onExit: (_) {},
      );

      controller.write(Uint8List.fromList([65, 66, 67]));
      controller.resize(33, 88);

      expect(session.writes, hasLength(1));
      expect(session.writes.single, [65, 66, 67]);
      expect(session.resizes, [
        const _ResizeCall(rows: 33, cols: 88),
      ]);
    });

    test('reset kills the active session and clears future writes/resizes', () async {
      final shell = _FakeRemoteShellService();
      final session = _FakeTerminalSession();
      shell.sessionToReturn = session;
      final controller = _controller(shell);

      await controller.start(
        options: const TerminalSessionOptions(),
        onOutput: (_) {},
        onExit: (_) {},
      );

      controller.reset();
      controller.write(Uint8List.fromList([90]));
      controller.resize(10, 20);

      expect(session.killCount, 1);
      expect(session.writes, isEmpty);
      expect(session.resizes, isEmpty);
    });

    test('starting a new session cancels the previous output subscription', () async {
      final shell = _FakeRemoteShellService();
      final first = _FakeTerminalSession();
      final second = _FakeTerminalSession();
      shell.sessionsToReturn = [first, second];
      final controller = _controller(shell);
      final outputs = <String>[];

      await controller.start(
        options: const TerminalSessionOptions(),
        onOutput: outputs.add,
        onExit: (_) {},
      );
      first.emitText('before');
      await pumpEventQueue();

      await controller.start(
        options: const TerminalSessionOptions(rows: 30, columns: 90),
        onOutput: outputs.add,
        onExit: (_) {},
      );
      first.emitText('ignored');
      second.emitText('after');
      await pumpEventQueue();

      expect(outputs, ['before', 'after']);
      expect(shell.createCalls, 2);
    });

    test('dispose delegates to reset', () async {
      final shell = _FakeRemoteShellService();
      final session = _FakeTerminalSession();
      shell.sessionToReturn = session;
      final controller = _controller(shell);

      await controller.start(
        options: const TerminalSessionOptions(),
        onOutput: (_) {},
        onExit: (_) {},
      );

      controller.dispose();

      expect(session.killCount, 1);
    });
  });
}

TerminalSessionController _controller(_FakeRemoteShellService shell) {
  return TerminalSessionController(
    shellService: shell,
    host: const SshHost(
      name: 'test-host',
      hostname: 'localhost',
      port: 22,
      available: true,
    ),
  );
}

class _FakeRemoteShellService extends RemoteShellService {
  int createCalls = 0;
  TerminalSessionOptions? lastOptions;
  _FakeTerminalSession? sessionToReturn;
  List<_FakeTerminalSession> sessionsToReturn = [];

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    createCalls += 1;
    lastOptions = options;
    if (sessionsToReturn.isNotEmpty) {
      return sessionsToReturn.removeAt(0);
    }
    return sessionToReturn ?? _FakeTerminalSession();
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
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
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
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
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
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();
}

class _FakeTerminalSession implements TerminalSession {
  final StreamController<Uint8List> _outputController =
      StreamController<Uint8List>.broadcast();
  final Completer<int> _exitCompleter = Completer<int>();
  final List<List<int>> writes = [];
  final List<_ResizeCall> resizes = [];
  int killCount = 0;

  @override
  Stream<Uint8List> get output => _outputController.stream;

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  void kill() {
    killCount += 1;
  }

  @override
  void resize(int rows, int cols) {
    resizes.add(_ResizeCall(rows: rows, cols: cols));
  }

  @override
  void write(Uint8List data) {
    writes.add(data.toList());
  }

  void emitText(String text) {
    _outputController.add(Uint8List.fromList(text.codeUnits));
  }

  void completeExit(int code) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
  }
}

class _ResizeCall {
  const _ResizeCall({required this.rows, required this.cols});

  final int rows;
  final int cols;

  @override
  bool operator ==(Object other) {
    return other is _ResizeCall &&
        other.rows == rows &&
        other.cols == cols;
  }

  @override
  int get hashCode => Object.hash(rows, cols);
}
