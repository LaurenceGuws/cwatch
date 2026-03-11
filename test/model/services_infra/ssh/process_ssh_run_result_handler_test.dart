import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_run_result_handler.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

class _CapturingShell extends RemoteShellService {
  _CapturingShell() : super(debugMode: true);

  String? lastOperation;
  String? lastCommand;
  String? lastOutput;
  VerificationResult? lastVerification;

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
    lastVerification = verification;
  }

  @override
  Future<void> copyBetweenHosts({required SshHost sourceHost, required String sourcePath, required SshHost destinationHost, required String destinationPath, bool recursive = false, Duration timeout = const Duration(minutes: 2), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<void> copyPath(SshHost host, String source, String destination, {bool recursive = false, Duration timeout = const Duration(seconds: 20), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<TerminalSession> createTerminalSession(SshHost host, {required TerminalSessionOptions options}) => throw UnimplementedError();
  @override
  Future<void> deletePath(SshHost host, String path, {Duration timeout = const Duration(seconds: 15), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<void> downloadPath({required SshHost host, required String remotePath, required String localDestination, bool recursive = false, Duration timeout = const Duration(minutes: 2), void Function(int p1)? onBytes, RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<String> homeDirectory(SshHost host, {Duration timeout = const Duration(seconds: 5), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<List<RemoteFileEntry>> listDirectory(SshHost host, String path, {Duration timeout = const Duration(seconds: 10), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<String> readFile(SshHost host, String path, {Duration timeout = const Duration(seconds: 15), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<String> runCommand(SshHost host, String command, {Duration timeout = const Duration(seconds: 10), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<List<RemoteFileEntry>> searchPaths(SshHost host, String basePath, String query, {String? includePattern, String? excludePattern, bool matchCase = false, bool matchWholeWord = false, bool searchContents = false, void Function(RemoteFileEntry p1)? onEntry, RemoteCommandCancellation? cancellation, Duration timeout = const Duration(seconds: 30), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<void> uploadPath({required SshHost host, required String localPath, required String remoteDestination, bool recursive = false, Duration timeout = const Duration(minutes: 2), void Function(int p1)? onBytes, RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<void> writeFile(SshHost host, String path, String contents, {Duration timeout = const Duration(seconds: 15), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
  @override
  Future<void> movePath(SshHost host, String source, String destination, {Duration timeout = const Duration(seconds: 15), RunTimeoutHandler? onTimeout}) => throw UnimplementedError();
}

void main() {
  const handler = ProcessSshRunResultHandler();
  final host = SshHost(
    name: 'h',
    hostname: 'host',
    port: 22,
    available: true,
    user: 'u',
    identityFiles: const [],
    source: 'test',
  );

  test('emitOutput forwards result fields and optional trimming', () {
    final shell = _CapturingShell();
    final result = RunResult(
      command: 'ssh host ls',
      stdout: 'hello\n',
      stderr: '',
    );

    final output = handler.emitOutput(
      shell: shell,
      host: host,
      operation: 'listDirectory',
      run: result,
      trimOutput: true,
    );

    expect(output, 'hello');
    expect(shell.lastOperation, 'listDirectory');
    expect(shell.lastCommand, 'ssh host ls');
    expect(shell.lastOutput, 'hello');
  });

  test('verificationFromExistsCheck maps exists result for shouldExist true', () {
    final verification = handler.verificationFromExistsCheck(
      run: const RunResult(
        command: 'test -e file',
        stdout: 'EXISTS\n',
        stderr: '',
      ),
      shouldExist: true,
    );

    expect(verification.passed, isTrue);
    expect(verification.command, 'test -e file');
  });

  test('verificationFromExistsCheck maps missing result for shouldExist false', () {
    final verification = handler.verificationFromExistsCheck(
      run: const RunResult(
        command: 'test -e file',
        stdout: 'MISSING\n',
        stderr: '',
      ),
      shouldExist: false,
    );

    expect(verification.passed, isTrue);
  });
}
