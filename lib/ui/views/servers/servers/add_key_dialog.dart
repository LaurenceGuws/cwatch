import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';

/// Dialog for adding an SSH key
class AddKeyDialog extends StatefulWidget {
  const AddKeyDialog({
    super.key,
    required this.keyStore,
    required this.vault,
  });

  final BuiltInSshKeyStore keyStore;
  final BuiltInSshVault vault;

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

    // Validate encrypted keys (same logic as settings view)
    bool keyIsEncrypted = false;
    bool parseSucceeded = false;
    try {
      SSHKeyPair.fromPem(keyText);
      parseSucceeded = true;
      keyIsEncrypted = false;
    } on ArgumentError catch (e) {
      if (e.message == 'passphrase is required for encrypted key') {
        keyIsEncrypted = true;
      }
    } on StateError catch (e) {
      if (e.message.contains('encrypted')) {
        keyIsEncrypted = true;
      }
    } catch (_) {
      // Parsing failed - might be encrypted or unsupported
    }

    // If parsing failed, validate with passphrase
    if (!parseSucceeded) {
      String? passphrase;
      if (password.isNotEmpty) {
        passphrase = password;
      } else {
        // Prompt for passphrase
        final passphraseResult = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('Key validation needed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The key could not be parsed. It may be encrypted with a passphrase, '
                    'or it may be unsupported. Please try providing a passphrase if the key is encrypted.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Key passphrase',
                      helperText: 'Leave empty if the key is not encrypted.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('Try without passphrase'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Validate'),
                ),
              ],
            );
          },
        );
        if (passphraseResult == null) {
          return; // User cancelled
        }
        passphrase = passphraseResult.isEmpty ? null : passphraseResult;
      }

      if (passphrase != null && passphrase.isNotEmpty) {
        try {
          SSHKeyPair.fromPem(keyText, passphrase);
          keyIsEncrypted = true;
        } on SSHKeyDecryptError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid passphrase: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } on UnsupportedError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unsupported key cipher or format: ${e.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Key cannot be parsed even with passphrase. '
                'It may be unsupported or malformed: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      } else {
        // No passphrase provided but parsing failed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Key cannot be parsed without passphrase. '
              'It may be encrypted, unsupported, or malformed.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    } else if (keyIsEncrypted) {
      // Key was detected as encrypted, validate passphrase
      if (password.isEmpty) {
        // Prompt for passphrase
        final passphraseResult = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text(
                'Key passphrase required',
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Key passphrase',
                    ),
                  ),
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
                  child: const Text('Validate'),
                ),
              ],
            );
          },
        );
        if (passphraseResult == null) {
          return; // User cancelled
        }
        try {
          SSHKeyPair.fromPem(keyText, passphraseResult);
        } on SSHKeyDecryptError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid passphrase: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to validate key: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final entry = await widget.keyStore.addEntry(
        label: label,
        keyData: utf8.encode(keyText),
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add key: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add SSH Key',
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                    decoration: const InputDecoration(
                      labelText: 'Key label',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Label is required';
                      }
                      return null;
                    },
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
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
    );
  }
}

