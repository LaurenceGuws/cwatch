import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_auth_challenge_handler.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_exceptions.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_failure_mapper.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_retry_handler.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_vault.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_runtime_failure.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVault implements BuiltInSshVault {
  @override
  bool isDecrypted(String keyId) => false;

  @override
  Future<bool> isEncrypted(String keyId) async => true;

  @override
  Future<void> decrypt(String keyId, String? password) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const host = SshHost(
    name: 'example',
    hostname: 'example.local',
    port: 22,
    available: true,
  );

  BuiltInSshRetryHandler createHandler({
    Future<bool> Function(BuiltInSshKeyDecryptionRequired error)? onDecrypt,
    Future<bool> Function(BuiltInSshKeyPassphraseRequired error)? onBuiltInPass,
    Future<bool> Function(BuiltInSshIdentityPassphraseRequired error)?
        onIdentityPass,
  }) {
    final authHandler = _StubBuiltInSshAuthChallengeHandler(
      onDecrypt: onDecrypt,
      onBuiltInPass: onBuiltInPass,
      onIdentityPass: onIdentityPass,
    );
    return BuiltInSshRetryHandler(
      failureMapper: const BuiltInSshFailureMapper(),
      authChallengeHandler: authHandler,
    );
  }

  test('retries after decrypt requirement when challenge succeeds', () async {
    var attempts = 0;
    final handler = createHandler(onDecrypt: (_) async => true);

    final result = await handler.run<String>(host, () async {
      attempts++;
      if (attempts == 1) {
        throw BuiltInSshKeyDecryptionRequired('example', 'key-1');
      }
      return 'ok';
    });

    expect(result, 'ok');
    expect(attempts, 2);
  });

  test('retries after built-in key passphrase requirement when provided', () async {
    var attempts = 0;
    final handler = createHandler(onBuiltInPass: (_) async => true);

    final result = await handler.run<String>(host, () async {
      attempts++;
      if (attempts == 1) {
        throw BuiltInSshKeyPassphraseRequired(
          hostName: 'example',
          keyId: 'key-1',
          error: SSHKeyDecryptError('passphrase'),
        );
      }
      return 'ok';
    });

    expect(result, 'ok');
    expect(attempts, 2);
  });

  test('maps generic error through shared failure mapper', () async {
    final handler = createHandler();

    expect(
      () => handler.run<void>(host, () async => throw Exception('boom')),
      throwsA(
        isA<SshRuntimeFailure>().having(
          (failure) => failure.kind,
          'kind',
          SshRuntimeFailureKind.commandFailed,
        ),
      ),
    );
  });

  test('rethrows unsupported cipher without mapping', () async {
    final handler = createHandler();
    final error = BuiltInSshKeyUnsupportedCipher(
      hostName: 'example',
      keyId: 'key-1',
      error: UnsupportedError('cipher'),
    );

    expect(
      () => handler.run<void>(host, () async => throw error),
      throwsA(same(error)),
    );
  });
}

class _StubBuiltInSshAuthChallengeHandler extends BuiltInSshAuthChallengeHandler {
  _StubBuiltInSshAuthChallengeHandler({
    this.onDecrypt,
    this.onBuiltInPass,
    this.onIdentityPass,
  }) : super(
         vault: _FakeVault(),
         authCoordinator: const SshAuthCoordinator(),
         setBuiltInKeyPassphrase: _noopBuiltInPassphrase,
         setIdentityPassphrase: _noopIdentityPassphrase,
       );

  final Future<bool> Function(BuiltInSshKeyDecryptionRequired error)? onDecrypt;
  final Future<bool> Function(BuiltInSshKeyPassphraseRequired error)?
      onBuiltInPass;
  final Future<bool> Function(BuiltInSshIdentityPassphraseRequired error)?
      onIdentityPass;

  @override
  Future<bool> handleDecryptRequired(
    BuiltInSshKeyDecryptionRequired error,
  ) async {
    return onDecrypt?.call(error) ?? false;
  }

  @override
  Future<bool> handleBuiltInPassphrase(
    BuiltInSshKeyPassphraseRequired error,
  ) async {
    return onBuiltInPass?.call(error) ?? false;
  }

  @override
  Future<bool> handleIdentityPassphrase(
    BuiltInSshIdentityPassphraseRequired error,
  ) async {
    return onIdentityPass?.call(error) ?? false;
  }
}

void _noopBuiltInPassphrase(String keyId, String passphrase) {}

void _noopIdentityPassphrase(String identityPath, String passphrase) {}
