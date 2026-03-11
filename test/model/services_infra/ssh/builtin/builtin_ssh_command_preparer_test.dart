import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_base.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_identity_manager.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_command_preparer.dart';

class _FakeIdentityManager implements BuiltInSshIdentityManager {
  int ensureCalls = 0;

  @override
  Future<void> ensureDecrypted(SshHost host) async {
    ensureCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const host = SshHost(name: 'h', hostname: '127.0.0.1', port: 22, available: true);

  test('prependNoHistory prefixes shell history guard', () {
    final preparer = BuiltInSshCommandPreparer(
      identityManager: _FakeIdentityManager(),
      isNoShellHost: (_) => false,
      wrapSshErrors: (host, action) => action(),
    );

    expect(
      preparer.prependNoHistory('ls'),
      'HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0; ls',
    );
  });

  test('prepareCommand ensures decrypt before returning safe command', () async {
    final manager = _FakeIdentityManager();
    final preparer = BuiltInSshCommandPreparer(
      identityManager: manager,
      isNoShellHost: (_) => false,
      wrapSshErrors: (host, action) => action(),
    );

    final safeCommand = await preparer.prepareCommand(host, 'pwd');

    expect(manager.ensureCalls, 1);
    expect(safeCommand, contains('pwd'));
  });

  test('prepareCommand rejects no-shell hosts', () async {
    final preparer = BuiltInSshCommandPreparer(
      identityManager: _FakeIdentityManager(),
      isNoShellHost: (_) => true,
      wrapSshErrors: (host, action) => action(),
    );

    expect(
      () => preparer.prepareCommand(host, 'pwd'),
      throwsA(isA<NoShellHostException>()),
    );
  });
}
