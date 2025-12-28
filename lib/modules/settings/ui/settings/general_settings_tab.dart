import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/models/input_mode_preference.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';
import '../../../../shared/theme/app_theme.dart';
import 'settings_section.dart';
import 'shortcuts_settings_tab.dart';

/// General settings tab widget
class GeneralSettingsTab extends StatelessWidget {
  const GeneralSettingsTab({
    super.key,
    required this.settings,
    required this.settingsController,
    required this.selectedTheme,
    required this.debugMode,
    required this.zoomFactor,
    required this.onThemeChanged,
    required this.onDebugModeChanged,
    required this.onZoomChanged,
    required this.appFontFamily,
    required this.onAppFontFamilyChanged,
    required this.appThemeKey,
    required this.onAppThemeChanged,
    required this.uiDensity,
    required this.onUiDensityChanged,
    required this.inputModePreference,
    required this.onInputModePreferenceChanged,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;
  final ThemeMode selectedTheme;
  final bool debugMode;
  final double zoomFactor;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<bool> onDebugModeChanged;
  final ValueChanged<double> onZoomChanged;
  final String? appFontFamily;
  final ValueChanged<String> onAppFontFamilyChanged;
  final String appThemeKey;
  final ValueChanged<String> onAppThemeChanged;
  final AppUiDensity uiDensity;
  final ValueChanged<AppUiDensity> onUiDensityChanged;
  final InputModePreference inputModePreference;
  final ValueChanged<InputModePreference> onInputModePreferenceChanged;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
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
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
              ),
              const FormSpacer(),
              TextFormField(
                initialValue: appFontFamily ?? '',
                decoration: const InputDecoration(
                  labelText: 'App font family',
                  hintText: 'JetBrainsMono Nerd Font',
                ),
                onChanged: onAppFontFamilyChanged,
              ),
              const FormSpacer(),
              DropdownButtonFormField<String>(
                initialValue: appThemeKey,
                decoration: const InputDecoration(labelText: 'App accent'),
                items: const [
                  DropdownMenuItem(
                    value: 'blue-grey',
                    child: Text('Blue Grey'),
                  ),
                  DropdownMenuItem(value: 'teal', child: Text('Teal')),
                  DropdownMenuItem(value: 'amber', child: Text('Amber')),
                  DropdownMenuItem(value: 'indigo', child: Text('Indigo')),
                  DropdownMenuItem(value: 'purple', child: Text('Purple')),
                  DropdownMenuItem(value: 'green', child: Text('Green')),
                ],
                onChanged: (value) {
                  if (value != null) onAppThemeChanged(value);
                },
              ),
              const FormSpacer(),
              DropdownButtonFormField<AppUiDensity>(
                decoration: const InputDecoration(labelText: 'Density'),
                initialValue: uiDensity,
                items: const [
                  DropdownMenuItem(
                    value: AppUiDensity.compact,
                    child: Text('Compact'),
                  ),
                  DropdownMenuItem(
                    value: AppUiDensity.comfy,
                    child: Text('Comfy'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onUiDensityChanged(value);
                },
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
          title: 'Transfers',
          description:
              'Limit how many files can upload or download at the same time.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Concurrent uploads: ${settings.fileTransferUploadConcurrency}',
              ),
              Slider(
                value: settings.fileTransferUploadConcurrency.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '${settings.fileTransferUploadConcurrency}',
                onChanged: (value) => settingsController.update(
                  (current) => current.copyWith(
                    fileTransferUploadConcurrency: value.round(),
                  ),
                ),
              ),
              const FormSpacer(),
              Text(
                'Concurrent downloads: '
                '${settings.fileTransferDownloadConcurrency}',
              ),
              Slider(
                value: settings.fileTransferDownloadConcurrency.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '${settings.fileTransferDownloadConcurrency}',
                onChanged: (value) => settingsController.update(
                  (current) => current.copyWith(
                    fileTransferDownloadConcurrency: value.round(),
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Input mode',
          description:
              'Choose whether gestures, keyboard shortcuts, or both are active.',
          child: DropdownButtonFormField<InputModePreference>(
            initialValue: inputModePreference,
            items: const [
              DropdownMenuItem(
                value: InputModePreference.auto,
                child: Text('Automatic (platform default)'),
              ),
              DropdownMenuItem(
                value: InputModePreference.gestures,
                child: Text('Gestures only'),
              ),
              DropdownMenuItem(
                value: InputModePreference.shortcuts,
                child: Text('Shortcuts only'),
              ),
              DropdownMenuItem(
                value: InputModePreference.both,
                child: Text('Gestures and shortcuts'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onInputModePreferenceChanged(value);
              }
            },
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
              children: [
                const Text('Enable SSH debug overlays'),
                SizedBox(width: spacing.md),
                const Tooltip(
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
        if (isDesktop)
          SettingsSection(
            title: 'Desktop window',
            description:
                'Control native window decorations (title bar and buttons).',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use system window decorations'),
              subtitle: const Text(
                'Turn off to use a custom/frameless window (where supported). Requires app restart.',
              ),
              value: settings.windowUseSystemDecorations,
              onChanged: (value) => settingsController.update(
                (current) =>
                    current.copyWith(windowUseSystemDecorations: value),
              ),
            ),
          ),
        ShortcutCategorySection(
          category: ShortcutCategory.global,
          controller: settingsController,
          settings: settings,
          titleOverride: 'Shortcuts',
          descriptionOverride:
              'App-wide shortcuts for zoom and common actions.',
        ),
      ],
    );
  }
}
