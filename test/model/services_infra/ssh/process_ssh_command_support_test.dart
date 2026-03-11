import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_command_support.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  const support = ProcessSshCommandSupport();
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  group('ProcessSshCommandSupport', () {
    test('emitCommandOutput delegates to shell debug emission', () {
      final shell = _FakeRemoteShellService();

      final output = support.emitCommandOutput(
        shell: shell,
        host: host,
        operation: 'runCommand',
        run: const RunResult(command: 'ssh echo hi', stdout: 'hi\n', stderr: ''),
        trimOutput: true,
      );

      expect(output, 'hi');
      expect(shell.lastOperation, 'runCommand');
      expect(shell.lastCommand, 'ssh echo hi');
      expect(shell.lastOutput, 'hi');
    });

    test('logFailure records structured remote command details', () {
      AppLogger.remoteCommandLog.clear();
      AppLogger.configureRemoteCommandLogging(enabled: true);

      try {
        support.logFailure(
          host: host,
          operation: 'listDirectory',
          command: 'ls /tmp',
          error: Exception('boom'),
        );
      } finally {
        AppLogger.configureRemoteCommandLogging(enabled: false);
      }

      final event = AppLogger.remoteCommandLog.events.single;
      expect(event.operation, 'listDirectory');
      expect(event.command, 'ls /tmp');
      expect(event.output, 'Error: Exception: boom');
    });
  });
}

class _FakeRemoteShellService extends RemoteShellService {
  String? lastOperation;
  String? lastCommand;
  String? lastOutput;

  @override
  void emitDebugEvent({
    required SshHost host,
    required String operation,
    required String command,
    required String output,
    VerificationResult? verification,
  }) {
    lastOperation = operation;
    lastCommand = command;
    lastOutput = output;
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
  }) async => throw UnimplementedError();

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
    void Function(int bytesTransferred)? onBytes,
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
  Future<String> runCommandStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
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
    void Function(int bytesTransferred)? onBytes,
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
