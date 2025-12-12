import 'package:flutter/material.dart';

import 'settings_section.dart';

/// Security settings tab widget
class SecuritySettingsTab extends StatelessWidget {
  const SecuritySettingsTab({
    super.key,
    required this.mfaRequired,
    required this.sshRotationEnabled,
    required this.auditStreamingEnabled,
    required this.onMfaChanged,
    required this.onSshRotationChanged,
    required this.onAuditStreamingChanged,
  });

  final bool mfaRequired;
  final bool sshRotationEnabled;
  final bool auditStreamingEnabled;
  final ValueChanged<bool> onMfaChanged;
  final ValueChanged<bool> onSshRotationChanged;
  final ValueChanged<bool> onAuditStreamingChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        SettingsSection(
          title: 'Access Controls',
          description: 'Protect operator access to critical resources.',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require MFA on sign-in'),
                subtitle: const Text(
                  'Users must register an authenticator app or security key.',
                ),
                value: mfaRequired,
                onChanged: onMfaChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enforce SSH key rotation'),
                subtitle: const Text(
                  'Keys older than 90 days automatically expire.',
                ),
                value: sshRotationEnabled,
                onChanged: onSshRotationChanged,
              ),
            ],
          ),
        ),
        SettingsSection(
          title: 'Auditing',
          description:
              'Stream live audit events to your SIEM or download manual exports.',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable audit log streaming'),
            subtitle: const Text(
              'Sends real-time events to the configured webhook endpoint.',
            ),
            value: auditStreamingEnabled,
            onChanged: onAuditStreamingChanged,
          ),
        ),
      ],
    );
  }
}
