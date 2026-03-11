import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_path_support.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';

void main() {
  const support = ProcessSshPathSupport();
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  group('ProcessSshPathSupport', () {
    test('ensureRemoteDirectory skips empty directories', () async {
      var called = false;

      await support.ensureRemoteDirectory(
        host,
        '',
        runHostCommand: (targetHost, command) async {
          called = true;
          return const RunResult(command: 'mkdir', stdout: '', stderr: '');
        },
      );

      expect(called, isFalse);
    });

    test('ensureRemoteDirectory runs mkdir command for non-empty directories', () async {
      final commands = <String>[];

      await support.ensureRemoteDirectory(
        host,
        '/tmp/example',
        runHostCommand: (targetHost, command) async {
          commands.add(command);
          return const RunResult(command: 'mkdir', stdout: '', stderr: '');
        },
      );

      expect(commands, ["mkdir -p '/tmp/example'"]);
    });

    test('verifyPathExists returns null when debug mode is off', () async {
      final result = await support.verifyPathExists(
        host,
        '/tmp/file.txt',
        shouldExist: true,
        debugMode: false,
        runSsh: (targetHost, command) async =>
            throw Exception('should not run'),
      );

      expect(result, isNull);
    });

    test('verifyPathExists shapes exists-check verification when debug mode is on', () async {
      final result = await support.verifyPathExists(
        host,
        '/tmp/file.txt',
        shouldExist: true,
        debugMode: true,
        runSsh: (targetHost, command) async {
          expect(
            command,
            "[ -e '/tmp/file.txt' ] && echo 'EXISTS' || echo 'MISSING'",
          );
          return const RunResult(
            command: 'ssh',
            stdout: 'EXISTS\n',
            stderr: '',
          );
        },
      );

      expect(result, isNotNull);
      final verification = result!;
      expect(verification.command, 'ssh');
      expect(verification.output.trim(), 'EXISTS');
      expect(verification.passed, isTrue);
    });
  });
}
