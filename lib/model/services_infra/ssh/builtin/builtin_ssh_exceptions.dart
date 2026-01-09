import 'package:dartssh2/dartssh2.dart';

class BuiltInSshKeyLockedException implements Exception {
  BuiltInSshKeyLockedException(this.hostName, this.keyId, [this.keyLabel]);

  final String hostName;
  final String keyId;
  final String? keyLabel;
}

class BuiltInSshKeyPassphraseRequired implements Exception {
  const BuiltInSshKeyPassphraseRequired({
    required this.hostName,
    required this.keyId,
    this.keyLabel,
    required this.error,
  });

  final String hostName;
  final String keyId;
  final String? keyLabel;
  final SSHKeyDecryptError error;
}

class BuiltInSshKeyUnsupportedCipher implements Exception {
  const BuiltInSshKeyUnsupportedCipher({
    required this.hostName,
    required this.keyId,
    this.keyLabel,
    required this.error,
  });

  final String hostName;
  final String keyId;
  final String? keyLabel;
  final UnsupportedError error;
}

class BuiltInSshIdentityPassphraseRequired implements Exception {
  const BuiltInSshIdentityPassphraseRequired({
    required this.hostName,
    required this.identityPath,
    required this.error,
  });

  final String hostName;
  final String identityPath;
  final SSHKeyDecryptError error;
}

class BuiltInSshAuthenticationFailed implements Exception {
  const BuiltInSshAuthenticationFailed({
    required this.hostName,
    required this.message,
  });

  final String hostName;
  final String message;

  @override
  String toString() => 'SSH authentication failed for $hostName: $message';
}
