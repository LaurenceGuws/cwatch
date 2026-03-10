import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../known_hosts_store.dart';
import '../remote_shell_base.dart';
import '../ssh_auth_coordinator.dart';
import 'builtin_ssh_failure_mapper.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
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
  final BuiltInSshFailureMapper _failureMapper = const BuiltInSshFailureMapper();
  final Map<String, Future<bool>> _pendingDecryptRequests = {};

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
        logBuiltInSshWarning(
          'Command failed on ${host.name} with exit code $exitCode',
        );
        throw Exception('Command failed with exit code $exitCode');
      }
      logBuiltInSsh('Command on ${host.name} completed successfully');
    } else {
      logBuiltInSshWarning(
        'Could not parse exit code for command on ${host.name}',
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
    if (isNoShellHost(host)) {
      throw NoShellHostException(host);
    }
    final safeCommand = _prependNoHistory(command);
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    // Ensure decryption completes before starting timeout.
    // This way password prompts don't count against the command timeout.
    // Note: _withClient also calls ensureDecrypted, but calling it here first
    // ensures the timeout only applies to command execution, not password entry.
    await _wrapSshErrors(host, () async {
      await _identityManager.ensureDecrypted(host);
    });
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
          } catch (error) {
            logBuiltInSshWarning(
              'Failed to close SSH client on kill',
              error: error,
            );
          }
        },
      );
    });
    final output = utf8.decode(bytes, allowMalformed: true);
    logBuiltInSsh(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }

  Future<String> runCommandStreaming(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    if (isNoShellHost(host)) {
      throw NoShellHostException(host);
    }
    final safeCommand = _prependNoHistory(command);
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    // Ensure decryption completes before starting timeout.
    // This way password prompts don't count against the command timeout.
    // Note: _withClient also calls ensureDecrypted, but calling it here first
    // ensures the timeout only applies to command execution, not password entry.
    await _wrapSshErrors(host, () async {
      await _identityManager.ensureDecrypted(host);
    });
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    var stdoutRemainder = '';
    var stderrRemainder = '';

    Future<void> handleStream(
      Stream<Uint8List> stream,
      StringBuffer buffer,
      void Function(String line)? onLine,
      void Function(String value) setRemainder,
      String Function() getRemainder,
      void Function() onDone,
    ) async {
      await stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach((chunk) {
            buffer.write(chunk);
            if (onLine == null) {
              return;
            }
            final combined = getRemainder() + chunk;
            final parts = combined.split('\n');
            setRemainder(parts.removeLast());
            for (final line in parts) {
              onLine(line);
            }
          });
      if (onLine != null) {
        final remainder = getRemainder();
        if (remainder.isNotEmpty) {
          onLine(remainder);
        }
      }
      onDone();
    }

    final bytes = await _withClient(host, (client) async {
      final session = await client.execute(safeCommand);
      if (cancellation?.isCancelled == true) {
        session.close();
        throw const RemoteCommandCancelled();
      }
      cancellation?.onCancel(() {
        try {
          session.close();
        } catch (error) {
          logBuiltInSshWarning(
            'Failed to close SSH session on cancel',
            error: error,
          );
        }
        try {
          client.close();
        } catch (error) {
          logBuiltInSshWarning(
            'Failed to close SSH client on cancel',
            error: error,
          );
        }
      });
      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();
      unawaited(
        handleStream(
          session.stdout,
          stdoutBuffer,
          onStdoutLine,
          (value) => stdoutRemainder = value,
          () => stdoutRemainder,
          stdoutDone.complete,
        ),
      );
      unawaited(
        handleStream(
          session.stderr,
          stderrBuffer,
          onStderrLine,
          (value) => stderrRemainder = value,
          () => stderrRemainder,
          stderrDone.complete,
        ),
      );
      await _waitWithTimeout(
        future: Future.wait([
          session.done,
          stdoutDone.future,
          stderrDone.future,
        ]),
        timeout: timeout,
        host: host,
        commandDescription: safeCommand,
        onTimeout: onTimeout,
        onKill: () {
          try {
            session.close();
          } catch (error) {
            logBuiltInSshWarning(
              'Failed to close SSH session on kill',
              error: error,
            );
          }
          try {
            client.close();
          } catch (error) {
            logBuiltInSshWarning(
              'Failed to close SSH client on kill',
              error: error,
            );
          }
        },
      );
      return stdoutBuffer.toString();
    });
    final output = bytes;
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
            } catch (error) {
              logBuiltInSshWarning(
                'Failed to close SFTP client on kill',
                error: error,
              );
            }
            try {
              client.close();
            } catch (error) {
              logBuiltInSshWarning(
                'Failed to close SSH client on kill',
                error: error,
              );
            }
          },
        );
      } finally {
        sftp.close();
      }
    });
  }

  Future<SSHClient> openPersistentClient(SshHost host) {
    return _wrapSshErrors(host, () async {
      await _identityManager.ensureDecrypted(host);
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
        await _identityManager.ensureDecrypted(host);
        client = await _openClient(host);
        return await action(client);
      } finally {
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
    });
  }

  Future<T> _wrapSshErrors<T>(SshHost host, Future<T> Function() action) async {
    var retries = 0;
    while (true) {
      try {
        if (isNoShellHost(host)) {
          throw NoShellHostException(host);
        }
        return await action();
      } on SSHAuthFailError catch (error) {
        logBuiltInSshWarning(
          'Authentication failed for ${host.name}',
          error: error,
        );
        throw _failureMapper.map(
          host,
          BuiltInSshAuthenticationFailed(
          hostName: host.name,
          message: error.toString(),
          ),
        );
      } on SSHStateError catch (error) {
        logBuiltInSshWarning('SSH state error for ${host.name}', error: error);
        throw _failureMapper.map(
          host,
          Exception('SSH connection failed for ${host.name}: $error'),
        );
      } catch (e) {
        logBuiltInSshWarning('SSH operation failed for ${host.name}', error: e);
        if (e is BuiltInSshKeyDecryptionRequired) {
          if (retries > 2) rethrow;
          final decrypted = await _handleDecryptRequired(e);
          retries++;
          if (decrypted) {
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
            e is NoShellHostException) {
          rethrow;
        }
        logBuiltInSshWarning(
          'Error in SSH operation for ${host.name}',
          error: e,
        );
        throw _failureMapper.map(host, e);
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

  Future<bool> _handleDecryptRequired(
    BuiltInSshKeyDecryptionRequired error,
  ) async {
    if (vault.isDecrypted(error.keyId)) {
      return true;
    }
    final pending = _pendingDecryptRequests[error.keyId];
    if (pending != null) {
      return pending;
    }
    final future = () async {
      final request = SshKeyDecryptRequest(
        keyId: error.keyId,
        hostName: error.hostName,
        keyLabel: error.keyLabel,
        storageEncrypted: await vault.isEncrypted(error.keyId),
      );
      final result = await authCoordinator.onDecryptKey?.call(request);
      if (result == null || result.decrypted != true) {
        return false;
      }
      if (!vault.isDecrypted(error.keyId) && result.password != null) {
        try {
          await vault.decrypt(error.keyId, result.password);
        } catch (e) {
          logBuiltInSshWarning(
            'Failed to decrypt built-in key ${error.keyId}',
            error: e,
          );
          return false;
        }
      }
      return vault.isDecrypted(error.keyId);
    }();
    _pendingDecryptRequests[error.keyId] = future;
    try {
      return await future;
    } finally {
      _pendingDecryptRequests.remove(error.keyId);
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
