import 'package:flutter/material.dart';

import 'package:cwatch/app/controllers/settings_controller.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'settings_section.dart';
import 'server_list_settings_controls.dart';
import 'ssh_settings_controls.dart';

/// Servers settings tab widget
class ServersSettingsTab extends StatefulWidget {
  const ServersSettingsTab({super.key, required this.controller});

  final SettingsController controller;

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
    final spacing = context.appTheme.spacing;
    final settings = widget.controller.settings;

    return ListView(
      controller: _scrollController,
      padding: spacing.inset(horizontal: 2, vertical: 1),
      children: [
        SettingsSection(
          title: 'List View',
          description: 'Customize how servers are displayed in the list.',
          child: FutureBuilder<List<SshHost>>(
            future: widget.controller.hostsFuture,
            builder: (context, snapshot) {
              return ServerListSettingsControls(
                settings: settings,
                settingsController: widget.controller,
                hosts: snapshot.data,
              );
            },
          ),
        ),
        SettingsSection(
          title: 'SSH Client',
          description: 'Select the SSH backend and manage configuration files.',
          child: SshSettingsControls(controller: widget.controller),
        ),
      ],
    );
  }
}
