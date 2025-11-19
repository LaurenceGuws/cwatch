import 'package:flutter/material.dart';

import 'settings_section.dart';

/// General settings tab widget
class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({
    super.key,
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
        SettingsSection(
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
        SettingsSection(
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
        SettingsSection(
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
        SettingsSection(
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

