import 'package:flutter/material.dart';

import '../../../../models/ssh_client_backend.dart';
import '../../../../services/settings/app_settings_controller.dart';
import '../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../../models/ssh_host.dart';
import 'builtin_ssh_settings.dart';
import 'settings_section.dart';

/// Servers settings tab widget
class ServersSettingsTab extends StatefulWidget {
  const ServersSettingsTab({
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
  State<ServersSettingsTab> createState() => _ServersSettingsTabState();
}

class _ServersSettingsTabState extends State<ServersSettingsTab> {
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
        SettingsSection(
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
        SettingsSection(
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
        SettingsSection(
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
                  title: const Text('Platform SSH client'),
                  subtitle: const Text(
                    'Use the operating system\'s ssh configuration and binaries.',
                  ),
                ),
                RadioListTile<SshClientBackend>(
                  value: SshClientBackend.builtin,
                  title: const Text('Built-in SSH client'),
                  subtitle: const Text(
                    'Use the app\'s encrypted key store (mobile-ready).',
                  ),
                ),
                if (usingBuiltIn)
                  BuiltInSshSettings(
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

