import 'dart:convert';

import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_entry.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../widgets/section_nav_bar.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.controller,
    required this.hostsFuture,
    required this.builtInKeyStore,
    required this.builtInVault,
    this.leading,
    super.key,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyStore builtInKeyStore;
  final BuiltInSshVault builtInVault;
  final Widget? leading;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _agents = const [
    ('edge-01', 'Firmware 1.2.4', 'Online · 3 min ago'),
    ('edge-02', 'Firmware 1.1.9', 'Online · 2 hr ago'),
    ('workstation-lab', 'Firmware 1.0.2', 'Offline · Yesterday'),
  ];

  static const _tabs = [
    Tab(text: 'General'),
    Tab(text: 'Servers'),
    Tab(text: 'Docker'),
    Tab(text: 'Kubernetes'),
    Tab(text: 'Security'),
    Tab(text: 'Agents'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final settings = widget.controller.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Settings',
              tabs: _tabs,
              controller: _tabController,
              showTitle: false,
              leading: widget.leading,
            ),
            Expanded(
              child: widget.controller.isLoaded
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _GeneralSettingsTab(
                          selectedTheme: settings.themeMode,
                          notificationsEnabled: settings.notificationsEnabled,
                          telemetryEnabled: settings.telemetryEnabled,
                          zoomFactor: settings.zoomFactor,
                          onThemeChanged: (mode) => widget.controller.update(
                            (current) => current.copyWith(themeMode: mode),
                          ),
                          onNotificationsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  notificationsEnabled: value,
                                ),
                              ),
                          onTelemetryChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(telemetryEnabled: value),
                              ),
                          onZoomChanged: (value) => widget.controller.update(
                            (current) => current.copyWith(zoomFactor: value),
                          ),
                        ),
                        _ServersSettingsTab(
                          key: const ValueKey('servers_settings_tab'),
                          autoRefresh: settings.serverAutoRefresh,
                          showOfflineHosts: settings.serverShowOffline,
                          controller: widget.controller,
                          hostsFuture: widget.hostsFuture,
                          builtInKeyStore: widget.builtInKeyStore,
                          builtInVault: widget.builtInVault,
                          onAutoRefreshChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(serverAutoRefresh: value),
                              ),
                          onShowOfflineChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(serverShowOffline: value),
                              ),
                        ),
                        _DockerSettingsTab(
                          liveStatsEnabled: settings.dockerLiveStats,
                          pruneWarningsEnabled: settings.dockerPruneWarnings,
                          onLiveStatsChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(dockerLiveStats: value),
                              ),
                          onPruneWarningsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  dockerPruneWarnings: value,
                                ),
                              ),
                        ),
                        _KubernetesSettingsTab(
                          autoDiscoverEnabled: settings.kubernetesAutoDiscover,
                          includeSystemPods:
                              settings.kubernetesIncludeSystemPods,
                          onAutoDiscoverChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  kubernetesAutoDiscover: value,
                                ),
                              ),
                          onIncludeSystemPodsChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  kubernetesIncludeSystemPods: value,
                                ),
                              ),
                        ),
                        _SecuritySettingsTab(
                          mfaRequired: settings.mfaRequired,
                          sshRotationEnabled: settings.sshRotationEnabled,
                          auditStreamingEnabled: settings.auditStreamingEnabled,
                          onMfaChanged: (value) => widget.controller.update(
                            (current) => current.copyWith(mfaRequired: value),
                          ),
                          onSshRotationChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(sshRotationEnabled: value),
                              ),
                          onAuditStreamingChanged: (value) =>
                              widget.controller.update(
                                (current) => current.copyWith(
                                  auditStreamingEnabled: value,
                                ),
                              ),
                        ),
                        _AgentsSettingsTab(
                          autoUpdateAgents: settings.autoUpdateAgents,
                          agentAlertsEnabled: settings.agentAlertsEnabled,
                          agents: _agents,
                          onAutoUpdateChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(autoUpdateAgents: value),
                              ),
                          onAgentAlertsChanged: (value) =>
                              widget.controller.update(
                                (current) =>
                                    current.copyWith(agentAlertsEnabled: value),
                              ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }
}

