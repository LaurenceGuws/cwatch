import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/model/features/docker/services/docker_cli_failure.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class DockerCliExecutor {
  const DockerCliExecutor({this.processRunner = Process.run});

  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  })
  processRunner;

  Future<ProcessResult> run(
    List<String> args, {
    required Duration timeout,
    String operation = 'run',
    String? contextLabel,
  }) async {
    final logger = AppLogger.remote(tag: 'Docker', source: 'docker');
    final command = 'docker ${args.join(' ')}';
    final resolvedContext = contextLabel ?? contextLabelFromArgs(args);
    try {
      final result = await processRunner(
        'docker',
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      ).timeout(timeout);
      final stdout = result.stdout?.toString() ?? '';
      final stderr = result.stderr?.toString() ?? '';
      final output = result.exitCode == 0 ? stdout : stderr;
      if (result.exitCode == 0) {
        logger.debug(
          'Completed $command',
          remote: RemoteCommandDetails(
            operation: operation,
            command: command,
            output: output,
            contextLabel: resolvedContext,
          ),
        );
      } else {
        logger.warn(
          'Command failed: $command',
          remote: RemoteCommandDetails(
            operation: operation,
            command: command,
            output: output,
            contextLabel: resolvedContext,
          ),
        );
      }
      return result;
    } on TimeoutException catch (error) {
      logger.warn(
        'Timed out $command after ${timeout.inSeconds}s',
        remote: RemoteCommandDetails(
          operation: operation,
          command: command,
          output: 'Timed out after ${timeout.inSeconds}s',
          contextLabel: resolvedContext,
        ),
      );
      throw DockerCliFailure.timeout(
        operation: operation,
        message: 'Timed out after ${timeout.inSeconds}s',
        contextLabel: resolvedContext,
        cause: error,
      );
    } on ProcessException catch (error) {
      logger.error(
        'Process error running $command',
        error: error,
        remote: RemoteCommandDetails(
          operation: operation,
          command: command,
          output: 'Process error: ${error.message}',
          contextLabel: resolvedContext,
        ),
      );
      throw DockerCliFailure.unavailable(
        operation: operation,
        message: error.message,
        contextLabel: resolvedContext,
        cause: error,
      );
    } catch (error) {
      logger.error(
        'Error running $command',
        error: error,
        remote: RemoteCommandDetails(
          operation: operation,
          command: command,
          output: 'Error: $error',
          contextLabel: resolvedContext,
        ),
      );
      throw DockerCliFailure.processError(
        operation: operation,
        message: 'Error running docker command: $error',
        contextLabel: resolvedContext,
        cause: error,
      );
    }
  }

  String contextLabelFromArgs(List<String> args) {
    final contextIndex = args.indexOf('--context');
    if (contextIndex != -1 && contextIndex + 1 < args.length) {
      final value = args[contextIndex + 1].trim();
      if (value.isNotEmpty) return value;
    }
    final hostIndex = args.indexOf('--host');
    if (hostIndex != -1 && hostIndex + 1 < args.length) {
      final value = args[hostIndex + 1].trim();
      if (value.isNotEmpty) return value;
    }
    return 'default';
  }
}
