import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/ssh_host.dart';

import '../logging/app_logger.dart';
import 'remote_shell_base.dart';

/// Small helper that wraps process execution and SSH/scp command building.
class ProcessSshRunner {
  const ProcessSshRunner();

  Future<RunResult> runProcess(
    List<String> command, {
    Duration timeout = const Duration(seconds: 10),
    SshHost? hostForErrors,
    void Function(SshHost host, ProcessResult result)? onSshError,
  }) async {
    final hostLabel = hostForErrors?.name ?? 'local';
    _logProcess('Running command on $hostLabel: ${command.join(' ')}');
    final result = await Process.run(
      command.first,
      command.skip(1).toList(),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    ).timeout(timeout);

    final stdoutStr = (result.stdout as String?) ?? '';
    final stderrStr = (result.stderr as String?) ?? '';
    if (result.exitCode != 0) {
      if (hostForErrors != null &&
          (command.first.contains('ssh') ||
              command.contains('ssh') ||
              command.first.contains('scp') ||
              command.contains('scp'))) {
        onSshError?.call(hostForErrors, result);
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

  Future<RunResult> runSsh(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    void Function(SshHost host, ProcessResult result)? onSshError,
  }) {
    return runProcess(
      buildSshCommand(host, command),
      timeout: timeout,
      hostForErrors: host,
      onSshError: onSshError,
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

  List<String> buildSshArgumentsForTerminal(SshHost host) {
    final args = buildBaseSshOptions(host);
    args.add(connectionTarget(host));
    return args;
  }

  List<String> buildSshCommand(SshHost host, String command) {
    return [
      'ssh',
      ...buildBaseSshOptions(host),
      connectionTarget(host),
      command,
    ];
  }

  List<String> buildBaseSshOptions(SshHost host) {
    final args = <String>[
      '-o',
      'BatchMode=yes',
      '-o',
      'StrictHostKeyChecking=no',
      '-o',
      'UserKnownHostsFile=/dev/null',
      '-p',
      host.port.toString(),
    ];
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
  }) {
    return runSsh(
      host,
      command,
      timeout: timeout,
      onSshError: onSshError,
    );
  }
}

void _logProcess(String message) {
  AppLogger.d(message, tag: 'ProcessSSH');
}
