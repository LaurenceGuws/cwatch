import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';

/// Built-in SSH settings widget for managing SSH keys
class BuiltInSshSettings extends StatefulWidget {
  const BuiltInSshSettings({
    super.key,
    required this.controller,
    required this.hostsFuture,
    required this.keyService,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyService keyService;

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
    _keysFuture = widget.keyService.listKeys();
    _vaultListener = () => setState(() {});
    widget.keyService.vault.addListener(_vaultListener);
  }

  @override
  void dispose() {
    widget.keyService.vault.removeListener(_vaultListener);
    _labelController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshKeys() {
    setState(() {
      _keysFuture = widget.keyService.listKeys();
    });
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

    setState(() => _isSaving = true);
    AppLogger.d('Adding built-in key "$label"', tag: 'Settings');
    try {
      final addResult = await widget.keyService.addKey(
        label: label,
        keyPem: keyText,
        storagePassword: password.isEmpty ? null : password,
        keyPassphrase: null,
      );
      if (addResult.status == BuiltInSshKeyAddStatus.needsPassphrase) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final passphrase = await _promptForKeyPassphrase(
          context,
          isRequired: true,
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
    final entry = await widget.keyService.loadKey(keyId);
    if (!mounted) return;
    String? password;
    if (entry != null && entry.isEncrypted) {
      password = await _promptForPassword(context);
      if (password == null) {
        return;
      }
    }
    AppLogger.d('Unlocking built-in key $keyId', tag: 'Settings');
    final result = await widget.keyService.unlock(keyId, password: password);
    if (!mounted) return;
    switch (result.status) {
      case BuiltInSshKeyUnlockStatus.unlocked:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
        break;
      case BuiltInSshKeyUnlockStatus.incorrectPassword:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Incorrect password.')),
        );
        break;
      default:
        final message = result.message ?? 'Failed to unlock key.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        break;
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
    await widget.keyService.deleteKey(keyId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Key removed from vault.')));
    _refreshKeys();
  }

  void _clearUnlocked() {
    widget.keyService.lockAll();
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
                      !widget.keyService.isUnlocked(entry.id)) {
                    widget.keyService
                        .unlock(entry.id, password: null)
                        .catchError(
                          (_) => const BuiltInSshKeyUnlockResult(
                            status: BuiltInSshKeyUnlockStatus.failed,
                          ),
                        );
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
    final isUnlocked =
        widget.keyService.isUnlocked(entry.id) || !entry.isEncrypted;
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
    widget.keyService.lock(keyId);
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

    final entry = await widget.keyService.loadKey(keyId);
    if (entry == null || entry.isEncrypted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key not found or already encrypted.')),
        );
      }
      return;
    }

    try {
      await widget.keyService.encryptStoredKey(
        keyId: keyId,
        password: password,
      );

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
