import 'package:flutter/material.dart';
import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

class ServerListSettingsControls extends StatelessWidget {
  const ServerListSettingsControls({
    super.key,
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Show Offline Servers'),
          value: settings.serverShowOffline,
          onChanged: (value) => settingsController.update(
            (s) => s.copyWith(serverShowOffline: value),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Auto Refresh'),
          value: settings.serverAutoRefresh,
          onChanged: (value) => settingsController.update(
            (s) => s.copyWith(serverAutoRefresh: value),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
