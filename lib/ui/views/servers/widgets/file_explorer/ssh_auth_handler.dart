import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/logging/app_logger.dart';
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
  bool _disposed = false;
  static const SshUnlockCancelled _unlockCancelled = SshUnlockCancelled();

  /// Execute a shell action with automatic SSH authentication handling
  Future<T> runShell<T>(Future<T> Function() action) async {
    if (_disposed) {
      throw StateError('SshAuthHandler used after dispose');
    }
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
        final displayName = (error.keyLabel?.trim().isNotEmpty ?? false)
            ? error.keyLabel!.trim()
            : await _keyDisplayName(error.keyId);
        final unlocked = await promptUnlock(error.keyId, displayName);
        if (!unlocked) {
          throw _unlockCancelled;
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

  void dispose() {
    _disposed = true;
    _pendingPassphrasePrompts.clear();
  }

  Future<bool> promptUnlock(String keyId, [String? displayName]) async {
    if (_unlockInProgress) {
      return false;
    }
    if (_disposed || !context.mounted) {
      return false;
    }
    final vault = builtInVault;
    if (vault == null) {
      return false;
    }
    _unlockInProgress = true;
    AppLogger.d('Prompting unlock for key $keyId', tag: 'Explorer');
    try {
      // Check if password is needed
      final needsPwd = await vault.needsPassword(keyId);
      if (needsPwd) {
        final unlocked = await _showUnlockDialog(
          keyId,
          displayName ?? await _keyDisplayName(keyId),
        );
        return unlocked;
      }
      await vault.unlock(keyId, null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
        AppLogger.d('Unlock succeeded for key $keyId', tag: 'Explorer');
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
      }
      AppLogger.w(
        'Unlock failed for key $keyId',
        tag: 'Explorer',
        error: error,
      );
      return false;
    } finally {
      _unlockInProgress = false;
      AppLogger.d('Unlock flow completed for key $keyId', tag: 'Explorer');
    }
  }

  Future<bool> _showUnlockDialog(String keyId, String displayName) async {
    if (_disposed || !context.mounted) {
      return false;
    }
    final controller = TextEditingController();
    String? errorText;
    bool loading = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> attemptUnlock() async {
              if (loading) return;
              final password = controller.text.trim();
              if (password.isEmpty) {
                setState(() => errorText = 'Password is required');
                return;
              }
              setState(() {
                loading = true;
                errorText = null;
              });
              try {
                await builtInVault?.unlock(keyId, password);
                if (!_disposed &&
                    dialogContext.mounted &&
                    Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on BuiltInSshKeyDecryptException {
                setState(() {
                  errorText = 'Incorrect password. Please try again.';
                  loading = false;
                });
              } catch (e) {
                setState(() {
                  errorText = 'Failed to unlock: $e';
                  loading = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Unlock $displayName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    enabled: !loading,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : attemptUnlock,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true && !_disposed && context.mounted;
  }

  Future<String> _keyDisplayName(String keyId) async {
    final entry = await builtInVault!.keyStore.loadEntry(keyId);
    if (entry != null) {
      final label = entry.label.trim();
      if (label.isNotEmpty) {
        return label;
      }
    }
    return 'Key ${_shortKeyId(keyId)}';
  }

  String _shortKeyId(String keyId) {
    if (keyId.length <= 8) return keyId;
    return '${keyId.substring(0, 8)}…${keyId.substring(keyId.length - 4)}';
  }
  Future<String?> awaitPassphraseInput(String host, String path) async {
    final key = '$host|$path';
    final existing = _pendingPassphrasePrompts[key];
    if (existing != null) {
      AppLogger.d('Awaiting existing passphrase for $key', tag: 'Explorer');
      return existing;
    }
    if (_disposed) {
      return null;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        AppLogger.d('Prompting passphrase for $key', tag: 'Explorer');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        AppLogger.d('Passphrase prompt completed for $key', tag: 'Explorer');
      }
    }();
    return completer.future;
  }

  Future<String?> _promptPassphrase(String host, String path) async {
    if (_disposed || !context.mounted) {
      return null;
    }
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
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    if (_disposed || !context.mounted) {
      return null;
    }
    return result?.isNotEmpty == true ? result : null;
  }

  /// Thrown when a user cancels an unlock prompt.
}

class SshUnlockCancelled implements Exception {
  const SshUnlockCancelled();

  @override
  String toString() => 'SshUnlockCancelled';
}
