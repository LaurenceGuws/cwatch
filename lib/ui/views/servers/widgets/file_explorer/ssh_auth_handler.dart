import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../../../services/ssh/remote_shell_service.dart';

/// Handler for SSH authentication, unlocking keys, and passphrase prompts
class SshAuthHandler {
  SshAuthHandler({
    required this.shellService,
    required this.builtInVault,
    required this.context,
    this.host,
  });

  final RemoteShellService shellService;
  final BuiltInSshVault? builtInVault;
  final BuildContext context;
  final SshHost? host;

  bool _unlockInProgress = false;
  final Map<String, Future<String?>> _pendingPassphrasePrompts = {};

  /// Execute a shell action with automatic SSH authentication handling
  Future<T> runShell<T>(Future<T> Function() action) async {
    if (shellService is BuiltInRemoteShellService &&
        builtInVault != null &&
        host != null) {
      final service = shellService as BuiltInRemoteShellService;
      final keyId = service.getActiveBuiltInKeyId(host!);
      if (keyId != null && builtInVault!.isUnlocked(keyId)) {
        // Key already unlocked → do not repeat unlock flow.
        return action();
      }
    }
    if (builtInVault == null) {
      return action();
    }
    return _withBuiltinUnlock(action);
  }

  Future<T> _withBuiltinUnlock<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } on BuiltInSshKeyLockedException catch (error) {
        final unlocked = await promptUnlock(error.keyId);
        if (!unlocked) {
          rethrow;
        }
        continue;
      } on BuiltInSshKeyPassphraseRequired catch (error) {
        final keyLabel = error.keyLabel ?? error.keyId;
        final passphrase = await awaitPassphraseInput(
          error.hostName,
          'built-in key $keyLabel',
        );
        if (passphrase == null) {
          if (!context.mounted) {
            rethrow;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passphrase is required to continue.'),
            ),
          );
          rethrow;
        }
        final service = shellService;
        if (service is BuiltInRemoteShellService) {
          service.setBuiltInKeyPassphrase(error.keyId, passphrase);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Passphrase stored for $keyLabel.')),
          );
        }
        continue;
      } on BuiltInSshKeyUnsupportedCipher catch (error) {
        final keyLabel = error.keyLabel ?? error.keyId;
        final detail = error.error.message ?? error.error.toString();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Key $keyLabel uses an unsupported cipher ($detail).',
              ),
            ),
          );
        }
        rethrow;
      } on BuiltInSshIdentityPassphraseRequired catch (error) {
        final passphrase = await awaitPassphraseInput(
          error.hostName,
          error.identityPath,
        );
        if (passphrase == null) {
          if (!context.mounted) {
            rethrow;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passphrase is required to continue.'),
            ),
          );
          rethrow;
        }
        final service = shellService;
        if (service is BuiltInRemoteShellService) {
          service.setIdentityPassphrase(error.identityPath, passphrase);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Passphrase stored for ${error.identityPath}.'),
            ),
          );
        }
        continue;
      } on BuiltInSshAuthenticationFailed catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'SSH authentication failed for ${error.hostName}. '
                'Check your key configuration in settings.',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        rethrow;
      }
    }
  }

  Future<bool> promptUnlock(String keyId) async {
    if (_unlockInProgress) {
      return false;
    }
    final vault = builtInVault;
    if (vault == null) {
      return false;
    }
    _unlockInProgress = true;
    debugPrint('[Explorer] Prompting unlock for key $keyId');
    try {
      // Check if password is needed
      final needsPwd = await vault.needsPassword(keyId);
      String? password;
      if (needsPwd) {
        password = await _showUnlockDialog(keyId);
        if (password == null) {
          debugPrint('[Explorer] Unlock cancelled for key $keyId');
          return false;
        }
      }
      await vault.unlock(keyId, password);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
        debugPrint('[Explorer] Unlock succeeded for key $keyId');
      }
      return true;
    } on BuiltInSshKeyDecryptException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password for that key.')),
        );
      }
      debugPrint('[Explorer] Unlock failed for key $keyId due to bad password');
      return false;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
      }
      debugPrint('[Explorer] Unlock failed for key $keyId. error=$error');
      return false;
    } finally {
      _unlockInProgress = false;
      debugPrint('[Explorer] Unlock flow completed for key $keyId');
    }
  }

  Future<String?> _showUnlockDialog(String keyId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Unlock key $keyId'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }

  Future<String?> awaitPassphraseInput(String host, String path) async {
    final key = '$host|$path';
    final existing = _pendingPassphrasePrompts[key];
    if (existing != null) {
      debugPrint('[Explorer] Awaiting existing passphrase for $key');
      return existing;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        debugPrint('[Explorer] Prompting passphrase for $key');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        debugPrint('[Explorer] Passphrase prompt completed for $key');
      }
    }();
    return completer.future;
  }

  Future<String?> _promptPassphrase(String host, String path) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Passphrase for $host ($path)'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }
}

