import 'package:flutter/material.dart';

import 'settings_section.dart';

/// Docker settings tab widget
class DockerSettingsTab extends StatelessWidget {
  const DockerSettingsTab({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        SettingsSection(
          title: 'Docker',
          description: 'Docker integrations are enabled by default.',
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No configurable Docker settings are available right now. Coming soon...',
            ),
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
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      children: [
        SettingsSection(
          title: 'Kubernetes',
          description: 'Kubernetes discovery runs automatically.',
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'There are no Kubernetes settings to configure at this time. Coming soon...',
            ),
          ),
        ),
      ],
    );
  }
}