class _GeneralSettingsTab extends StatelessWidget {
  const _GeneralSettingsTab({
    required this.selectedTheme,
    required this.notificationsEnabled,
    required this.telemetryEnabled,
    required this.zoomFactor,
    required this.onThemeChanged,
    required this.onNotificationsChanged,
    required this.onTelemetryChanged,
    required this.onZoomChanged,
  });

  final ThemeMode selectedTheme;
  final bool notificationsEnabled;
  final bool telemetryEnabled;
  final double zoomFactor;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onTelemetryChanged;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Theme',
          description: 'Switch between light, dark, or system themes.',
          child: DropdownButtonFormField<ThemeMode>(
            isExpanded: true,
            initialValue: selectedTheme,
            onChanged: (mode) {
              if (mode != null) {
                onThemeChanged(mode);
              }
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('System Default'),
              ),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Interface Zoom',
          description: 'Scale interface text to improve readability.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Slider(
                value: zoomFactor.clamp(0.8, 1.5).toDouble(),
                min: 0.8,
                max: 1.5,
                divisions: 7,
                label: '${(zoomFactor * 100).round()}%',
                onChanged: onZoomChanged,
              ),
              Text('Current zoom: ${(zoomFactor * 100).round()}%'),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Notifications',
          description: 'Manage app-level alerts for agent activity.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable notifications'),
            subtitle: const Text(
              'Receive push alerts when infrastructure changes are detected.',
            ),
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
        ),
        _SettingsSection(
          title: 'Telemetry',
          description:
              'Help improve cwatch by sharing anonymized usage metrics.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share anonymous telemetry'),
            subtitle: const Text(
              'Crash reports and session performance data are uploaded securely.',
            ),
            value: telemetryEnabled,
            onChanged: onTelemetryChanged,
          ),
        ),
      ],
    );
  }
}

class _ServersSettingsTab extends StatefulWidget {
  const _ServersSettingsTab({
    super.key,
    required this.autoRefresh,
    required this.showOfflineHosts,
    required this.controller,
    required this.hostsFuture,
    required this.builtInKeyStore,
    required this.builtInVault,
    required this.onAutoRefreshChanged,
    required this.onShowOfflineChanged,
  });

  final bool autoRefresh;
  final bool showOfflineHosts;
  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyStore builtInKeyStore;
  final BuiltInSshVault builtInVault;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<bool> onShowOfflineChanged;

  @override
  State<_ServersSettingsTab> createState() => _ServersSettingsTabState();
}

