/// Coordinates SSH authentication prompts so UI code can centralize unlock and
/// passphrase handling while services retry internally.
class SshAuthCoordinator {
  const SshAuthCoordinator({
    this.onUnlockKey,
    this.onRequestPassphrase,
  });

  final Future<SshKeyUnlockResult?> Function(SshKeyUnlockRequest request)?
      onUnlockKey;
  final Future<String?> Function(SshPassphraseRequest request)?
      onRequestPassphrase;

  SshAuthCoordinator withUnlockFallback(
    Future<bool> Function(String keyId, String hostName, String? keyLabel)
        promptUnlock,
  ) {
    if (onUnlockKey != null) {
      return this;
    }
    return SshAuthCoordinator(
      onUnlockKey: (request) async {
        final unlocked = await promptUnlock(
          request.keyId,
          request.hostName,
          request.keyLabel,
        );
        return SshKeyUnlockResult(unlocked: unlocked);
      },
      onRequestPassphrase: onRequestPassphrase,
    );
  }
}

class SshKeyUnlockRequest {
  const SshKeyUnlockRequest({
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

class SshKeyUnlockResult {
  const SshKeyUnlockResult({
    required this.unlocked,
    this.password,
  });

  final bool unlocked;
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
