import '../ssh_auth_coordinator.dart';
import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_vault.dart';

typedef BuiltInSshSetBuiltInKeyPassphrase = void Function(
  String keyId,
  String passphrase,
);
typedef BuiltInSshSetIdentityPassphrase = void Function(
  String identityPath,
  String passphrase,
);

class BuiltInSshAuthChallengeHandler {
  BuiltInSshAuthChallengeHandler({
    required this.vault,
    required this.authCoordinator,
    required this.setBuiltInKeyPassphrase,
    required this.setIdentityPassphrase,
  });

  final BuiltInSshVault vault;
  final SshAuthCoordinator authCoordinator;
  final BuiltInSshSetBuiltInKeyPassphrase setBuiltInKeyPassphrase;
  final BuiltInSshSetIdentityPassphrase setIdentityPassphrase;

  final Map<String, Future<bool>> _pendingDecryptRequests = {};

  Future<bool> handleDecryptRequired(
    BuiltInSshKeyDecryptionRequired error,
  ) async {
    if (vault.isDecrypted(error.keyId)) {
      return true;
    }
    final pending = _pendingDecryptRequests[error.keyId];
    if (pending != null) {
      return pending;
    }
    final future = () async {
      final request = SshKeyDecryptRequest(
        keyId: error.keyId,
        hostName: error.hostName,
        keyLabel: error.keyLabel,
        storageEncrypted: await vault.isEncrypted(error.keyId),
      );
      final result = await authCoordinator.onDecryptKey?.call(request);
      if (result == null || result.decrypted != true) {
        return false;
      }
      if (!vault.isDecrypted(error.keyId) && result.password != null) {
        try {
          await vault.decrypt(error.keyId, result.password);
        } catch (e) {
          logBuiltInSshWarning(
            'Failed to decrypt built-in key ${error.keyId}',
            error: e,
          );
          return false;
        }
      }
      return vault.isDecrypted(error.keyId);
    }();
    _pendingDecryptRequests[error.keyId] = future;
    try {
      return await future;
    } finally {
      _pendingDecryptRequests.remove(error.keyId);
    }
  }

  Future<bool> handleBuiltInPassphrase(
    BuiltInSshKeyPassphraseRequired error,
  ) async {
    final passphrase = await authCoordinator.onRequestPassphrase?.call(
      SshPassphraseRequest(
        hostName: error.hostName,
        kind: SshPassphraseKind.builtInKey,
        targetLabel: error.keyLabel ?? error.keyId,
      ),
    );
    if (passphrase == null || passphrase.isEmpty) {
      return false;
    }
    setBuiltInKeyPassphrase(error.keyId, passphrase);
    return true;
  }

  Future<bool> handleIdentityPassphrase(
    BuiltInSshIdentityPassphraseRequired error,
  ) async {
    final passphrase = await authCoordinator.onRequestPassphrase?.call(
      SshPassphraseRequest(
        hostName: error.hostName,
        kind: SshPassphraseKind.identityFile,
        targetLabel: error.identityPath,
      ),
    );
    if (passphrase == null || passphrase.isEmpty) {
      return false;
    }
    setIdentityPassphrase(error.identityPath, passphrase);
    return true;
  }
}
