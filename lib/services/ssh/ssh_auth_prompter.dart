import 'package:flutter/material.dart';

import 'builtin/builtin_ssh_key_service.dart';
import 'ssh_auth_coordinator.dart';
import '../../shared/theme/app_theme.dart';

/// UI helpers that adapt unlock/passphrase prompts into an [SshAuthCoordinator]
/// so backend services can handle retries without leaking implementation
/// details to callers.
class SshAuthPrompter {
  static SshAuthCoordinator forContext({
    required BuildContext context,
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthCoordinator(
      onUnlockKey: (request) => _promptUnlock(context, keyService, request),
      onRequestPassphrase: (request) => _promptPassphrase(context, request),
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
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SshUnlockDialog(
        keyService: keyService,
        request: request,
      ),
    );
    return SshKeyUnlockResult(unlocked: success == true);
  }

  static Future<String?> _promptPassphrase(
    BuildContext context,
    SshPassphraseRequest request,
  ) async {
    if (!context.mounted) return null;
    final passphrase = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SshPassphraseDialog(request: request),
    );
    return passphrase;
  }
}

class _SshUnlockDialog extends StatefulWidget {
  const _SshUnlockDialog({
    required this.keyService,
    required this.request,
  });

  final BuiltInSshKeyService keyService;
  final SshKeyUnlockRequest request;

  @override
  State<_SshUnlockDialog> createState() => _SshUnlockDialogState();
}

class _SshUnlockDialogState extends State<_SshUnlockDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _attemptUnlock() async {
    if (_loading) return;
    final password = _controller.text.trim();
    if (password.isEmpty) {
      setState(() => _errorText = 'Password is required');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final result = await widget.keyService.unlock(
        widget.request.keyId,
        password: password,
      );
      if (!mounted) return;
      if (result.isUnlocked) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
      } else if (result.status ==
          BuiltInSshKeyUnlockStatus.incorrectPassword) {
        setState(() {
          _errorText = 'Incorrect password. Please try again.';
          _loading = false;
        });
      } else {
        setState(() {
          _errorText = result.message ?? 'Failed to unlock.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to unlock: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return AlertDialog(
      title: Text('Unlock ${widget.request.keyLabel ?? 'key'}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Host: ${widget.request.hostName}'),
          if (widget.request.storageEncrypted) ...[
            SizedBox(height: spacing.base * 1.5),
            const Text('Storage password required.'),
          ],
          SizedBox(height: spacing.md),
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            enabled: !_loading,
          ),
          if (_errorText != null) ...[
            SizedBox(height: spacing.md),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _attemptUnlock,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}

class _SshPassphraseDialog extends StatefulWidget {
  const _SshPassphraseDialog({required this.request});

  final SshPassphraseRequest request;

  @override
  State<_SshPassphraseDialog> createState() => _SshPassphraseDialogState();
}

class _SshPassphraseDialogState extends State<_SshPassphraseDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_loading) return;
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = 'Passphrase is required');
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return AlertDialog(
      title: Text(
        widget.request.kind == SshPassphraseKind.identityFile
            ? 'Identity passphrase required'
            : 'Key passphrase required',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Host: ${widget.request.hostName}'),
          SizedBox(height: spacing.md),
          Text(widget.request.targetLabel),
          SizedBox(height: spacing.md),
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
            enabled: !_loading,
          ),
          if (_errorText != null) ...[
            SizedBox(height: spacing.md),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
