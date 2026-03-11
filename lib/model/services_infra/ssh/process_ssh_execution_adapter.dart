import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';

import 'process_ssh_failure_mapper.dart';
import 'process_ssh_runner.dart';
import 'remote_shell_base.dart';

class ProcessSshExecutionAdapter {
  const ProcessSshExecutionAdapter({
    ProcessSshRunner? runner,
    ProcessSshFailureMapper? failureMapper,
  }) : _runner = runner ?? const ProcessSshRunner(),
       _failureMapper = failureMapper ?? const ProcessSshFailureMapper();

  final ProcessSshRunner _runner;
  final ProcessSshFailureMapper _failureMapper;

  Future<RunResult> runSsh(
    SshHost host,
    String command, {
    required Never Function(SshHost host, ProcessResult result) onSshError,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runSsh(
        host,
        command,
        timeout: timeout,
        onSshError: onSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> runSshStreaming(
    SshHost host,
    String command, {
    required Never Function(SshHost host, ProcessResult result) onSshError,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    try {
      return await _runner.runSshStreaming(
        host,
        command,
        timeout: timeout,
        onSshError: onSshError,
        onTimeout: onTimeout,
        cancellation: cancellation,
        onStdoutLine: onStdoutLine,
        onStderrLine: onStderrLine,
      );
    } catch (error) {
      if (error is RemoteCommandCancelled) {
        rethrow;
      }
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> runHostCommand(
    SshHost host,
    String command, {
    required Never Function(SshHost host, ProcessResult result) onSshError,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runHostCommand(
        host,
        command,
        timeout: timeout,
        onSshError: onSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }

  Future<RunResult> runProcess(
    SshHost host,
    List<String> command, {
    required Never Function(SshHost host, ProcessResult result) onSshError,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    try {
      return await _runner.runProcess(
        command,
        timeout: timeout,
        hostForErrors: host,
        onSshError: onSshError,
        onTimeout: onTimeout,
      );
    } catch (error) {
      throw _failureMapper.map(host, error);
    }
  }
}
