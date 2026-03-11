import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_timeout_runner.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';

void main() {
  const host = SshHost(name: 'h', hostname: '127.0.0.1', port: 22, available: true);

  test('returns future value when it completes in time', () async {
    final runner = const BuiltInSshTimeoutRunner();

    final result = await runner.run<int>(
      future: Future.value(7),
      timeout: const Duration(milliseconds: 10),
      host: host,
      commandDescription: 'cmd',
      onKill: () {},
    );

    expect(result, 7);
  });

  test('kills and throws timeout when handler does not extend', () async {
    final runner = const BuiltInSshTimeoutRunner();
    var killed = false;

    await expectLater(
      () => runner.run<void>(
        future: Future<void>.delayed(const Duration(milliseconds: 20)),
        timeout: const Duration(milliseconds: 1),
        host: host,
        commandDescription: 'cmd',
        onKill: () => killed = true,
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(killed, true);
  });

  test('extends timeout when handler requests extension', () async {
    final runner = const BuiltInSshTimeoutRunner();
    var calls = 0;

    final result = await runner.run<int>(
      future: Future<int>.delayed(const Duration(milliseconds: 5), () => 3),
      timeout: const Duration(milliseconds: 1),
      host: host,
      commandDescription: 'cmd',
      onTimeout: (_) async {
        calls++;
        return const TimeoutResolution.wait(Duration(milliseconds: 10));
      },
      onKill: () {},
    );

    expect(result, 3);
    expect(calls, 1);
  });
}
