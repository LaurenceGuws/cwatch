import 'dart:convert';

import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/models/ssh_host.dart';
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

class _ServersSettingsTab extends StatelessWidget {
  const _ServersSettingsTab({
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
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final backend = settings.sshClientBackend;
    final usingBuiltIn = backend == SshClientBackend.builtin;
    return ListView(
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
            value: autoRefresh,
            onChanged: onAutoRefreshChanged,
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
            value: showOfflineHosts,
            onChanged: onShowOfflineChanged,
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
              controller.update(
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
                    controller: controller,
                    hostsFuture: hostsFuture,
                    keyStore: builtInKeyStore,
                    vault: builtInVault,
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

  @override
  void initState() {
    super.initState();
    _keysFuture = widget.keyStore.listEntries();
    _vaultListener = () => setState(() {});
    widget.vault.addListener(_vaultListener);
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
  }

  Future<void> _handleAddKey() async {
    final label = _labelController.text.trim();
    final keyText = _keyController.text.trim();
    final password = _passwordController.text;
    if (label.isEmpty || keyText.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide label, key, and password.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    debugPrint('[Settings] Adding built-in key "$label"');
    try {
      await widget.keyStore.addEntry(
        label: label,
        keyData: utf8.encode(keyText),
        password: password,
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

  Future<void> _unlockKey(String keyId) async {
    final password = await _promptForPassword(context);
    if (password == null) {
      return;
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
        FutureBuilder<List<SshHost>>(
          future: widget.hostsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Unable to load hosts: ${snapshot.error}');
            }
            final hosts = snapshot.data ?? const [];
            if (hosts.isEmpty) {
              return const Text('No SSH hosts were detected.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Host to key bindings'),
                const SizedBox(height: 6),
                ...hosts.map((host) => _buildHostMapping(host)),
              ],
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
          decoration: const InputDecoration(labelText: 'Encryption password'),
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
    final isUnlocked = widget.vault.isUnlocked(entry.id);
    final fingerprint = entry.fingerprint.length > 12
        ? '${entry.fingerprint.substring(0, 12)}…'
        : entry.fingerprint;
    return ListTile(
      title: Text(entry.label),
      subtitle: Text('Fingerprint: $fingerprint'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: isUnlocked ? null : () => _unlockKey(entry.id),
            child: Text(isUnlocked ? 'Unlocked' : 'Unlock'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _removeKeyEntry(entry.id),
          ),
        ],
      ),
    );
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
