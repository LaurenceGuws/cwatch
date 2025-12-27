import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'settings_section.dart';

/// Agents settings tab widget
class AgentsSettingsTab extends StatelessWidget {
  const AgentsSettingsTab({
    super.key,
    required this.autoUpdateAgents,
    required this.agentAlertsEnabled,
    required this.agents,
    required this.onAutoUpdateChanged,
    required this.onAgentAlertsChanged,
  });

  final bool autoUpdateAgents;
  final bool agentAlertsEnabled;
  final List<(String, String, String)> agents;
  final ValueChanged<bool> onAutoUpdateChanged;
  final ValueChanged<bool> onAgentAlertsChanged;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * 3,
        vertical: spacing.base * 2.5,
      ),
      children: [
        SettingsSection(
          title: 'Agent Fleet',
          description: 'Keep agents healthy with automatic patches and alerts.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-update agents'),
                subtitle: const Text(
                  'Roll out patches when new firmware is published.',
                ),
                value: autoUpdateAgents,
                onChanged: onAutoUpdateChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alert when agents go offline'),
                subtitle: const Text(
                  'Send notifications if an agent misses a heartbeat.',
                ),
                value: agentAlertsEnabled,
                onChanged: onAgentAlertsChanged,
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Connected Agents',
          description:
              'Review firmware versions and last heartbeat per device.',
          child: Column(
            children: agents
                .map(
                  (agent) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(agent.$1),
                    subtitle: Text(agent.$2),
                    trailing: Text(agent.$3),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
