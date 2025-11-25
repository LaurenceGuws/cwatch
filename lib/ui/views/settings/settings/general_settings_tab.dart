import 'package:flutter/material.dart';

import 'editor_settings_section.dart';
import 'settings_section.dart';
import 'terminal_settings_section.dart';

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
    required this.terminalFontFamily,
    required this.terminalFontSize,
    required this.terminalLineHeight,
    required this.onTerminalFontFamilyChanged,
    required this.onTerminalFontSizeChanged,
    required this.onTerminalLineHeightChanged,
    required this.editorFontFamily,
    required this.editorFontSize,
    required this.editorLineHeight,
    required this.onEditorFontFamilyChanged,
    required this.onEditorFontSizeChanged,
    required this.onEditorLineHeightChanged,
    required this.appFontFamily,
    required this.onAppFontFamilyChanged,
  });

  final ThemeMode selectedTheme;
  final bool debugMode;
  final double zoomFactor;
  final String? terminalFontFamily;
  final double terminalFontSize;
  final double terminalLineHeight;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onDebugModeChanged;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<String> onTerminalFontFamilyChanged;
  final ValueChanged<double> onTerminalFontSizeChanged;
  final ValueChanged<double> onTerminalLineHeightChanged;
  final String? editorFontFamily;
  final double editorFontSize;
  final double editorLineHeight;
  final ValueChanged<String> onEditorFontFamilyChanged;
  final ValueChanged<double> onEditorFontSizeChanged;
  final ValueChanged<double> onEditorLineHeightChanged;
  final String? appFontFamily;
  final ValueChanged<String> onAppFontFamilyChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        SettingsSection(
          title: 'Theme',
          description: 'Switch between light, dark, or system themes.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<ThemeMode>(
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
              const SizedBox(height: 12),
              TextFormField(
                initialValue: appFontFamily ?? '',
                decoration: const InputDecoration(
                  labelText: 'App font family',
                  hintText: 'JetBrainsMono Nerd Font',
                ),
                onChanged: onAppFontFamilyChanged,
              ),
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
        TerminalSettingsSection(
          fontFamily: terminalFontFamily,
          fontSize: terminalFontSize,
          lineHeight: terminalLineHeight,
          onFontFamilyChanged: onTerminalFontFamilyChanged,
          onFontSizeChanged: onTerminalFontSizeChanged,
          onLineHeightChanged: onTerminalLineHeightChanged,
        ),
        EditorSettingsSection(
          fontFamily: editorFontFamily,
          fontSize: editorFontSize,
          lineHeight: editorLineHeight,
          onFontFamilyChanged: onEditorFontFamilyChanged,
          onFontSizeChanged: onEditorFontSizeChanged,
          onLineHeightChanged: onEditorLineHeightChanged,
        ),
      ],
    );
  }
}
