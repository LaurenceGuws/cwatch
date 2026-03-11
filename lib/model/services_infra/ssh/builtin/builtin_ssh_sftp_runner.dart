import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../remote_shell_base.dart';
import 'builtin_ssh_client_lifecycle.dart';
import 'builtin_ssh_timeout_runner.dart';

class BuiltInSshSftpRunner {
  const BuiltInSshSftpRunner({
    required BuiltInSshTimeoutRunner timeoutRunner,
    required BuiltInSshClientLifecycle clientLifecycle,
  }) : _timeoutRunner = timeoutRunner,
       _clientLifecycle = clientLifecycle;

  final BuiltInSshTimeoutRunner _timeoutRunner;
  final BuiltInSshClientLifecycle _clientLifecycle;

  Future<T> withSftp<T>({
    required SshHost host,
    required SSHClient client,
    required Future<T> Function(SftpClient client) action,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    final sftp = await client.sftp();
    try {
      return await _timeoutRunner.run(
        future: action(sftp),
        timeout: timeout,
        host: host,
        commandDescription: 'sftp:${host.name}',
        onTimeout: onTimeout,
        onKill: () {
          _clientLifecycle.killSftp(sftp);
          _clientLifecycle.killClient(client);
        },
      );
    } finally {
      _clientLifecycle.killSftp(sftp);
    }
  }
}
