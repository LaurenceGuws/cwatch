import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/ssh_host.dart';

import '../logging/app_logger.dart';
import 'remote_shell_base.dart';

/// Small helper that wraps process execution and SSH/scp command building.
class ProcessSshRunner {
  const ProcessSshRunner();

  static const Map<String, String> _historySanitizedEnv = {
    'HISTFILE': '/dev/null',
    'HISTSIZE': '0',
    'HISTFILESIZE': '0',
  };

  Future<RunResult> runProcess(
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    SshHost? hostForErrors,
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
  }) async {
    final hostLabel = hostForErrors?.name ?? 'local';
    _logProcess('Running command on $hostLabel: ${command.join(' ')}');
    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      environment: {...Platform.environment, ..._historySanitizedEnv},
      runInShell: false,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .forEach(stdoutBuffer.write);
    final stderrFuture = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);

    final stopwatch = Stopwatch()..start();
    final exitCode = await _waitForExit(
      process,
      timeout: timeout,
      hostForErrors: hostForErrors,
      onTimeout: onTimeout,
      elapsed: () => stopwatch.elapsed,
      commandDescription: command.join(' '),
    );
    await Future.wait([stdoutFuture, stderrFuture]);
    final stdoutStr = stdoutBuffer.toString();
    final stderrStr = stderrBuffer.toString();
    final processResult = ProcessResult(
      process.pid,
      exitCode,
      stdoutStr,
      stderrStr,
    );
    if (exitCode != 0) {
      if (hostForErrors != null &&
          (command.first.contains('ssh') ||
              command.contains('ssh') ||
              command.first.contains('scp') ||
              command.contains('scp'))) {
        onSshError?.call(hostForErrors, processResult);
      }
      throw Exception(stderrStr.isNotEmpty ? stderrStr : stdoutStr);
    }
    final commandString = command.join(' ');
    _logProcess(
      'Command on $hostLabel completed. Output length=${stdoutStr.length}',
    );
    return RunResult(
      command: commandString,
      stdout: stdoutStr,
      stderr: stderrStr,
    );
  }

  Future<int> _waitForExit(
    Process process, {
    required Duration timeout,
    required Duration Function() elapsed,
    SshHost? hostForErrors,
    RunTimeoutHandler? onTimeout,
    required String commandDescription,
  }) async {
    var nextTimeout = timeout;
    while (true) {
      try {
        return await process.exitCode.timeout(nextTimeout);
      } on TimeoutException {
        final resolution = onTimeout != null
            ? await onTimeout(
                TimeoutContext(
                  host: hostForErrors,
                  commandDescription: commandDescription,
                  elapsed: elapsed(),
                ),
              )
            : const TimeoutResolution.kill();
        if (resolution.shouldKill) {
          process.kill();
          try {
            await process.exitCode.timeout(const Duration(seconds: 2));
          } catch (_) {
            try {
              process.kill(ProcessSignal.sigkill);
            } catch (_) {}
          }
          throw TimeoutException(
            'Command timed out after ${elapsed().inSeconds}s',
            elapsed(),
          );
        }
        nextTimeout = resolution.extendBy ?? timeout;
        continue;
      }
    }
  }

  Future<RunResult> runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
    String? knownHostsPath,
  }) {
    final sanitizedCommand = _prependNoHistory(command);
    return runProcess(
      buildSshCommand(host, sanitizedCommand, knownHostsPath: knownHostsPath),
      timeout: timeout,
      hostForErrors: host,
      onSshError: onSshError,
      onTimeout: onTimeout,
    );
  }

  /// Returns the host portion for an SSH connection, including the username
  /// when provided for custom hosts.
  String connectionTarget(SshHost host) {
    if (host.source == 'custom') {
      final user = host.user?.trim();
      final hostname = host.hostname;
      if (user?.isNotEmpty == true) {
        return '$user@$hostname';
      }
      return hostname;
    }
    return host.name;
  }

  List<String> buildSshArgumentsForTerminal(
    SshHost host, {
    String? knownHostsPath,
  }) {
    final args = buildBaseSshOptions(host, knownHostsPath: knownHostsPath);
    args.add(connectionTarget(host));
    return args;
  }

  List<String> buildSshCommand(
    SshHost host,
    String command, {
    String? knownHostsPath,
  }) {
    return [
      'ssh',
      ...buildBaseSshOptions(host, knownHostsPath: knownHostsPath),
      connectionTarget(host),
      command,
    ];
  }

  List<String> buildBaseSshOptions(SshHost host, {String? knownHostsPath}) {
    final args = <String>[
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=accept-new',
    ];
    if (knownHostsPath != null && knownHostsPath.isNotEmpty) {
      args.addAll(['-o', 'UserKnownHostsFile=$knownHostsPath']);
    }
    args.addAll(['-p', host.port.toString()]);
    for (final identity in host.identityFiles) {
      final trimmed = identity.trim();
      if (trimmed.isNotEmpty) {
        args.addAll(['-i', trimmed]);
      }
    }
    return args;
  }

  Future<RunResult> runHostCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    void Function(SshHost host, ProcessResult result)? onSshError,
    RunTimeoutHandler? onTimeout,
    String? knownHostsPath,
  }) {
    return runSsh(
      host,
      command,
      timeout: timeout,
      onSshError: onSshError,
      onTimeout: onTimeout,
      knownHostsPath: knownHostsPath,
    );
  }

  String _prependNoHistory(String command) {
    return 'HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0; $command';
  }
}

void _logProcess(String message) {
  AppLogger.d(message, tag: 'ProcessSSH');
}
