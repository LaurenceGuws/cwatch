import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../known_hosts_store.dart';
import '../remote_shell_base.dart';
import '../ssh_auth_coordinator.dart';
import 'builtin_identity_manager.dart';
import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_vault.dart';

class BuiltInSshClientManager {
  BuiltInSshClientManager({
    required this.vault,
    required Map<String, String> hostKeyBindings,
    this.connectTimeout = const Duration(seconds: 10),
    SshAuthCoordinator? authCoordinator,
    KnownHostsStore? knownHostsStore,
  }) : _identityManager = BuiltInSshIdentityManager(
         vault: vault,
         hostKeyBindings: hostKeyBindings,
       ),
       authCoordinator = authCoordinator ?? const SshAuthCoordinator(),
       knownHostsStore = knownHostsStore ?? const KnownHostsStore();

  final BuiltInSshVault vault;
  final Duration connectTimeout;
  final BuiltInSshIdentityManager _identityManager;
  final SshAuthCoordinator authCoordinator;
  final KnownHostsStore knownHostsStore;
  final Map<String, Future<bool>> _pendingUnlockRequests = {};

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
    RunTimeoutHandler? onTimeout,
  }) async {
    final safeCommand = _prependNoHistory(command);
    logBuiltInSsh('Running remote command on ${host.name}: $safeCommand');
    final checkCommand = '$safeCommand; echo "EXIT_CODE:\$?"';
    final output = await runCommand(
      host,
      checkCommand,
      timeout: timeout,
      onTimeout: onTimeout,
    );
    final exitCodeMatch = RegExp(r'EXIT_CODE:(\d+)').firstMatch(output);
    if (exitCodeMatch != null) {
      final exitCode = int.tryParse(exitCodeMatch.group(1) ?? '') ?? -1;
      if (exitCode != 0) {
        logBuiltInSsh(
          'Command failed on ${host.name} with exit code: $exitCode',
        );
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
    RunTimeoutHandler? onTimeout,
  }) async {
    final safeCommand = _prependNoHistory(command);
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    final bytes = await _withClient(host, (client) async {
      final future = client.run(safeCommand);
      return _waitWithTimeout(
        future: future,
        timeout: timeout,
        host: host,
        commandDescription: safeCommand,
        onTimeout: onTimeout,
        onKill: () {
          try {
            client.close();
          } catch (_) {}
        },
      );
    });
    final output = utf8.decode(bytes, allowMalformed: true);
    logBuiltInSsh(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }

  Future<T> withSftp<T>(
    SshHost host,
    Future<T> Function(SftpClient client) action, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) async {
    return _withClient(host, (client) async {
      final sftp = await client.sftp();
      try {
        return await _waitWithTimeout(
          future: action(sftp),
          timeout: timeout,
          host: host,
          commandDescription: 'sftp:${host.name}',
          onTimeout: onTimeout,
          onKill: () {
            try {
              sftp.close();
            } catch (_) {}
            try {
              client.close();
            } catch (_) {}
          },
        );
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

  Future<T> _wrapSshErrors<T>(SshHost host, Future<T> Function() action) async {
    var retries = 0;
    while (true) {
      try {
        return await action();
      } on SSHAuthFailError catch (error) {
        logBuiltInSsh('Authentication failed for ${host.name}: $error');
        throw BuiltInSshAuthenticationFailed(
          hostName: host.name,
          message: error.toString(),
        );
      } on SSHStateError catch (error) {
        logBuiltInSsh('SSH state error for ${host.name}: $error');
        throw Exception('SSH connection failed for ${host.name}: $error');
      } catch (e) {
        if (e is BuiltInSshKeyLockedException) {
          if (retries > 2) rethrow;
          final unlocked = await _handleLockedKey(e);
          retries++;
          if (unlocked) {
            continue;
          }
        } else if (e is BuiltInSshKeyPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _handleBuiltInPassphrase(e);
          retries++;
          if (provided) {
            continue;
          }
        } else if (e is BuiltInSshIdentityPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _handleIdentityPassphrase(e);
          retries++;
          if (provided) {
            continue;
          }
        } else if (e is BuiltInSshKeyUnsupportedCipher ||
            e is BuiltInSshAuthenticationFailed) {
          rethrow;
        }
        logBuiltInSsh('Error in SSH operation for ${host.name}: $e');
        throw Exception('SSH operation failed for ${host.name}: $e');
      }
    }
  }

  Future<T> _waitWithTimeout<T>({
    required Future<T> future,
    required Duration timeout,
    required SshHost host,
    required String commandDescription,
    RunTimeoutHandler? onTimeout,
    required void Function() onKill,
  }) async {
    var nextTimeout = timeout;
    final stopwatch = Stopwatch()..start();
    while (true) {
      try {
        return await future.timeout(nextTimeout);
      } on TimeoutException {
        final resolution = onTimeout != null
            ? await onTimeout(
                TimeoutContext(
                  host: host,
                  commandDescription: commandDescription,
                  elapsed: stopwatch.elapsed,
                ),
              )
            : const TimeoutResolution.kill();
        if (resolution.shouldKill) {
          onKill();
          throw TimeoutException(
            'SSH command timed out after ${stopwatch.elapsed.inSeconds}s',
            stopwatch.elapsed,
          );
        }
        nextTimeout = resolution.extendBy ?? timeout;
      }
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
      disableHostkeyVerification: false,
      onVerifyHostKey: (type, fingerprint) async {
        final label = _hostLabel(host);
        final fingerprintHex = _fingerprintHex(fingerprint);
        final result = await knownHostsStore.verifyAndRecord(
          host: label,
          type: type,
          fingerprint: fingerprintHex,
        );
        if (!result.accepted) {
          logBuiltInSsh(
            'Host key verification failed for $label (type=$type fingerprint=$fingerprintHex)',
          );
        } else if (result.added) {
          logBuiltInSsh(
            'Trusted new host key for $label (type=$type fingerprint=$fingerprintHex)',
          );
        }
        return result.accepted;
      },
    );
  }

  String _fingerprintHex(List<int> fingerprint) {
    return fingerprint
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':');
  }

  String _hostLabel(SshHost host) {
    if (host.port == 22) {
      return host.hostname;
    }
    return '[${host.hostname}]:${host.port}';
  }

  String _prependNoHistory(String command) {
    return 'HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0; $command';
  }

  Future<bool> _handleLockedKey(BuiltInSshKeyLockedException error) async {
    if (vault.isUnlocked(error.keyId)) {
      return true;
    }
    final pending = _pendingUnlockRequests[error.keyId];
    if (pending != null) {
      return pending;
    }
    final future = () async {
      final request = SshKeyUnlockRequest(
        keyId: error.keyId,
        hostName: error.hostName,
        keyLabel: error.keyLabel,
        storageEncrypted: await vault.needsPassword(error.keyId),
      );
      final result = await authCoordinator.onUnlockKey?.call(request);
      if (result == null || result.unlocked != true) {
        return false;
      }
      if (!vault.isUnlocked(error.keyId) && result.password != null) {
        try {
          await vault.unlock(error.keyId, result.password);
        } catch (_) {
          return false;
        }
      }
      return vault.isUnlocked(error.keyId);
    }();
    _pendingUnlockRequests[error.keyId] = future;
    try {
      return await future;
    } finally {
      _pendingUnlockRequests.remove(error.keyId);
    }
  }

  Future<bool> _handleBuiltInPassphrase(
    BuiltInSshKeyPassphraseRequired error,
  ) async {
    final passphrase = await authCoordinator.onRequestPassphrase?.call(
      SshPassphraseRequest(
        hostName: error.hostName,
        kind: SshPassphraseKind.builtInKey,
        targetLabel: error.keyLabel ?? error.keyId,
      ),
    );
    if (passphrase == null || passphrase.isEmpty) {
      return false;
    }
    _identityManager.setBuiltInKeyPassphrase(error.keyId, passphrase);
    return true;
  }

  Future<bool> _handleIdentityPassphrase(
    BuiltInSshIdentityPassphraseRequired error,
  ) async {
    final passphrase = await authCoordinator.onRequestPassphrase?.call(
      SshPassphraseRequest(
        hostName: error.hostName,
        kind: SshPassphraseKind.identityFile,
        targetLabel: error.identityPath,
      ),
    );
    if (passphrase == null || passphrase.isEmpty) {
      return false;
    }
    _identityManager.setIdentityPassphrase(error.identityPath, passphrase);
    return true;
  }
}
