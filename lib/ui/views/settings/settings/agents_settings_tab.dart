import 'package:flutter/material.dart';

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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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

