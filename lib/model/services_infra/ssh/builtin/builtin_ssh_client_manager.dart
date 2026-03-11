import 'dart:async';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../known_hosts_store.dart';
import '../remote_shell_base.dart';
import '../ssh_auth_coordinator.dart';
import 'builtin_ssh_auth_challenge_handler.dart';
import 'builtin_ssh_client_connector.dart';
import 'builtin_ssh_command_preparer.dart';
import 'builtin_ssh_command_runner.dart';
import 'builtin_ssh_client_lifecycle.dart';
import 'builtin_ssh_failure_mapper.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'builtin_identity_manager.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_retry_handler.dart';
import 'builtin_ssh_stream_output_collector.dart';
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
  final BuiltInSshStreamOutputCollector _streamOutputCollector =
      const BuiltInSshStreamOutputCollector();
  late final BuiltInSshCommandRunner _commandRunner = BuiltInSshCommandRunner(
    timeoutRunner: _timeoutRunner,
    clientLifecycle: _clientLifecycle,
  );
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
  late final BuiltInSshRetryHandler _retryHandler = BuiltInSshRetryHandler(
    failureMapper: _failureMapper,
    authChallengeHandler: _authChallengeHandler,
  );
  late final BuiltInSshClientConnector _clientConnector =
      BuiltInSshClientConnector(
        identityManager: _identityManager,
        knownHostsStore: knownHostsStore,
        connectTimeout: connectTimeout,
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
    return _withClient(host, (client) {
      return _commandRunner.runCommand(
        host: host,
        client: client,
        safeCommand: safeCommand,
        timeout: timeout,
        onTimeout: onTimeout,
      );
    });
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
      final stdoutDone = _streamOutputCollector.collect(
        stream: session.stdout,
        buffer: stdoutBuffer,
        onLine: onStdoutLine,
      );
      final stderrDone = _streamOutputCollector.collect(
        stream: session.stderr,
        buffer: stderrBuffer,
        onLine: onStderrLine,
      );
      await _timeoutRunner.run(
        future: Future.wait([
          session.done,
          stdoutDone,
          stderrDone,
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
    return _retryHandler.run(host, action);
  }

  Future<SSHClient> _openClient(SshHost host) async {
    return _clientConnector.openClient(host);
  }

}
