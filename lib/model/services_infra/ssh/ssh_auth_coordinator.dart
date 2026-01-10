/// Coordinates SSH authentication prompts so UI code can centralize decrypt and
/// passphrase handling while services retry internally.
class SshAuthCoordinator {
  const SshAuthCoordinator({this.onDecryptKey, this.onRequestPassphrase});

  final Future<SshKeyDecryptResult?> Function(SshKeyDecryptRequest request)?
  onDecryptKey;
  final Future<String?> Function(SshPassphraseRequest request)?
  onRequestPassphrase;

  SshAuthCoordinator withDecryptFallback(
    Future<bool> Function(String keyId, String hostName, String? keyLabel)
    promptDecrypt,
  ) {
    if (onDecryptKey != null) {
      return this;
    }
    return SshAuthCoordinator(
      onDecryptKey: (request) async {
        final decrypted = await promptDecrypt(
          request.keyId,
          request.hostName,
          request.keyLabel,
        );
        return SshKeyDecryptResult(decrypted: decrypted);
      },
      onRequestPassphrase: onRequestPassphrase,
    );
  }
}

class SshKeyDecryptRequest {
  const SshKeyDecryptRequest({
    required this.keyId,
    required this.hostName,
    this.keyLabel,
    this.storageEncrypted = false,
  });

  final String keyId;
  final String hostName;
  final String? keyLabel;
  final bool storageEncrypted;
}

class SshKeyDecryptResult {
  const SshKeyDecryptResult({required this.decrypted, this.password});

  final bool decrypted;
  final String? password;
}

enum SshPassphraseKind { identityFile, builtInKey }

class SshPassphraseRequest {
  const SshPassphraseRequest({
    required this.hostName,
    required this.kind,
    required this.targetLabel,
  });

  final String hostName;
  final SshPassphraseKind kind;
  final String targetLabel;
}
