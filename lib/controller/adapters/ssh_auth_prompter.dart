import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_auth_coordinator.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';

/// UI helpers that adapt decrypt/passphrase prompts into an [SshAuthCoordinator]
/// so backend services can handle retries without leaking implementation
/// details to callers.
class SshAuthPrompter {
  static SshAuthCoordinator forContext({
    required BuildContext context,
    required BuiltInSshKeyService keyService,
  }) {
    return SshAuthCoordinator(
      onDecryptKey: (request) => _promptDecrypt(context, keyService, request),
      onRequestPassphrase: (request) => _promptPassphrase(context, request),
    );
  }

  static Future<SshKeyDecryptResult?> _promptDecrypt(
    BuildContext context,
    BuiltInSshKeyService keyService,
    SshKeyDecryptRequest request,
  ) async {
    final initial = await keyService.decrypt(request.keyId, password: null);
    if (initial.isDecrypted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key decrypted for this session.')),
        );
      }
      return const SshKeyDecryptResult(decrypted: true);
    }
    if (!context.mounted) return const SshKeyDecryptResult(decrypted: false);
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _SshDecryptDialog(keyService: keyService, request: request),
    );
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key decrypted for this session.')),
      );
    }
    return SshKeyDecryptResult(decrypted: success == true);
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

class _SshDecryptDialog extends StatelessWidget {
  const _SshDecryptDialog({required this.keyService, required this.request});

  final BuiltInSshKeyService keyService;
  final SshKeyDecryptRequest request;

  @override
  Widget build(BuildContext context) {
    final keyName = request.keyLabel ?? 'Key';
    return _SshAuthDialog<bool>(
      headerText: 'Internal key: $keyName',
      hostName: request.hostName,
      detailText: 'Decrypt the key for this session.',
      fieldLabel: 'Password',
      requiredText: 'Password is required',
      infoText:
          'Provide the storage password to decrypt this key for this session.',
      cancelValue: false,
      onSubmit: (password) async {
        try {
          final result = await keyService.decrypt(
            request.keyId,
            password: password,
          );
          if (result.isDecrypted) {
            return const _SshAuthDialogResult.success(true);
          }
          if (result.status == BuiltInSshKeyDecryptStatus.incorrectPassword) {
            return const _SshAuthDialogResult.error(
              'Incorrect password. Please try again.',
            );
          }
          return _SshAuthDialogResult.error(
            result.message ?? 'Failed to decrypt.',
          );
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to decrypt key via UI prompt',
            tag: 'SSH',
            error: error,
            stackTrace: stackTrace,
          );
          return _SshAuthDialogResult.error('Failed to decrypt: $error');
        }
      },
    );
  }
}

class _SshPassphraseDialog extends StatelessWidget {
  const _SshPassphraseDialog({required this.request});

  final SshPassphraseRequest request;

  @override
  Widget build(BuildContext context) {
    final isExternal = request.kind == SshPassphraseKind.identityFile;
    final keyScope = isExternal ? 'External' : 'Internal';
    return _SshAuthDialog<String>(
      headerText: '$keyScope key: ${request.targetLabel}',
      hostName: request.hostName,
      targetLabel: request.targetLabel,
      fieldLabel: 'Passphrase',
      requiredText: 'Passphrase is required',
      infoText: isExternal
          ? 'Enter the passphrase for the external identity file.'
          : 'Enter the passphrase to decrypt the stored key.',
      onSubmit: (value) async => _SshAuthDialogResult.success(value),
    );
  }
}

class _SshAuthDialogResult<T> {
  const _SshAuthDialogResult.success(this.value)
    : errorMessage = null,
      closeDialog = true;
  const _SshAuthDialogResult.error(this.errorMessage)
    : value = null,
      closeDialog = false;

  final T? value;
  final String? errorMessage;
  final bool closeDialog;
}

class _SshAuthDialog<T> extends StatefulWidget {
  const _SshAuthDialog({
    required this.headerText,
    required this.hostName,
    required this.fieldLabel,
    required this.requiredText,
    required this.infoText,
    required this.onSubmit,
    this.targetLabel,
    this.detailText,
    this.cancelValue,
  });

  final String headerText;
  final String hostName;
  final String fieldLabel;
  final String requiredText;
  final String infoText;
  final String? targetLabel;
  final String? detailText;
  final T? cancelValue;
  final Future<_SshAuthDialogResult<T>> Function(String) onSubmit;

