import 'package:flutter/material.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'settings_section.dart';
import 'shortcuts_settings_tab.dart';
import 'explorer_settings_controls.dart';

class ExplorerSettingsTab extends StatelessWidget {
  const ExplorerSettingsTab({
    super.key,
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingsSection(
          title: 'View',
          description:
              'Adjust density and navigation defaults for explorer tabs.',
          child: ExplorerSettingsControls(
            settings: settings,
            settingsController: settingsController,
          ),
        ),
        ShortcutCategorySection(
          category: ShortcutCategory.explorer,
          controller: settingsController,
          settings: settings,
          titleOverride: 'Explorer shortcuts',
          descriptionOverride: 'Configure bindings for explorer actions.',
        ),
      ],
    );
  }
}
