import 'dart:async';
import 'dart:typed_data';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_client_lifecycle.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_command_runner.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_timeout_runner.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements SSHClient {
  _FakeClient(this.future);

  final Future<Uint8List> future;

  @override
  Future<Uint8List> run(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) => future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingLifecycle extends BuiltInSshClientLifecycle {
  const _RecordingLifecycle(this.onKill);

  final void Function() onKill;

  @override
  void killClient(SSHClient client) {
    onKill();
  }
}

void main() {
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  test('decodes command output', () async {
    final runner = BuiltInSshCommandRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: const BuiltInSshClientLifecycle(),
    );
    final client = _FakeClient(
      Future.value(Uint8List.fromList('hello'.codeUnits)),
    );

    final output = await runner.runCommand(
      host: host,
      client: client,
      safeCommand: 'echo hello',
    );

    expect(output, 'hello');
  });

  test('kills client when command times out', () async {
    var killed = false;
    final runner = BuiltInSshCommandRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: _RecordingLifecycle(() => killed = true),
    );
    final client = _FakeClient(Future<Uint8List>.delayed(
      const Duration(milliseconds: 50),
      () => Uint8List(0),
    ));

    await expectLater(
      () => runner.runCommand(
        host: host,
        client: client,
        safeCommand: 'sleep',
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(killed, true);
  });
}
