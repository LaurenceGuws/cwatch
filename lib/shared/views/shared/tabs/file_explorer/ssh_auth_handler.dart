import 'package:flutter/widgets.dart';

import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';

/// Pass-through auth handler now that SSH unlock/passphrase flows are handled
/// by the shared auth coordinator in the SSH services layer.
class SshAuthHandler {
  SshAuthHandler({
    required this.shellService,
    this.context,
    this.host,
  });

  final RemoteShellService shellService;
  final BuildContext? context;
  final SshHost? host;
  bool _disposed = false;

  Future<T> runShell<T>(Future<T> Function() action) async {
    if (_disposed) {
      throw StateError('SshAuthHandler used after dispose');
    }
    return action();
  }

  Future<String?> awaitPassphraseInput(String hostName, String path) async {
    return null;
  }

  Future<String> currentPassphrase(String identityPath) async {
    if (_disposed) {
      return '';
    }
    return '';
  }

  void dispose() {
    _disposed = true;
  }
}

class SshUnlockCancelled implements Exception {
  const SshUnlockCancelled();

  @override
  String toString() => 'SshUnlockCancelled';
}