class _ServersSettingsTabState extends State<_ServersSettingsTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings;
    final backend = settings.sshClientBackend;
    final usingBuiltIn = backend == SshClientBackend.builtin;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Inventory Refresh',
          description: 'Control how often server metadata is refreshed.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-refresh server stats'),
            subtitle: const Text(
              'Periodically sync CPU, memory, and disk gauges.',
            ),
            value: widget.autoRefresh,
            onChanged: widget.onAutoRefreshChanged,
          ),
        ),
        _SettingsSection(
          title: 'Visibility',
          description:
              'Choose whether to show offline hosts in the servers list.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show offline hosts'),
            subtitle: const Text(
              'Keep historical hosts visible for quick triage.',
            ),
            value: widget.showOfflineHosts,
            onChanged: widget.onShowOfflineChanged,
          ),
        ),
        _SettingsSection(
          title: 'SSH Client',
          description:
              'Select the SSH backend used to interact with your hosts.',
          child: RadioGroup<SshClientBackend>(
            groupValue: backend,
            onChanged: (value) {
              if (value == null) {
                return;
              }
              widget.controller.update(
                (current) => current.copyWith(sshClientBackend: value),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<SshClientBackend>(
                  value: SshClientBackend.platform,
                  selected: backend == SshClientBackend.platform,
                  title: const Text('Platform SSH client'),
                  subtitle: const Text(
                    'Use the operating system’s ssh configuration and binaries.',
                  ),
                ),
                RadioListTile<SshClientBackend>(
                  value: SshClientBackend.builtin,
                  selected: backend == SshClientBackend.builtin,
                  title: const Text('Built-in SSH client'),
                  subtitle: const Text(
                    'Use the app’s encrypted key store (mobile-ready).',
                  ),
                ),
                if (usingBuiltIn)
                  _BuiltInSshSettings(
                    controller: widget.controller,
                    hostsFuture: widget.hostsFuture,
                    keyStore: widget.builtInKeyStore,
                    vault: widget.builtInVault,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BuiltInSshSettings extends StatefulWidget {
  const _BuiltInSshSettings({
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
  State<_BuiltInSshSettings> createState() => _BuiltInSshSettingsState();
}

class _BuiltInSshSettingsState extends State<_BuiltInSshSettings> {
  late Future<List<BuiltInSshKeyEntry>> _keysFuture;
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  late final VoidCallback _vaultListener;
  bool _isSaving = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide label and key.')),
      );
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
        debugPrint('[Settings] Encrypted key validation successful');
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
            content: Text(
              'Unsupported key cipher or format: ${e.message}',
            ),
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
        debugPrint('[Settings] Using password from form for validation');
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
        debugPrint('[Settings] Using password from form for validation');
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
    debugPrint('[Settings] Adding built-in key "$label"');
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
            isRequired
                ? 'Key passphrase required'
                : 'Key validation needed',
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
    debugPrint('[Settings] Unlocking built-in key $keyId');
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
        debugPrint('[Settings] Removed key binding for host $hostName');
      }
      widget.controller.update(
        (current) => current.copyWith(builtinSshHostKeyBindings: updatedBindings),
      );
    }

    debugPrint('[Settings] Removing built-in key $keyId');
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
    debugPrint('[Settings] Cleared unlocked built-in keys from memory');
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
    debugPrint(
      '[Settings] Host $hostName now uses ${keyId ?? 'platform default'} for SSH.',
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
        const Text(
          'Built-in keys remain encrypted on disk and are only decrypted on demand.',
        ),
        const SizedBox(height: 12),
        SelectableText(
          'Powered by dartssh2 · https://pub.dev/documentation/dartssh2/2.13.0/',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
                  if (!entry.isEncrypted && !widget.vault.isUnlocked(entry.id)) {
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
                final isLoading = (keysSnapshot.connectionState == ConnectionState.waiting ||
                    hostsSnapshot.connectionState == ConnectionState.waiting) &&
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
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          if (statusText != null) Text(statusText, style: Theme.of(context).textTheme.bodySmall),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Key locked.')),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to encrypt key: $error')),
      );
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

class _DockerSettingsTab extends StatelessWidget {
  const _DockerSettingsTab({
    required this.liveStatsEnabled,
    required this.pruneWarningsEnabled,
    required this.onLiveStatsChanged,
    required this.onPruneWarningsChanged,
  });

  final bool liveStatsEnabled;
  final bool pruneWarningsEnabled;
  final ValueChanged<bool> onLiveStatsChanged;
  final ValueChanged<bool> onPruneWarningsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Monitoring',
          description: 'Toggle live container resource charts.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable live stats streaming'),
            subtitle: const Text(
              'Container CPU/memory metrics update every 2 seconds.',
            ),
            value: liveStatsEnabled,
            onChanged: onLiveStatsChanged,
          ),
        ),
        _SettingsSection(
          title: 'Maintenance',
          description:
              'Display safety prompts before pruning unused resources.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Warn before prune'),
            subtitle: const Text(
              'Surface a confirmation dialog before deleting dangling images.',
            ),
            value: pruneWarningsEnabled,
            onChanged: onPruneWarningsChanged,
          ),
        ),
      ],
    );
  }
}

