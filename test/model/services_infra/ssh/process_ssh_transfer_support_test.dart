import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/process_ssh_transfer_support.dart';

void main() {
  const support = ProcessSshTransferSupport();

  group('ProcessSshTransferSupport', () {
    test('buildScpArgs adds port, recursion, flags, and non-empty identities', () {
      final args = support.buildScpArgs(
        identityFiles: {'/tmp/id_a', ' ', '/tmp/id_b'},
        remotePort: 2222,
        recursive: true,
        extraFlags: const ['-3'],
      );

      expect(args, [
        'scp',
        '-o',
        'BatchMode=yes',
        '-o',
        'StrictHostKeyChecking=accept-new',
        '-3',
        '-P',
        '2222',
        '-r',
        '-i',
        '/tmp/id_a',
        '-i',
        '/tmp/id_b',
      ]);
    });

    test('formatRemoteSpec uses provided connection target and raw remote path', () {
      final spec = support.formatRemoteSpec(
        const SshHost(
          name: 'alpha',
          hostname: 'alpha.example',
          port: 22,
          available: true,
          user: 'dev',
        ),
        '/tmp/../var/log',
        connectionTarget: 'dev@alpha.example',
      );

      expect(spec, 'dev@alpha.example:/tmp/../var/log');
    });

    test('formatRemoteSpec falls back to host user/hostname when target omitted', () {
      final spec = support.formatRemoteSpec(
        const SshHost(
          name: 'beta',
          hostname: 'beta.example',
          port: 22,
          available: true,
          user: 'ops',
        ),
        '/srv/app',
      );

      expect(spec, 'ops@beta.example:/srv/app');
    });
  });
}
