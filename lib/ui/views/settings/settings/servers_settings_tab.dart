import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

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
    required this.controller,
    required this.hostsFuture,
    required this.builtInKeyStore,
    required this.builtInVault,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyStore builtInKeyStore;
  final BuiltInSshVault builtInVault;

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
    final customConfigs = settings.customSshConfigPaths;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
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
        SettingsSection(
          title: 'Detected SSH config files',
          description:
              'Toggle which ssh_config files are used when discovering hosts.',
          child: FutureBuilder<List<SshHost>>(
            future: widget.hostsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Failed to load configs: ${snapshot.error}');
              }
              final hosts = snapshot.data ?? [];
              final sources = hosts
                  .map((h) => h.source)
                  .whereType<String>()
                  .where((s) => s != 'custom')
                  .toSet()
                  .toList()
                ..sort();
              if (sources.isEmpty) {
                return const Text('No ssh_config files were detected.');
              }
              final disabled =
                  widget.controller.settings.disabledSshConfigPaths.toSet();
              return Column(
                children: sources
                    .map(
                      (path) => SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.basename(path)),
                        subtitle: Text(path),
                        value: !disabled.contains(path),
                        onChanged: (enabled) =>
                            _toggleConfigPath(path, enabled, disabled),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        SettingsSection(
          title: 'SSH Config Files',
          description:
              'Add extra ssh_config files (e.g., from another device) without editing them manually.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final path in customConfigs)
                    InputChip(
                      label: Text(p.basename(path)),
                      tooltip: path,
                      onDeleted: () => _removeConfigPath(path),
                    ),
                  if (customConfigs.isEmpty)
                    const Text('No additional config files added yet.'),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Add SSH config file'),
                  onPressed: _pickConfigFile,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickConfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select ssh_config file',
      allowMultiple: false,
    );
    final path =
        (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path == null) {
      return;
    }
    final current = widget.controller.settings.customSshConfigPaths;
    if (current.contains(path)) {
      _showSnack('Config already added');
      return;
    }
    await widget.controller.update(
      (settings) => settings.copyWith(
        customSshConfigPaths: [...current, path],
      ),
    );
    _showSnack('Added SSH config: ${p.basename(path)}');
  }

  Future<void> _removeConfigPath(String path) async {
    final current = widget.controller.settings.customSshConfigPaths;
    final next = [...current]..remove(path);
    await widget.controller.update(
      (settings) => settings.copyWith(customSshConfigPaths: next),
    );
    _showSnack('Removed config');
  }

  Future<void> _toggleConfigPath(
    String path,
    bool enabled,
    Set<String> disabled,
  ) async {
    final next = disabled.toSet();
    if (enabled) {
      next.remove(path);
    } else {
      next.add(path);
    }
    await widget.controller.update(
      (settings) => settings.copyWith(
        disabledSshConfigPaths: next.toList(),
      ),
    );
    _showSnack(enabled ? 'Enabled $path' : 'Disabled $path');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
