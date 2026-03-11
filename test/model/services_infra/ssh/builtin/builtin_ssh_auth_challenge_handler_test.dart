import 'package:dartssh2/dartssh2.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_auth_challenge_handler.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_exceptions.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';

class _FakeVault implements BuiltInSshVault {
  final Set<String> decrypted = {};
  final Set<String> encrypted = {};
  final List<(String, String)> decryptCalls = [];

  @override
  bool isDecrypted(String keyId) => decrypted.contains(keyId);

  @override
  Future<bool> isEncrypted(String keyId) async => encrypted.contains(keyId);

  @override
  Future<void> decrypt(String keyId, String? password) async {
    decryptCalls.add((keyId, password ?? ''));
    decrypted.add(keyId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('dedupes concurrent decrypt requests for same key', () async {
    final vault = _FakeVault()..encrypted.add('k1');
    var calls = 0;
    final completer = Completer<SshKeyDecryptResult?>();
    final handler = BuiltInSshAuthChallengeHandler(
      vault: vault,
      authCoordinator: SshAuthCoordinator(
        onDecryptKey: (_) {
          calls++;
          return completer.future;
        },
      ),
      setBuiltInKeyPassphrase: (keyId, passphrase) {},
      setIdentityPassphrase: (identityPath, passphrase) {},
    );
    final error = BuiltInSshKeyDecryptionRequired('host', 'k1', 'label');

    final f1 = handler.handleDecryptRequired(error);
    final f2 = handler.handleDecryptRequired(error);
    completer.complete(const SshKeyDecryptResult(decrypted: true, password: 'pw'));

    expect(await f1, true);
    expect(await f2, true);
    expect(calls, 1);
    expect(vault.decryptCalls, [('k1', 'pw')]);
  });

  test('built in passphrase stores provided passphrase', () async {
    String? storedKey;
    String? storedPassphrase;
    final handler = BuiltInSshAuthChallengeHandler(
      vault: _FakeVault(),
      authCoordinator: const SshAuthCoordinator(
        onRequestPassphrase: _provideBuiltInPassphrase,
      ),
      setBuiltInKeyPassphrase: (keyId, passphrase) {
        storedKey = keyId;
        storedPassphrase = passphrase;
      },
      setIdentityPassphrase: (identityPath, passphrase) {},
    );

    final result = await handler.handleBuiltInPassphrase(
      BuiltInSshKeyPassphraseRequired(
        hostName: 'host',
        keyId: 'k1',
        keyLabel: 'main',
        error: SSHKeyDecryptError('test'),
      ),
    );

    expect(result, true);
    expect(storedKey, 'k1');
    expect(storedPassphrase, 'secret');
  });

  test('identity passphrase stores provided passphrase', () async {
    String? storedPath;
    String? storedPassphrase;
    final handler = BuiltInSshAuthChallengeHandler(
      vault: _FakeVault(),
      authCoordinator: const SshAuthCoordinator(
        onRequestPassphrase: _provideBuiltInPassphrase,
      ),
      setBuiltInKeyPassphrase: (keyId, passphrase) {},
      setIdentityPassphrase: (path, passphrase) {
        storedPath = path;
        storedPassphrase = passphrase;
      },
    );

    final result = await handler.handleIdentityPassphrase(
      BuiltInSshIdentityPassphraseRequired(
        hostName: 'host',
        identityPath: '/id_rsa',
        error: SSHKeyDecryptError('test'),
      ),
    );

    expect(result, true);
    expect(storedPath, '/id_rsa');
    expect(storedPassphrase, 'secret');
  });
}

Future<String?> _provideBuiltInPassphrase(SshPassphraseRequest request) async {
  return 'secret';
}

