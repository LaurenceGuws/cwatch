import 'package:flutter/material.dart';

import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'settings_section.dart';
import 'server_list_settings_controls.dart';
import 'ssh_settings_controls.dart';

/// Servers settings tab widget
class ServersSettingsTab extends StatefulWidget {
  const ServersSettingsTab({
    super.key,
    required this.controller,
    required this.hostsFuture,
    required this.keyService,
  });

  final AppSettingsController controller;
  final Future<List<SshHost>> hostsFuture;
  final BuiltInSshKeyService keyService;

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
          child: ServerListSettingsControls(
            settings: settings,
            settingsController: widget.controller,
          ),
        ),
        SettingsSection(
          title: 'SSH Client',
          description:
              'Select the SSH backend and manage configuration files.',
          child: SshSettingsControls(
            controller: widget.controller,
            hostsFuture: widget.hostsFuture,
            keyService: widget.keyService,
          ),
        ),
      ],
    );
  }
}
