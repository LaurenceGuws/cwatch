import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_failure_mapper.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_runtime_failure.dart';

void main() {
  group('ProcessSshFailureMapper', () {
    const mapper = ProcessSshFailureMapper();
    const host = SshHost(
      name: 'example',
      hostname: 'example.local',
      port: 22,
      available: true,
    );

    test('maps permission denied result to authentication failure', () {
      final failure = mapper.fromProcessResult(
        host,
        ProcessResult(1, 255, '', 'Permission denied (publickey)'),
      );

      expect(failure.kind, SshRuntimeFailureKind.authenticationFailed);
      expect(failure.message, contains('SSH authentication failed'));
    });

    test('maps timeout error to timedOut failure', () {
      final failure = mapper.map(
        host,
        TimeoutException('Command timed out after 10s'),
      );

      expect(failure.kind, SshRuntimeFailureKind.timedOut);
      expect(failure.message, contains('timed out'));
    });

    test('maps process exception to unavailable failure', () {
      final failure = mapper.map(
        host,
        const ProcessException('ssh', <String>[], 'No such file or directory'),
      );

      expect(failure.kind, SshRuntimeFailureKind.unavailable);
      expect(failure.message, contains('provider unavailable'));
    });

    test('maps generic error to command failure', () {
      final failure = mapper.map(host, Exception('boom'));

      expect(failure.kind, SshRuntimeFailureKind.commandFailed);
      expect(failure.message, contains('boom'));
    });
  });
}
