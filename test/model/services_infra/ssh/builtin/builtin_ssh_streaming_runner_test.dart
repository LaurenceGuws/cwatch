import 'dart:async';
import 'dart:typed_data';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_client_lifecycle.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_stream_output_collector.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_streaming_runner.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_timeout_runner.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSession implements SSHSession {
  _FakeSession({
    required this.stdoutController,
    required this.stderrController,
    required this.doneFuture,
    this.onClose,
  });

  final StreamController<Uint8List> stdoutController;
  final StreamController<Uint8List> stderrController;
  final Future<void> doneFuture;
  final void Function()? onClose;

  @override
  Stream<Uint8List> get stdout => stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => stderrController.stream;

  @override
  Future<void> get done => doneFuture;

  @override
  void close() {
    onClose?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClient implements SSHClient {
  _FakeClient(this.session);

  final SSHSession session;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    Map<String, String>? environment,
  }) async => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingLifecycle extends BuiltInSshClientLifecycle {
  const _RecordingLifecycle({
    required this.onKillClient,
    required this.onKillSession,
  });

  final void Function() onKillClient;
  final void Function() onKillSession;

  @override
  void killClient(SSHClient client) {
    onKillClient();
  }

  @override
  void killSession(SSHSession session) {
    onKillSession();
  }
}

void main() {
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  test('returns collected stdout output', () async {
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final session = _FakeSession(
      stdoutController: stdout,
      stderrController: stderr,
      doneFuture: Future<void>(() async {
        stdout.add(Uint8List.fromList('hello\nworld'.codeUnits));
        await stdout.close();
        await stderr.close();
      }),
    );
    final runner = BuiltInSshStreamingRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: const BuiltInSshClientLifecycle(),
      streamOutputCollector: const BuiltInSshStreamOutputCollector(),
    );

    final output = await runner.runCommandStreaming(
      host: host,
      client: _FakeClient(session),
      safeCommand: 'echo hello',
    );

    expect(output, 'hello\nworld');
  });

  test('kills session and client on timeout', () async {
    var killedClient = 0;
    var killedSession = 0;
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final session = _FakeSession(
      stdoutController: stdout,
      stderrController: stderr,
      doneFuture: Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    final runner = BuiltInSshStreamingRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: _RecordingLifecycle(
        onKillClient: () => killedClient++,
        onKillSession: () => killedSession++,
      ),
      streamOutputCollector: const BuiltInSshStreamOutputCollector(),
    );

    await expectLater(
      () => runner.runCommandStreaming(
        host: host,
        client: _FakeClient(session),
        safeCommand: 'sleep',
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(killedClient, 1);
    expect(killedSession, 1);
  });

  test('closes cancelled session before streaming starts', () async {
    var closed = 0;
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final session = _FakeSession(
      stdoutController: stdout,
      stderrController: stderr,
      doneFuture: Future.value(),
      onClose: () => closed++,
    );
    final cancellation = RemoteCommandCancellation();
    cancellation.cancel();
    final runner = BuiltInSshStreamingRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: const BuiltInSshClientLifecycle(),
      streamOutputCollector: const BuiltInSshStreamOutputCollector(),
    );

    await expectLater(
      () => runner.runCommandStreaming(
        host: host,
        client: _FakeClient(session),
        safeCommand: 'noop',
        cancellation: cancellation,
      ),
      throwsA(isA<RemoteCommandCancelled>()),
    );

    expect(closed, 1);
  });
}
