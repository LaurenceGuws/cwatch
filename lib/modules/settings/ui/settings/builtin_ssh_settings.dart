import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_store.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_vault.dart';

/// Built-in SSH settings widget for managing SSH keys
class BuiltInSshSettings extends StatefulWidget {
  const BuiltInSshSettings({
    super.key,
    required this.controller,
    required this.hostsFuture,
    required this.keyStore,
    required this.vault,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyStore keyStore;
  final BuiltInSshVault vault;

  @override
  State<BuiltInSshSettings> createState() => _BuiltInSshSettingsState();
}

class _BuiltInSshSettingsState extends State<BuiltInSshSettings> {
  late Future<List<BuiltInSshKeyEntry>> _keysFuture;
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  late final VoidCallback _vaultListener;
  bool _isSaving = false;
  String? _lastPickedFileName;
  List<BuiltInSshKeyEntry> _cachedKeys = [];
  List<SshHost>? _cachedHosts;

  @override
  void initState() {
    super.initState();
    _keysFuture = widget.keyStore.listEntries();
    _vaultListener = () => setState(() {});
    widget.vault.addListener(_vaultListener);
    _autoUnlockPlaintextKeys();
  }

  Future<void> _autoUnlockPlaintextKeys() async {
    // Automatically unlock plaintext keys (they don't need a password)
    final keys = await _keysFuture;
    for (final entry in keys) {
      if (!entry.isEncrypted && !widget.vault.isUnlocked(entry.id)) {
        try {
          await widget.vault.unlock(entry.id, null);
        } catch (_) {
          // Ignore errors - key might be invalid
        }
      }
    }
  }

  @override
  void dispose() {
    widget.vault.removeListener(_vaultListener);
    _labelController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshKeys() {
    setState(() {
      _keysFuture = widget.keyStore.listEntries();
    });
    _autoUnlockPlaintextKeys();
  }

  Future<void> _handleAddKey() async {
    final label = _labelController.text.trim();
    final keyText = _keyController.text.trim();
    final password = _passwordController.text.trim();
    if (label.isEmpty || keyText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provide label and key.')));
      return;
    }

    // Try to parse the key without passphrase first
    bool keyIsEncrypted = false;
    bool parseSucceeded = false;
    try {
      SSHKeyPair.fromPem(keyText);
      parseSucceeded = true;
      keyIsEncrypted = false;
    } on ArgumentError catch (e) {
      if (e.message == 'passphrase is required for encrypted key') {
        keyIsEncrypted = true;
      } else {
        // Other parsing error - might be encrypted or unsupported
        // We'll try with passphrase to determine which
        keyIsEncrypted = false; // Will prompt anyway
      }
    } on StateError catch (e) {
      if (e.message.contains('encrypted')) {
        keyIsEncrypted = true;
      } else {
        // Other parsing error - might be encrypted or unsupported
        keyIsEncrypted = false; // Will prompt anyway
      }
    } catch (e) {
      // Parsing failed - might be encrypted or unsupported
      // We'll try with passphrase to determine which
      keyIsEncrypted = false; // Will prompt anyway
    }

    // Helper function to validate key with passphrase
    Future<bool> validateKeyWithPassphrase(String passphraseToTest) async {
      try {
        SSHKeyPair.fromPem(keyText, passphraseToTest);
        keyIsEncrypted = true; // Confirmed encrypted
        AppLogger.d('Encrypted key validation successful', tag: 'Settings');
        return true;
      } on SSHKeyDecryptError catch (e) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid passphrase: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return false;
      } on UnsupportedError catch (e) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unsupported key cipher or format: ${e.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return false;
      } catch (e) {
        if (!mounted) return false;
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
        return false;
      }
    }

    // If parsing failed, always validate - might be encrypted or unsupported
    if (!parseSucceeded) {
      String? passphrase;

      // Use form password if provided, otherwise prompt
      if (password.isNotEmpty) {
        passphrase = password;
        AppLogger.d('Using password from form for validation', tag: 'Settings');
      } else {
        passphrase = await _promptForKeyPassphrase(
          context,
          isRequired: keyIsEncrypted,
        );
        if (passphrase == null || !mounted) {
          if (keyIsEncrypted) {
            // User cancelled required passphrase
            return;
          }
          // User cancelled - reject since parsing already failed
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Key cannot be parsed. It may be encrypted, unsupported, or malformed.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }

        // If user chose "Try without passphrase", we already know it fails
        if (passphrase.isEmpty) {
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
      }

      // Test decryption/parsing with passphrase
      final isValid = await validateKeyWithPassphrase(passphrase);
      if (!isValid) {
        return; // Don't save invalid key
      }
    } else if (keyIsEncrypted) {
      // Key was detected as encrypted, validate passphrase
      String? passphrase;

      // Use form password if provided, otherwise prompt
      if (password.isNotEmpty) {
        passphrase = password;
        AppLogger.d('Using password from form for validation', tag: 'Settings');
      } else {
        passphrase = await _promptForKeyPassphrase(context, isRequired: true);
        if (passphrase == null || !mounted) {
          return; // User cancelled
        }
      }

      // Test decryption
      final isValid = await validateKeyWithPassphrase(passphrase);
      if (!isValid) {
        return; // Don't save invalid key
      }
    }

    setState(() => _isSaving = true);
    AppLogger.d('Adding built-in key "$label"', tag: 'Settings');
    try {
      await widget.keyStore.addEntry(
        label: label,
        keyData: utf8.encode(keyText),
        password: password.isEmpty ? null : password,
      );
      _labelController.clear();
      _keyController.clear();
      _passwordController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Key added to the vault.')));
      _refreshKeys();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add key: $error')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<String?> _promptForKeyPassphrase(
    BuildContext context, {
    bool isRequired = false,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isRequired ? 'Key passphrase required' : 'Key validation needed',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRequired
                    ? 'This key is encrypted with a passphrase. '
                          'Please provide the passphrase to validate the key can be decrypted.'
                    : 'The key could not be parsed. It may be encrypted with a passphrase, '
                          'or it may be unsupported. Please try providing a passphrase if the key is encrypted.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Key passphrase',
                  helperText: isRequired
                      ? 'This will not be stored, only used for validation.'
                      : 'Leave empty if the key is not encrypted. '
                            'This will not be stored, only used for validation.',
                ),
              ),
            ],
          ),
          actions: [
            if (!isRequired)
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
  }

  Future<void> _unlockKey(String keyId) async {
    // Check if the entry needs a password
    final entry = await widget.keyStore.loadEntry(keyId);
    if (!mounted) return;
    String? password;
    if (entry != null && entry.isEncrypted) {
      password = await _promptForPassword(context);
      if (password == null) {
        return;
      }
    }
    AppLogger.d('Unlocking built-in key $keyId', tag: 'Settings');
    try {
      await widget.vault.unlock(keyId, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key unlocked for this session.')),
      );
    } on BuiltInSshKeyDecryptException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password for that key.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
    }
  }

  Future<void> _removeKeyEntry(String keyId) async {
    // Check which hosts are using this key
    final hosts = await widget.hostsFuture;
    if (!mounted) return;
    final bindings = widget.controller.settings.builtinSshHostKeyBindings;
    final hostsUsingKey = hosts
        .where((host) => bindings[host.name] == keyId)
        .map((host) => host.name)
        .toList();

    // If key is in use, warn the user
    if (hostsUsingKey.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Key in use'),
            content: Text(
              'This key is currently assigned to ${hostsUsingKey.length} '
              'host${hostsUsingKey.length == 1 ? '' : 's'}: '
              '${hostsUsingKey.join(', ')}.\n\n'
              'Deleting this key will remove it from these hosts. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      // Remove key bindings for all hosts using this key
      final updatedBindings = Map<String, String>.from(bindings);
      for (final hostName in hostsUsingKey) {
        updatedBindings.remove(hostName);
        AppLogger.d('Removed key binding for host $hostName', tag: 'Settings');
      }
      widget.controller.update(
        (current) =>
            current.copyWith(builtinSshHostKeyBindings: updatedBindings),
      );
    }

    AppLogger.d('Removing built-in key $keyId', tag: 'Settings');
    await widget.keyStore.deleteEntry(keyId);
    widget.vault.forget(keyId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Key removed from vault.')));
    _refreshKeys();
  }

  void _clearUnlocked() {
    widget.vault.forgetAll();
    AppLogger.d('Cleared unlocked built-in keys from memory', tag: 'Settings');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unlocked keys cleared from memory.')),
    );
  }

  void _updateHostBinding(String hostName, String? keyId) {
    final current = widget.controller.settings.builtinSshHostKeyBindings;
    final updated = Map<String, String>.from(current);
    if (keyId == null) {
      updated.remove(hostName);
    } else {
      updated[hostName] = keyId;
    }
    AppLogger.d(
      'Host $hostName now uses ${keyId ?? 'platform default'} for SSH.',
      tag: 'Settings',
    );
    widget.controller.update(
      (current) => current.copyWith(builtinSshHostKeyBindings: updated),
    );
  }

  Future<String?> _promptForPassword(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unlock key'),
          content: TextField(
            controller: controller,
            autofocus: true,
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        _buildAddKeyForm(context),
        const SizedBox(height: 12),
        FutureBuilder<List<BuiltInSshKeyEntry>>(
          future: _keysFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Unable to load keys: ${snapshot.error}');
            }
            final keys = snapshot.data ?? const [];
            _cachedKeys = keys;

            // Auto-unlock plaintext keys
            if (keys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                for (final entry in keys) {
                  if (!entry.isEncrypted &&
                      !widget.vault.isUnlocked(entry.id)) {
                    widget.vault.unlock(entry.id, null).catchError((_) {
                      // Ignore errors
                    });
                  }
                }
              });
            }

            if (keys.isEmpty) {
              return const Text('No built-in keys have been added yet.');
            }
            return Column(
              children: keys
                  .map((entry) => _buildKeyTile(entry, context))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _clearUnlocked,
            child: const Text('Clear unlocked keys'),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<BuiltInSshKeyEntry>>(
          future: _keysFuture,
          builder: (context, keysSnapshot) {
            return FutureBuilder<List<SshHost>>(
              future: widget.hostsFuture,
              builder: (context, hostsSnapshot) {
                // Update cache when data is available
                if (keysSnapshot.hasData && keysSnapshot.data != null) {
                  _cachedKeys = keysSnapshot.data!;
                }
                if (hostsSnapshot.hasData && hostsSnapshot.data != null) {
                  _cachedHosts = hostsSnapshot.data!;
                }

                // Use cached data if available while loading
                final hosts = hostsSnapshot.data ?? _cachedHosts ?? const [];

                // Only show loading spinner if we don't have cached data
                final isLoading =
                    (keysSnapshot.connectionState == ConnectionState.waiting ||
                        hostsSnapshot.connectionState ==
                            ConnectionState.waiting) &&
                    (_cachedKeys.isEmpty && _cachedHosts == null);

                if (isLoading) {
                  return const SizedBox(
                    height: 64,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (hostsSnapshot.hasError && _cachedHosts == null) {
                  return Text('Unable to load hosts: ${hostsSnapshot.error}');
                }
                if (hosts.isEmpty) {
                  return const Text('No SSH hosts were detected.');
                }

                // Group hosts by source
                final grouped = _groupHostsBySource(hosts);
                final sources = grouped.keys.toList()..sort();
                final showSections = sources.length > 1;

                if (!showSections) {
                  // Single source - no headers needed
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Host to key bindings'),
                      const SizedBox(height: 6),
                      ...hosts.map((host) => _buildHostMapping(host)),
                    ],
                  );
                }

                // Multiple sources - show with headers
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Host to key bindings'),
                    const SizedBox(height: 6),
                    ...sources.expand((source) {
                      final sourceHosts = grouped[source]!;
                      return [
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(
                            _getSourceDisplayName(source),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        ...sourceHosts.map((host) => _buildHostMapping(host)),
                      ];
                    }),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddKeyForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add a new key'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import from file'),
              onPressed: _isSaving ? null : () => _pickKeyFile(context),
            ),
            if (_lastPickedFileName != null)
              Chip(
                label: Text(_lastPickedFileName!),
                avatar: const Icon(Icons.description_outlined, size: 18),
                onDeleted: () {
                  setState(() {
                    _lastPickedFileName = null;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _labelController,
          decoration: const InputDecoration(labelText: 'Key label'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _keyController,
          decoration: const InputDecoration(
            labelText: 'Private key (PEM format)',
          ),
          maxLines: null,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Encryption password (optional)',
            helperText:
                'If provided, the key will be encrypted in storage. '
                'Leave empty to store unencrypted keys as plaintext.',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleAddKey,
            child: Text(_isSaving ? 'Saving...' : 'Add key'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickKeyFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select private key (PEM)',
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.first;
    if (file == null) {
      return;
    }
    try {
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        throw Exception('Unable to read selected file.');
      }
      final contents = String.fromCharCodes(bytes);
      setState(() {
        _keyController.text = contents;
        _labelController.text = _labelController.text.isEmpty
            ? p.basename(file.name)
            : _labelController.text;
        _lastPickedFileName = file.name;
      });
      if (!context.mounted) return;
      _showSnack(context, 'Loaded key from ${file.name}');
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'Failed to read key: $error');
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildKeyTile(BuiltInSshKeyEntry entry, BuildContext context) {
    // Plaintext keys are always considered unlocked
    final isUnlocked = widget.vault.isUnlocked(entry.id) || !entry.isEncrypted;
    final fingerprint = entry.fingerprint.length > 12
        ? '${entry.fingerprint.substring(0, 12)}…'
        : entry.fingerprint;
    final statusParts = <String>[];
    if (entry.isEncrypted) {
      statusParts.add('Encrypted storage');
    } else {
      statusParts.add('Plaintext storage');
    }
    if (entry.keyHasPassphrase) {
      statusParts.add('Has passphrase');
    }
    final statusText = statusParts.isEmpty ? null : statusParts.join(' • ');
    return ListTile(
      title: Text(entry.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fingerprint: $fingerprint'),
          if (statusText != null)
            Text(statusText, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnlocked)
            Tooltip(
              message: entry.isEncrypted
                  ? 'Lock this key to remove it from memory'
                  : 'Plaintext storage is a security risk. Encrypt this key to protect it.',
              child: ElevatedButton(
                onPressed: entry.isEncrypted
                    ? () => _lockKey(entry.id)
                    : () => _encryptKey(entry.id),
                style: ElevatedButton.styleFrom(
                  foregroundColor: entry.isEncrypted
                      ? null
                      : Colors.orange.shade700,
                ),
                child: Text(entry.isEncrypted ? 'Lock key' : 'Encrypt key'),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _unlockKey(entry.id),
              child: const Text('Unlock'),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeKeyEntry(entry.id),
          ),
        ],
      ),
    );
  }

  Future<void> _lockKey(String keyId) async {
    widget.vault.forget(keyId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Key locked.')));
  }

  Future<void> _encryptKey(String keyId) async {
    final password = await _promptForPassword(context);
    if (password == null || !mounted) {
      return;
    }

    // Load the current entry
    final entry = await widget.keyStore.loadEntry(keyId);
    if (entry == null || entry.isEncrypted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key not found or already encrypted.')),
        );
      }
      return;
    }

    // Get the plaintext key data
    final keyData = utf8.encode(entry.plaintext!);

    // Delete the old entry
    await widget.keyStore.deleteEntry(keyId);
    widget.vault.forget(keyId);

    // Create a new encrypted entry with the same ID
    try {
      final newEntry = await widget.keyStore.buildEntry(
        id: keyId,
        label: entry.label,
        keyData: keyData,
        keyIsEncrypted: entry.keyHasPassphrase,
        password: password,
      );
      await widget.keyStore.writeEntry(newEntry);

      // Auto-unlock the newly encrypted key
      await widget.vault.unlock(keyId, password);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key encrypted successfully.')),
      );
      _refreshKeys();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to encrypt key: $error')));
    }
  }

  Map<String, List<SshHost>> _groupHostsBySource(List<SshHost> hosts) {
    final grouped = <String, List<SshHost>>{};
    for (final host in hosts) {
      final source = host.source ?? 'unknown';
      grouped.putIfAbsent(source, () => []).add(host);
    }
    return grouped;
  }

  String _getSourceDisplayName(String source) {
    if (source == 'custom') {
      return 'Added Servers';
    }
    // Extract filename from path
    final parts = source.split('/');
    return parts.last;
  }

  Widget _buildHostMapping(SshHost host) {
    final mapping =
        widget.controller.settings.builtinSshHostKeyBindings[host.name];
    final seen = <String>{};
    final keyItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(
        value: null,
        child: Text('Use platform/default SSH configuration'),
      ),
    ];
    for (final entry in _cachedKeys) {
      if (!seen.add(entry.id)) {
        continue;
      }
      keyItems.add(DropdownMenuItem(value: entry.id, child: Text(entry.label)));
    }
    if (mapping != null && !seen.contains(mapping)) {
      keyItems.add(
        DropdownMenuItem(value: mapping, child: Text('Unknown key ($mapping)')),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String?>(
        initialValue: mapping,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: host.name,
          border: const OutlineInputBorder(),
        ),
        items: keyItems,
        onChanged: (value) => _updateHostBinding(host.name, value),
      ),
    );
  }
}
