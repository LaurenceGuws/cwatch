import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../known_hosts_store.dart';
import '../remote_shell_base.dart';
import '../ssh_auth_coordinator.dart';
import 'builtin_ssh_auth_challenge_handler.dart';
import 'builtin_ssh_command_preparer.dart';
import 'builtin_ssh_client_lifecycle.dart';
import 'builtin_ssh_failure_mapper.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'builtin_identity_manager.dart';
import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_timeout_runner.dart';
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
  final BuiltInSshClientLifecycle _clientLifecycle = const BuiltInSshClientLifecycle();
  final BuiltInSshTimeoutRunner _timeoutRunner = const BuiltInSshTimeoutRunner();
  late final BuiltInSshAuthChallengeHandler _authChallengeHandler =
      BuiltInSshAuthChallengeHandler(
        vault: vault,
        authCoordinator: authCoordinator,
        setBuiltInKeyPassphrase: _identityManager.setBuiltInKeyPassphrase,
        setIdentityPassphrase: _identityManager.setIdentityPassphrase,
      );
  late final BuiltInSshCommandPreparer _commandPreparer =
      BuiltInSshCommandPreparer(
        identityManager: _identityManager,
        isNoShellHost: isNoShellHost,
        wrapSshErrors: _wrapSshErrors,
      );

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
    final safeCommand = _commandPreparer.prependNoHistory(command);
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
    final safeCommand = await _commandPreparer.prepareCommand(host, command);
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    final bytes = await _withClient(host, (client) async {
      final future = client.run(safeCommand);
      return _timeoutRunner.run(
        future: future,
        timeout: timeout,
        host: host,
        commandDescription: safeCommand,
        onTimeout: onTimeout,
        onKill: () => _clientLifecycle.killClient(client),
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
    final safeCommand = await _commandPreparer.prepareCommand(host, command);
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
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
        _clientLifecycle.killSession(session);
        _clientLifecycle.killClient(client);
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
      await _timeoutRunner.run(
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
          _clientLifecycle.killSession(session);
          _clientLifecycle.killClient(client);
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
      await _identityManager.ensureDecrypted(host);
      return _clientLifecycle.withManagedClient(
        () => _openClient(host),
        action,
      );
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
          final decrypted = await _authChallengeHandler.handleDecryptRequired(e);
          retries++;
          if (decrypted) {
            continue;
          }
        } else if (e is BuiltInSshKeyPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _authChallengeHandler.handleBuiltInPassphrase(e);
          retries++;
          if (provided) {
            continue;
          }
        } else if (e is BuiltInSshIdentityPassphraseRequired) {
          if (retries > 2) rethrow;
          final provided = await _authChallengeHandler.handleIdentityPassphrase(e);
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

}

