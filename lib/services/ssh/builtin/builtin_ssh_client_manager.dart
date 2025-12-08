import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../remote_shell_base.dart';
import 'builtin_identity_manager.dart';
import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_vault.dart';

class BuiltInSshClientManager {
  BuiltInSshClientManager({
    required this.vault,
    required Map<String, String> hostKeyBindings,
    this.connectTimeout = const Duration(seconds: 10),
    this.promptUnlock,
  }) : _identityManager = BuiltInSshIdentityManager(
          vault: vault,
          hostKeyBindings: hostKeyBindings,
          promptUnlock: promptUnlock,
        );

  final BuiltInSshVault vault;
  final Duration connectTimeout;
  final BuiltInSshIdentityManager _identityManager;
  final Future<bool> Function(String keyId, String hostName, String? keyLabel)?
      promptUnlock;

  String? boundKeyForHost(String hostName) =>
      _identityManager.boundKeyForHost(hostName);

  void setIdentityPassphrase(String identityPath, String passphrase) {
    _identityManager.setIdentityPassphrase(identityPath, passphrase);
  }

  void setBuiltInKeyPassphrase(String keyId, String passphrase) {
    _identityManager.setBuiltInKeyPassphrase(keyId, passphrase);
  }

  Future<RunResult> runRemoteCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    logBuiltInSsh('Running remote command on ${host.name}: $command');
    final checkCommand = '$command; echo "EXIT_CODE:\$?"';
    final output = await runCommand(host, checkCommand, timeout: timeout);
    final exitCodeMatch = RegExp(r'EXIT_CODE:(\d+)').firstMatch(output);
    if (exitCodeMatch != null) {
      final exitCode = int.tryParse(exitCodeMatch.group(1) ?? '') ?? -1;
      if (exitCode != 0) {
        logBuiltInSsh('Command failed on ${host.name} with exit code: $exitCode');
        throw Exception('Command failed with exit code $exitCode');
      }
      logBuiltInSsh('Command on ${host.name} completed successfully');
    } else {
      logBuiltInSsh(
        'Warning: Could not parse exit code for command on ${host.name}',
      );
    }
    return RunResult(command: command, stdout: output, stderr: '');
  }

  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    logBuiltInSsh('Running command on ${host.name}: $command');
    final bytes = await _withClient(
      host,
      (client) => client.run(command).timeout(timeout),
    );
    final output = utf8.decode(bytes, allowMalformed: true);
    logBuiltInSsh(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }

  Future<T> withSftp<T>(
    SshHost host,
    Future<T> Function(SftpClient client) action,
  ) async {
    return _withClient(host, (client) async {
      final sftp = await client.sftp();
      try {
        return await action(sftp);
      } finally {
        sftp.close();
      }
    });
  }

  Future<SSHClient> openPersistentClient(SshHost host) {
    return _wrapSshErrors(host, () async {
      await _identityManager.ensureUnlocked(host);
      return _openClient(host);
    });
  }

  Future<T> _withClient<T>(
    SshHost host,
    Future<T> Function(SSHClient client) action,
  ) async {
    return _wrapSshErrors(host, () async {
      SSHClient? client;
      try {
        await _identityManager.ensureUnlocked(host);
        client = await _openClient(host);
        return await action(client);
      } finally {
        client?.close();
        try {
          await client?.done;
        } catch (_) {
          // Ignore errors during cleanup
        }
      }
    });
  }

  Future<T> _wrapSshErrors<T>(
    SshHost host,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on SSHAuthFailError catch (error) {
      logBuiltInSsh('Authentication failed for ${host.name}: $error');
      throw BuiltInSshAuthenticationFailed(
        hostName: host.name,
        message: error.toString(),
      );
    } catch (e) {
      if (e is BuiltInSshKeyLockedException ||
          e is BuiltInSshKeyPassphraseRequired ||
          e is BuiltInSshKeyUnsupportedCipher ||
          e is BuiltInSshIdentityPassphraseRequired ||
          e is BuiltInSshAuthenticationFailed) {
        rethrow;
      }
      logBuiltInSsh('Error in SSH operation for ${host.name}: $e');
      throw Exception('SSH operation failed for ${host.name}: $e');
    }
  }

  Future<SSHClient> _openClient(SshHost host) async {
    final socket = await SSHSocket.connect(
      host.hostname,
      host.port,
      timeout: connectTimeout,
    );
    final username =
        host.user ??
        Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        'root';
    final identities = await _identityManager.loadIdentities(host);
    logBuiltInSsh(
      'Opening SSH client to ${host.name}@${host.hostname}:${host.port} '
      'with ${identities.length} identities '
      'boundKey=${_identityManager.boundKeyForHost(host.name) ?? 'none'}',
    );
    if (identities.isEmpty) {
      socket.destroy();
      throw Exception('No SSH identity available for ${host.name}');
    }
    return SSHClient(
      socket,
      username: username,
      identities: identities,
      disableHostkeyVerification: true,
    );
  }
}
