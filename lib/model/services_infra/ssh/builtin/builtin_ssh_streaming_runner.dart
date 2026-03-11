import 'dart:async';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';

import '../remote_shell_base.dart';
import 'builtin_ssh_client_lifecycle.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_stream_output_collector.dart';
import 'builtin_ssh_timeout_runner.dart';

class BuiltInSshStreamingRunner {
  const BuiltInSshStreamingRunner({
    required BuiltInSshTimeoutRunner timeoutRunner,
    required BuiltInSshClientLifecycle clientLifecycle,
    required BuiltInSshStreamOutputCollector streamOutputCollector,
  }) : _timeoutRunner = timeoutRunner,
       _clientLifecycle = clientLifecycle,
       _streamOutputCollector = streamOutputCollector;

  final BuiltInSshTimeoutRunner _timeoutRunner;
  final BuiltInSshClientLifecycle _clientLifecycle;
  final BuiltInSshStreamOutputCollector _streamOutputCollector;

  Future<String> runCommandStreaming({
    required SshHost host,
    required SSHClient client,
    required String safeCommand,
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
    RemoteCommandCancellation? cancellation,
    void Function(String line)? onStdoutLine,
    void Function(String line)? onStderrLine,
  }) async {
    logBuiltInSsh('Running command on ${host.name}: $safeCommand');
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

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
    final output = stdoutBuffer.toString();
    logBuiltInSsh(
      'Command on ${host.name} completed. Output length=${output.length}',
    );
    return output;
  }
}
