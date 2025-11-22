import 'package:flutter/material.dart';

import 'settings_section.dart';

/// General settings tab widget
class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({
    super.key,
    required this.selectedTheme,
    required this.debugMode,
    required this.zoomFactor,
    required this.onThemeChanged,
    required this.onDebugModeChanged,
    required this.onZoomChanged,
  });

  final ThemeMode selectedTheme;
  final bool debugMode;
  final double zoomFactor;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onDebugModeChanged;
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
          title: 'Debug Mode',
          description:
              'Show command feedback and verification steps in the UI when running SSH operations.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            subtitle: null,
            title: Row(
              children: const [
                Text('Enable SSH debug overlays'),
                SizedBox(width: 8),
                Tooltip(
                  message:
                      'Displays commands, raw output, and post-action checks like file existence verification.',
                  preferBelow: false,
                  child: Icon(Icons.info_outline, size: 18),
                ),
              ],
            ),
            value: debugMode,
            onChanged: onDebugModeChanged,
          ),
        ),
      ],
    );
  }
}
