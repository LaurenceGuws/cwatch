import 'dart:async';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_client_lifecycle.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_sftp_runner.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_timeout_runner.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements SSHClient {
  _FakeClient(this.sftpClient);

  final SftpClient sftpClient;

  @override
  Future<SftpClient> sftp() async => sftpClient;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSftpClient implements SftpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingLifecycle extends BuiltInSshClientLifecycle {
  const _RecordingLifecycle({
    required this.onKillClient,
    required this.onKillSftp,
  });

  final void Function() onKillClient;
  final void Function() onKillSftp;

  @override
  void killClient(SSHClient client) {
    onKillClient();
  }

  @override
  void killSftp(SftpClient sftp) {
    onKillSftp();
  }
}

void main() {
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  test('closes sftp after successful action', () async {
    var killedSftp = 0;
    final runner = BuiltInSshSftpRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: _RecordingLifecycle(
        onKillClient: () {},
        onKillSftp: () => killedSftp++,
      ),
    );
    final client = _FakeClient(_FakeSftpClient());

    final result = await runner.withSftp<String>(
      host: host,
      client: client,
      action: (sftp) async => 'ok',
    );

    expect(result, 'ok');
    expect(killedSftp, 1);
  });

  test('kills sftp and client when action times out', () async {
    var killedClient = 0;
    var killedSftp = 0;
    final runner = BuiltInSshSftpRunner(
      timeoutRunner: const BuiltInSshTimeoutRunner(),
      clientLifecycle: _RecordingLifecycle(
        onKillClient: () => killedClient++,
        onKillSftp: () => killedSftp++,
      ),
    );
    final client = _FakeClient(_FakeSftpClient());

    await expectLater(
      () => runner.withSftp<void>(
        host: host,
        client: client,
        timeout: const Duration(milliseconds: 1),
        action: (sftp) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(killedClient, 1);
    expect(killedSftp, 2);
  });
}
