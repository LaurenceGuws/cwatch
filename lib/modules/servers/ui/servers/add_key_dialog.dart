import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';

/// Dialog for adding an SSH key
class AddKeyDialog extends StatefulWidget {
  const AddKeyDialog({super.key, required this.keyService});

  final BuiltInSshKeyService keyService;

  @override
  State<AddKeyDialog> createState() => _AddKeyDialogState();
}

class _AddKeyDialogState extends State<AddKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _selectedFilePath;

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem', 'key', 'id_rsa', 'id_ed25519', 'id_ecdsa'],
      dialogTitle: 'Select SSH Private Key',
    );
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final file = File(filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        setState(() {
          _selectedFilePath = filePath;
          _keyController.text = contents;
          if (_labelController.text.isEmpty) {
            // Auto-fill label from filename
            final fileName = filePath.split('/').last;
            _labelController.text = fileName;
          }
        });
      }
    }
  }

  Future<void> _handleAddKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final label = _labelController.text.trim();
    final keyText = _keyController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isSaving = true);
    try {
      // Let the key service own validation and passphrase handling.
      final addResult = await widget.keyService.addKey(
        label: label,
        keyPem: keyText,
        storagePassword: password.isEmpty ? null : password,
        keyPassphrase: null,
      );
      if (addResult.status == BuiltInSshKeyAddStatus.needsPassphrase) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final passphrase = await _promptPassphrase(
          title: 'Key passphrase required',
          helper:
              'This passphrase is used only to validate the key during import.',
        );
        if (passphrase == null || passphrase.isEmpty) {
          return;
        }
        setState(() => _isSaving = true);
        final retry = await widget.keyService.addKey(
          label: label,
          keyPem: keyText,
          storagePassword: password.isEmpty ? null : password,
          keyPassphrase: passphrase,
        );
        if (retry.status != BuiltInSshKeyAddStatus.success) {
          if (!mounted) return;
          final message =
              retry.message ??
              'Unable to import key. Please check the passphrase or format.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pop(retry.entry);
        return;
      } else if (addResult.status != BuiltInSshKeyAddStatus.success) {
        if (!mounted) return;
        final message =
            addResult.message ??
            'Key cannot be parsed. It may be encrypted, unsupported, or malformed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      final entry = addResult.entry;
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to add SSH key from dialog',
        tag: 'Servers',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add key: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return DialogKeyboardShortcuts(
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: _isSaving ? null : _handleAddKey,
      child: AlertDialog(
        title: const Text(
          'Add SSH Key',
          overflow: TextOverflow.visible,
          softWrap: true,
        ),
        contentPadding: EdgeInsets.fromLTRB(
          spacing.base * 6,
          spacing.base * 5,
          spacing.base * 6,
          spacing.base * 6,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(labelText: 'Key label'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Label is required';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    SizedBox(height: spacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _keyController,
                            decoration: InputDecoration(
                              labelText: 'Private key (PEM format)',
                              helperText: _selectedFilePath != null
                                  ? 'Selected: ${_selectedFilePath!.split('/').last}'
                                  : null,
                            ),
                            maxLines: null,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Key is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          tooltip: 'Select key file',
                          onPressed: _pickKeyFile,
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xl),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Encryption password (optional)',
                        helperText:
                            'If provided, the key will be encrypted in storage. '
                            'Leave empty to store unencrypted keys as plaintext.',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleAddKey,
            child: Text(_isSaving ? 'Saving...' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptPassphrase({required String title, String? helper}) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(null),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Key passphrase',
                helperText: helper,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }
}
