import 'package:dartssh2/dartssh2.dart';

import 'builtin_ssh_logging.dart';

class BuiltInSshClientLifecycle {
  const BuiltInSshClientLifecycle();

  Future<T> withManagedClient<T>(
    Future<SSHClient> Function() openClient,
    Future<T> Function(SSHClient client) action,
  ) async {
    SSHClient? client;
    try {
      client = await openClient();
      return await action(client);
    } finally {
      await closeClient(client);
    }
  }

  Future<void> closeClient(SSHClient? client) async {
    client?.close();
    try {
      await client?.done;
    } catch (error) {
      logBuiltInSshWarning(
        'Failed waiting for SSH client to close',
        error: error,
      );
    }
  }

  void killClient(SSHClient client) {
    try {
      client.close();
    } catch (error) {
      logBuiltInSshWarning(
        'Failed to close SSH client on kill',
        error: error,
      );
    }
  }

  void killSession(SSHSession session) {
    try {
      session.close();
    } catch (error) {
      logBuiltInSshWarning(
        'Failed to close SSH session on kill',
        error: error,
      );
    }
  }

  void killSftp(SftpClient sftp) {
    try {
      sftp.close();
    } catch (error) {
      logBuiltInSshWarning(
        'Failed to close SFTP client on kill',
        error: error,
      );
    }
  }
}