  @override
  State<_SshAuthDialog<T>> createState() => _SshAuthDialogState<T>();
}

class _SshAuthDialogState<T> extends State<_SshAuthDialog<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorText;
  bool _loading = false;
  bool _obscureText = true;
  bool _hasFocus = true;
  bool _hasText = false;
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  bool _isTogglingObscure = false;

  @override
  void initState() {
    super.initState();
    _hasFocus = _focusNode.hasFocus;
    _hasText = _controller.text.trim().isNotEmpty;
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleEditingChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleEditingChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_hasFocus == _focusNode.hasFocus) return;
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _handleEditingChange() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
    if (_isTogglingObscure) return;
    final selection = _controller.selection;
    if (selection.isValid) {
      _lastSelection = selection;
    }
  }

  void _toggleObscure() {
    _isTogglingObscure = true;
    final selection = _controller.selection;
    setState(() => _obscureText = !_obscureText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      if (selection.isValid && selection.baseOffset >= 0) {
        _controller.selection = selection;
        _lastSelection = selection;
      } else {
        final fallback = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        _controller.selection = fallback;
        _lastSelection = fallback;
      }
      _isTogglingObscure = false;
    });
  }

  void _handleCancel() {
    Navigator.of(context).pop(widget.cancelValue);
  }

  Future<void> _submit() async {
    if (_loading) return;
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _errorText = widget.requiredText);
      return;
    }
    setState(() {
      _loading = true;
      _errorText = null;
    });
    final result = await widget.onSubmit(value);
    if (!mounted) return;
    if (result.closeDialog) {
      Navigator.of(context).pop(result.value);
      return;
    }
    setState(() {
      _loading = false;
      _errorText = result.errorMessage ?? widget.requiredText;
    });
  }

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About this prompt'),
        content: Text(widget.infoText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final textTheme = Theme.of(context).textTheme;
    final headerBackground = context.appTheme.section.toolbarBackground;
    final inputBorder =
        Theme.of(context).inputDecorationTheme.enabledBorder ??
        const OutlineInputBorder();
    ButtonStyle iconButtonStyle(Color hoverColor) {
      return ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.white.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverColor;
          }
          return Colors.white;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return hoverColor.withValues(alpha: 0.12);
          }
          return Colors.white.withValues(alpha: 0.06);
        }),
      );
    }

    return DialogKeyboardShortcuts(
      onCancel: _loading ? null : _handleCancel,
      onConfirm: _loading ? null : _submit,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: context.appTheme.section.cardRadius,
          side: inputBorder.borderSide,
        ),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.base * 3,
            vertical: spacing.base * 2,
          ),
          decoration: BoxDecoration(
            color: headerBackground,
            borderRadius: BorderRadius.vertical(
              top: context.appTheme.section.cardRadius.topLeft,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.headerText,
                  style: textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Info',
                visualDensity: VisualDensity.compact,
                style: iconButtonStyle(Theme.of(context).colorScheme.primary),
                onPressed: _loading ? null : _showInfo,
                icon: const Icon(Icons.info_outline, size: 18),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                style: iconButtonStyle(Theme.of(context).colorScheme.error),
                onPressed: _loading ? null : _handleCancel,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          spacing.base * 4,
          spacing.base * 3,
          spacing.base * 4,
          spacing.base * 4,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Host 󰁔 ', style: textTheme.labelMedium),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      widget.hostName,
                      style: textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (widget.targetLabel != null) ...[
                SizedBox(height: spacing.sm),
                Text(widget.targetLabel!, style: textTheme.bodySmall),
              ],
              if (widget.detailText != null) ...[
                SizedBox(height: spacing.sm),
                Text(widget.detailText!, style: textTheme.bodySmall),
              ],
              SizedBox(height: spacing.lg),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                obscureText: _obscureText,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: widget.fieldLabel,
                  errorText: _errorText,
                  prefixIcon: null,
                  suffixIcon: (_hasFocus || _hasText)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _obscureText ? 'Show' : 'Hide',
                              style: iconButtonStyle(
                                Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _loading ? null : _toggleObscure,
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 18,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.35),
                            ),
                            IconButton(
                              tooltip: 'Submit',
                              style: iconButtonStyle(
                                Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _loading ? null : _submit,
                              icon: const Icon(Icons.arrow_forward, size: 18),
                            ),
                          ],
                        )
                      : null,
                ),
                enabled: !_loading,
                onChanged: (value) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                onSubmitted: (_) {
                  if (_loading) return;
                  _submit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