class _KubernetesSettingsTab extends StatelessWidget {
  const _KubernetesSettingsTab({
    required this.autoDiscoverEnabled,
    required this.includeSystemPods,
    required this.onAutoDiscoverChanged,
    required this.onIncludeSystemPodsChanged,
  });

  final bool autoDiscoverEnabled;
  final bool includeSystemPods;
  final ValueChanged<bool> onAutoDiscoverChanged;
  final ValueChanged<bool> onIncludeSystemPodsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        _SettingsSection(
          title: 'Clusters',
          description: 'Automatically detect new kubeconfigs from disk.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-discover contexts'),
            subtitle: const Text(
              'Watch ~/.kube for newly added kubeconfig files.',
            ),
            value: autoDiscoverEnabled,
            onChanged: onAutoDiscoverChanged,
          ),
        ),
        _SettingsSection(
          title: 'Namespace Filters',
          description: 'Reduce clutter by hiding platform namespaces.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include system pods'),
            subtitle: const Text(
              'Show kube-system and istio-* namespaces in resource explorer.',
            ),
            value: includeSystemPods,
            onChanged: onIncludeSystemPodsChanged,
          ),
        ),
      ],
    );
  }
}

class _SecuritySettingsTab extends StatelessWidget {
  const _SecuritySettingsTab({
    required this.mfaRequired,
    required this.sshRotationEnabled,
    required this.auditStreamingEnabled,
    required this.onMfaChanged,
    required this.onSshRotationChanged,
    required this.onAuditStreamingChanged,
  });

  final bool mfaRequired;
  final bool sshRotationEnabled;
  final bool auditStreamingEnabled;
  final ValueChanged<bool> onMfaChanged;
  final ValueChanged<bool> onSshRotationChanged;
  final ValueChanged<bool> onAuditStreamingChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _SettingsSection(
          title: 'Access Controls',
          description: 'Protect operator access to critical resources.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require MFA on sign-in'),
                subtitle: const Text(
                  'Users must register an authenticator app or security key.',
                ),
                value: mfaRequired,
                onChanged: onMfaChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enforce SSH key rotation'),
                subtitle: const Text(
                  'Keys older than 90 days automatically expire.',
                ),
                value: sshRotationEnabled,
                onChanged: onSshRotationChanged,
              ),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Auditing',
          description:
              'Stream live audit events to your SIEM or download manual exports.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable audit log streaming'),
            subtitle: const Text(
              'Sends real-time events to the configured webhook endpoint.',
            ),
            value: auditStreamingEnabled,
            onChanged: onAuditStreamingChanged,
          ),
        ),
      ],
    );
  }
}

class _AgentsSettingsTab extends StatelessWidget {
  const _AgentsSettingsTab({
    required this.autoUpdateAgents,
    required this.agentAlertsEnabled,
    required this.agents,
    required this.onAutoUpdateChanged,
    required this.onAgentAlertsChanged,
  });

  final bool autoUpdateAgents;
  final bool agentAlertsEnabled;
  final List<(String, String, String)> agents;
  final ValueChanged<bool> onAutoUpdateChanged;
  final ValueChanged<bool> onAgentAlertsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        _SettingsSection(
          title: 'Agent Fleet',
          description: 'Keep agents healthy with automatic patches and alerts.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-update agents'),
                subtitle: const Text(
                  'Roll out patches when new firmware is published.',
                ),
                value: autoUpdateAgents,
                onChanged: onAutoUpdateChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert when agents go offline'),
                subtitle: const Text(
                  'Send notifications if an agent misses a heartbeat.',
                ),
                value: agentAlertsEnabled,
                onChanged: onAgentAlertsChanged,
              ),
            ],
          ),
        ),
        _SettingsSection(
          title: 'Connected Agents',
          description:
              'Review firmware versions and last heartbeat per device.',
          child: Column(
            children: agents
                .map(
                  (agent) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(agent.$1),
                    subtitle: Text(agent.$2),
                    trailing: Text(agent.$3),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
