import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'settings_section.dart';
import 'docker_settings_controls.dart';
import 'kubernetes_settings_controls.dart';
import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';

/// Docker settings tab widget
class DockerSettingsTab extends StatelessWidget {
  const DockerSettingsTab({
    super.key,
    required this.logsTail,
    required this.onLogsTailChanged,
  });

  final int logsTail;
  final ValueChanged<int> onLogsTailChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 2, vertical: 1),
      children: [
        SettingsSection(
          title: 'Docker',
          description: 'Docker integrations are enabled by default.',
          child: DockerSettingsControls(
            logsTail: logsTail,
            onLogsTailChanged: onLogsTailChanged,
          ),
        ),
      ],
    );
  }
}

/// Kubernetes settings tab widget
class KubernetesSettingsTab extends StatelessWidget {
  const KubernetesSettingsTab({
    super.key,
    required this.settings,
    required this.settingsController,
  });

  final AppSettings settings;
  final AppSettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: spacing.inset(horizontal: 2, vertical: 1),
      children: [
        SettingsSection(
          title: 'Kubernetes',
          description: 'Manage kubeconfig files for context discovery.',
          child: KubernetesSettingsControls(
            settings: settings,
            settingsController: settingsController,
          ),
        ),
      ],
    );
  }
}
