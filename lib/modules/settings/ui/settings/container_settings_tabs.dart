import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_section.dart';

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        SettingsSection(
          title: 'Docker',
          description: 'Docker integrations are enabled by default.',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              key: ValueKey(logsTail),
              initialValue: logsTail.toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Default log tail',
                helperText:
                    'Number of lines to fetch when opening Docker logs (set 0 to only stream new lines).',
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed == null) return;
                final clamped = parsed.clamp(0, 5000).toInt();
                onLogsTailChanged(clamped);
              },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        SettingsSection(
          title: 'Kubernetes',
          description: 'Kubernetes discovery runs automatically.',
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No Kubernetes settings to configure yet.',
            ),
          ),
        ),
      ],
    );
  }
}
