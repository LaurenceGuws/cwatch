import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/built_in_ssh_key_controller.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/ssh_preferences.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/form_spacer.dart';

/// Built-in SSH settings widget for managing SSH keys
class BuiltInSshSettings extends StatefulWidget {
  const BuiltInSshSettings({
    super.key,
    required this.keyController,
    required this.sshPreferences,
  });

  final BuiltInSshKeyController keyController;
  final SshPreferences sshPreferences;

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
    _keysFuture = widget.keyController.listBuiltInKeys();
    _vaultListener = () => setState(() {});
    widget.keyController.keyVaultListenable.addListener(_vaultListener);
  }

  @override
  void dispose() {
    widget.keyController.keyVaultListenable.removeListener(_vaultListener);
    _labelController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshKeys() {
    setState(() {
      _keysFuture = widget.keyController.listBuiltInKeys();
    });
  }

  Future<void> _handleAddKey() async {
    final label = _labelController.text.trim();
    final keyText = _keyController.text.trim();
    final password = _passwordController.text.trim();
    setState(() => _isSaving = true);
    try {
      final added = await widget.keyController.addBuiltInKey(
        label: label,
        keyText: keyText,
        password: password,
      );
      if (!mounted) return;
      if (added) {
        _labelController.clear();
        _keyController.clear();
        _passwordController.clear();
        _refreshKeys();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _decryptKey(String keyId) async {
    await widget.keyController.decryptBuiltInKey(keyId);
  }

  Future<void> _removeKeyEntry(String keyId) async {
    final removed = await widget.keyController.removeBuiltInKey(keyId);
    if (removed) {
      _refreshKeys();
    }
  }

  void _clearDecrypted() {
    widget.keyController.clearDecryptedKeys();
  }

  void _updateHostBinding(String hostName, String? keyId) {
    widget.keyController.updateHostBinding(hostName, keyId);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSpacer(),
        const FormSpacer(),
        _buildAddKeyForm(context),
        const FormSpacer(),
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

            // Auto-decrypt plaintext keys
            if (keys.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.keyController.decryptPlaintextKeysIfNeeded(keys);
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
        SizedBox(height: spacing.base * 5),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _clearDecrypted,
            child: const Text('Clear decrypted keys'),
          ),
        ),
        const FormSpacer(),
        FutureBuilder<List<BuiltInSshKeyEntry>>(
          future: _keysFuture,
          builder: (context, keysSnapshot) {
            return FutureBuilder<List<SshHost>>(
              future: widget.keyController.hostsFuture,
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
                      SizedBox(height: spacing.base * 1.5),
                      ...hosts.map((host) => _buildHostMapping(host)),
                    ],
                  );
                }

                // Multiple sources - show with headers
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Host to key bindings'),
                    SizedBox(height: spacing.base * 1.5),
                    ...sources.expand((source) {
                      final sourceHosts = grouped[source]!;
                      return [
                        Padding(
                          padding: EdgeInsets.only(
                            top: spacing.lg,
                            bottom: spacing.base * 1.5,
                          ),
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
    final spacing = context.appTheme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add a new key'),
        SizedBox(height: spacing.md),
        Wrap(
          spacing: spacing.md,
          runSpacing: spacing.md,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import from file'),
              onPressed: _isSaving ? null : _pickKeyFile,
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
        SizedBox(height: spacing.md),
        TextField(
          controller: _labelController,
          decoration: const InputDecoration(labelText: 'Key label'),
        ),
        SizedBox(height: spacing.md),
        TextField(
          controller: _keyController,
          decoration: const InputDecoration(
            labelText: 'Private key (PEM format)',
          ),
          maxLines: null,
        ),
        SizedBox(height: spacing.md),
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
        SizedBox(height: spacing.md),
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

  Future<void> _pickKeyFile() async {
    final loaded = await widget.keyController.loadPrivateKeyContents();
    if (loaded == null) {
      return;
    }
    setState(() {
      _keyController.text = loaded.contents;
      _labelController.text = _labelController.text.isEmpty
          ? loaded.fileName
          : _labelController.text;
      _lastPickedFileName = loaded.fileName;
    });
  }

  Widget _buildKeyTile(BuiltInSshKeyEntry entry, BuildContext context) {
    // Plaintext keys are always considered decrypted
    final isDecrypted =
        widget.keyController.isKeyDecrypted(entry.id) || !entry.isEncrypted;
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
          if (isDecrypted)
            Tooltip(
              message: entry.isEncrypted
                  ? 'Clear decrypted key from memory'
                  : 'Plaintext storage is a security risk. Encrypt this key to protect it.',
              child: TextButton(
                onPressed: entry.isEncrypted
                    ? () => _clearKey(entry.id)
                    : () => _encryptKey(entry.id),
                style: TextButton.styleFrom(
                  foregroundColor: entry.isEncrypted
                      ? null
                      : Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(entry.isEncrypted ? 'Clear' : 'Encrypt'),
              ),
            )
          else
            TextButton(
              onPressed: () => _decryptKey(entry.id),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Decrypt'),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeKeyEntry(entry.id),
          ),
        ],
      ),
    );
  }

  void _clearKey(String keyId) {
    widget.keyController.clearDecryptedKey(keyId);
  }

  Future<void> _encryptKey(String keyId) async {
    final encrypted = await widget.keyController.encryptBuiltInKey(keyId);
    if (encrypted) {
      _refreshKeys();
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
        widget.sshPreferences.builtinHostKeyBindings[host.name];
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
      padding: EdgeInsets.only(bottom: context.appTheme.spacing.md),
      child: DropdownButtonFormField<String?>(
        initialValue: mapping,
        isExpanded: true,
        decoration: InputDecoration(labelText: host.name),
        items: keyItems,
        onChanged: (value) => _updateHostBinding(host.name, value),
      ),
    );
  }
}
