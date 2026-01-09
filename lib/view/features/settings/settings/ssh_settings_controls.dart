import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/models/ssh_client_backend.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/form_spacer.dart';
import 'builtin_ssh_settings.dart';
import 'settings_section.dart';

class SshSettingsControls extends StatefulWidget {
  const SshSettingsControls({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SshSettingsControls> createState() => _SshSettingsControlsState();
}

class _SshSettingsControlsState extends State<SshSettingsControls> {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final settings = widget.controller.settings;
    final backend = settings.sshClientBackend;
    final usingBuiltIn = backend == SshClientBackend.builtin;
    final customConfigs = settings.customSshConfigPaths;
    final supportsPlatformSsh = widget.controller.supportsPlatformSsh;

    if (!supportsPlatformSsh && backend != SshClientBackend.builtin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.controller.ensureSupportedSshBackend();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supportsPlatformSsh)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: usingBuiltIn,
            onChanged: (value) {
              final target = value
                  ? SshClientBackend.builtin
                  : SshClientBackend.platform;
              widget.controller.setSshClientBackend(target);
            },
            title: Row(
              children: [
                const Expanded(child: Text('Use built-in SSH client')),
                SizedBox(width: spacing.md),
                const Tooltip(
                  message:
                      'When off, use the system SSH client and configs. When on, use the app key vault.',
                  preferBelow: false,
                  child: Icon(Icons.info_outline, size: 18),
                ),
              ],
            ),
          ),
        if (usingBuiltIn) BuiltInSshSettings(controller: widget.controller),
        const Divider(),
        SettingsSection(
          title: 'Detected SSH config files',
          description:
              'Toggle which ssh_config files are used when discovering hosts.',
          child: FutureBuilder<List<SshHost>>(
            future: widget.controller.hostsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: const LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Failed to load configs: ${snapshot.error}');
              }
              final hosts = snapshot.data ?? [];
              final sources =
                  hosts
                      .map((h) => h.source)
                      .whereType<String>()
                      .where((s) => s != 'custom')
                      .toSet()
                      .toList()
                    ..sort();
              if (sources.isEmpty) {
                return const Text('No ssh_config files were detected.');
              }
              final disabled = widget.controller.settings.disabledSshConfigPaths
                  .toSet();
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
        const Divider(),
        SettingsSection(
          title: 'SSH Config Files',
          description:
              'Add extra ssh_config files (e.g., from another device) without editing them manually.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: spacing.md,
                runSpacing: spacing.md,
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
              const FormSpacer(),
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

  Future<void> _pickConfigFile() => widget.controller.addSshConfigFile();

  Future<void> _removeConfigPath(String path) async {
    await widget.controller.removeSshConfigPath(path);
  }

  Future<void> _toggleConfigPath(
    String path,
    bool enabled,
    Set<String> disabled,
  ) async {
    await widget.controller.toggleSshConfigPath(path, enabled, disabled);
  }
}
