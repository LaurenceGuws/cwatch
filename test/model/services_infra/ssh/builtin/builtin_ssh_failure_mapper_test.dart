import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_exceptions.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_failure_mapper.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_runtime_failure.dart';

void main() {
  group('BuiltInSshFailureMapper', () {
    const mapper = BuiltInSshFailureMapper();
    const host = SshHost(
      name: 'example',
      hostname: 'example.local',
      port: 22,
      available: true,
    );

    test('maps built-in authentication failure to shared auth failure', () {
      final failure = mapper.map(
        host,
        const BuiltInSshAuthenticationFailed(
          hostName: 'example',
          message: 'Permission denied',
        ),
      );

      expect(failure.kind, SshRuntimeFailureKind.authenticationFailed);
      expect(failure.message, contains('SSH authentication failed'));
    });

    test('maps timeout to shared timeout failure', () {
      final failure = mapper.map(
        host,
        TimeoutException('SSH command timed out after 10s'),
      );

      expect(failure.kind, SshRuntimeFailureKind.timedOut);
      expect(failure.message, contains('timed out'));
    });

    test('maps missing identity to unavailable failure', () {
      final failure = mapper.map(
        host,
        Exception('No SSH identity available for example'),
      );

      expect(failure.kind, SshRuntimeFailureKind.unavailable);
      expect(failure.message, contains('provider unavailable'));
    });

    test('maps generic builtin error to command failure', () {
      final failure = mapper.map(host, Exception('boom'));

      expect(failure.kind, SshRuntimeFailureKind.commandFailed);
      expect(failure.message, contains('boom'));
    });
  });
}
