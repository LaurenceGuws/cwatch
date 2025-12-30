import 'package:flutter/material.dart';

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/shortcuts/shortcut_definition.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';
import 'settings_section.dart';
import 'shortcuts_settings_tab.dart';

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
          description: 'Adjust density and navigation defaults for explorer tabs.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliderRow(
                label: 'Row height',
                valueLabel: settings.explorerRowHeight.toStringAsFixed(0),
                child: Slider(
                  value: settings.explorerRowHeight.clamp(24, 88).toDouble(),
                  min: 24,
                  max: 88,
                  divisions: 16,
                  label: settings.explorerRowHeight.toStringAsFixed(0),
                  onChanged: (value) => settingsController.update(
                    (current) => current.copyWith(explorerRowHeight: value),
                  ),
                ),
              ),
              const FormSpacer(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show breadcrumbs by default'),
                subtitle: const Text(
                  'Turn off to default to the editable path field.',
                ),
                value: settings.explorerShowBreadcrumbs,
                onChanged: (value) => settingsController.update(
                  (current) =>
                      current.copyWith(explorerShowBreadcrumbs: value),
                ),
              ),
            ],
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

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.child,
  });

  final String label;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(valueLabel),
          ],
        ),
        child,
      ],
    );
  }
}
