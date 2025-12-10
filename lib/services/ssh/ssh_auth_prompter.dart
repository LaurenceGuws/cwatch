import 'package:flutter/material.dart';

import 'builtin/builtin_ssh_key_service.dart';
import 'ssh_auth_coordinator.dart';

/// UI helpers that adapt unlock/passphrase prompts into an [SshAuthCoordinator]
/// so backend services can handle retries without leaking implementation
/// details to callers.
class SshAuthPrompter {
  static SshAuthCoordinator forContext({
    required BuildContext context,
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthCoordinator(
      onUnlockKey: (request) =>
          _promptUnlock(context, keyService, request),
      onRequestPassphrase: (request) =>
          _promptPassphrase(context, request),
    );
  }

  static Future<SshKeyUnlockResult?> _promptUnlock(
    BuildContext context,
    BuiltInSshKeyService keyService,
    SshKeyUnlockRequest request,
  ) async {
    final initial = await keyService.unlock(request.keyId, password: null);
    if (initial.isUnlocked) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unlocked key for this session.')),
        );
      }
      return const SshKeyUnlockResult(unlocked: true);
    }
    if (!context.mounted) return const SshKeyUnlockResult(unlocked: false);

    final controller = TextEditingController();
    String? errorText;
    bool loading = false;
    final success = await showDialog<bool>(
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
                final result = await keyService.unlock(
                  request.keyId,
                  password: password,
                );
                if (result.isUnlocked) {
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Key unlocked for this session.'),
                    ),
                  );
                } else if (result.status ==
                    BuiltInSshKeyUnlockStatus.incorrectPassword) {
                  setState(() {
                    errorText = 'Incorrect password. Please try again.';
                    loading = false;
                  });
                } else {
                  setState(() {
                    errorText = result.message ?? 'Failed to unlock.';
                    loading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  errorText = 'Failed to unlock: $e';
                  loading = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Unlock ${request.keyLabel ?? 'key'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Host: ${request.hostName}'),
                  if (request.storageEncrypted) ...[
                    const SizedBox(height: 6),
                    const Text('Storage password required.'),
                  ],
                  const SizedBox(height: 8),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
    _disposeControllerAfterFrame(controller);
    return SshKeyUnlockResult(unlocked: success == true);
  }

  static Future<String?> _promptPassphrase(
    BuildContext context,
    SshPassphraseRequest request,
  ) async {
    if (!context.mounted) return null;
    final controller = TextEditingController();
    String? errorText;
    bool loading = false;
    final passphrase = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              if (loading) return;
              final value = controller.text.trim();
              if (value.isEmpty) {
                setState(() => errorText = 'Passphrase is required');
                return;
              }
              setState(() {
                loading = true;
                errorText = null;
              });
              Navigator.of(dialogContext).pop(value);
            }

            return AlertDialog(
              title: Text(
                request.kind == SshPassphraseKind.identityFile
                    ? 'Identity passphrase required'
                    : 'Key passphrase required',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Host: ${request.hostName}'),
                  const SizedBox(height: 8),
                  Text(request.targetLabel),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Passphrase'),
                    enabled: !loading,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : submit,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeControllerAfterFrame(controller);
    return passphrase;
  }

  static void _disposeControllerAfterFrame(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}
