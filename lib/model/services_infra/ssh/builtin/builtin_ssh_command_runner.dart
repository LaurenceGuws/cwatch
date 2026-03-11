import 'dart:convert';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../remote_shell_base.dart';
import 'builtin_ssh_client_lifecycle.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_timeout_runner.dart';

class BuiltInSshCommandRunner {
  const BuiltInSshCommandRunner({
    required BuiltInSshTimeoutRunner timeoutRunner,
    required BuiltInSshClientLifecycle clientLifecycle,
  }) : _timeoutRunner = timeoutRunner,
       _clientLifecycle = clientLifecycle;

  final BuiltInSshTimeoutRunner _timeoutRunner;
  final BuiltInSshClientLifecycle _clientLifecycle;

  Future<String> runCommand({
    required SshHost host,
    required SSHClient client,
    required String safeCommand,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    final bytes = await _timeoutRunner.run(
      future: client.run(safeCommand),
      timeout: timeout,
      host: host,
      commandDescription: safeCommand,
      onTimeout: onTimeout,
      onKill: () => _clientLifecycle.killClient(client),
    );
    final output = utf8.decode(bytes, allowMalformed: true);
    logBuiltInSsh(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }
}
