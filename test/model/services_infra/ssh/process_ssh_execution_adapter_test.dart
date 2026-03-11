import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_execution_adapter.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_failure_mapper.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_runner.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_runtime_failure.dart';

void main() {
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  group('ProcessSshExecutionAdapter', () {
    test('maps runner errors for ssh commands', () async {
      final adapter = ProcessSshExecutionAdapter(
        runner: _FakeRunner(runSshError: TimeoutException('timed out')),
        failureMapper: const ProcessSshFailureMapper(),
      );

      await expectLater(
        () => adapter.runSsh(
          host,
          'echo hi',
          onSshError: _throwSshError,
        ),
        throwsA(
          isA<SshRuntimeFailure>().having(
            (failure) => failure.kind,
            'kind',
            SshRuntimeFailureKind.timedOut,
          ),
        ),
      );
    });

    test('preserves cancellation for ssh streaming commands', () async {
      final adapter = ProcessSshExecutionAdapter(
        runner: _FakeRunner(
          runSshStreamingError: const RemoteCommandCancelled(),
        ),
      );

      await expectLater(
        () => adapter.runSshStreaming(
          host,
          'tail -f log',
          onSshError: _throwSshError,
        ),
        throwsA(isA<RemoteCommandCancelled>()),
      );
    });

    test('maps runner errors for host commands and process commands', () async {
      final adapter = ProcessSshExecutionAdapter(
        runner: _FakeRunner(
          runHostCommandError: Exception('host failed'),
          runProcessError: const ProcessException('scp', <String>[]),
        ),
        failureMapper: const ProcessSshFailureMapper(),
      );

      await expectLater(
        () => adapter.runHostCommand(
          host,
          'mkdir -p /tmp/a',
          onSshError: _throwSshError,
        ),
        throwsA(isA<SshRuntimeFailure>()),
      );

      await expectLater(
        () => adapter.runProcess(
          host,
          const ['scp', 'a', 'b'],
          onSshError: _throwSshError,
        ),
        throwsA(
          isA<SshRuntimeFailure>().having(
            (failure) => failure.kind,
            'kind',
            SshRuntimeFailureKind.unavailable,
          ),
        ),
      );
    });
  });
}

Never _throwSshError(SshHost host, ProcessResult result) {
  throw Exception(result.stderr);
}

class _FakeRunner extends ProcessSshRunner {
  const _FakeRunner({
    this.runSshError,
    this.runSshStreamingError,
    this.runHostCommandError,
    this.runProcessError,
  });

  final Object? runSshError;
  final Object? runSshStreamingError;
  final Object? runHostCommandError;
  final Object? runProcessError;

  @override
  Future<RunResult> runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    String? knownHostsPath,
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
  }) async {
    final error = runSshError;
    if (error != null) throw error;
    return const RunResult(command: 'ssh', stdout: 'ok', stderr: '');
  }

  @override
  Future<RunResult> runSshStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    String? knownHostsPath,
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    final error = runSshStreamingError;
    if (error != null) throw error;
    return const RunResult(command: 'ssh', stdout: 'ok', stderr: '');
  }

  @override
  Future<RunResult> runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    String? knownHostsPath,
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
  }) async {
    final error = runHostCommandError;
    if (error != null) throw error;
    return const RunResult(command: 'ssh', stdout: 'ok', stderr: '');
  }

  @override
  Future<RunResult> runProcess(
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    SshHost? hostForErrors,
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
  }) async {
    final error = runProcessError;
    if (error != null) throw error;
    return const RunResult(command: 'scp', stdout: 'ok', stderr: '');
  }
}
