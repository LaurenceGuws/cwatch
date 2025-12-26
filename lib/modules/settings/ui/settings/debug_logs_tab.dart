import 'package:flutter/material.dart';

import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';

class DebugLogsTab extends StatelessWidget {
  const DebugLogsTab({
    super.key,
    required this.logController,
    required this.debugEnabled,
  });

  final RemoteCommandLogController logController;
  final bool debugEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: logController,
      builder: (context, _) {
        final spacing = context.appTheme.spacing;
        final events = logController.events;
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.base * 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const FormSpacer(),
                  Text(
                    debugEnabled
                        ? 'No SSH activity logged yet.'
                        : 'Enable Debug Mode to capture SSH command logs.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: spacing.inset(horizontal: 3, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    debugEnabled ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: spacing.base * 1.5),
                  Text(
                    debugEnabled
                        ? 'Debug logging is ON'
                        : 'Debug logging is OFF',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: logController.clear,
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(spacing.lg),
                itemCount: events.length,
                separatorBuilder: (context, _) =>
                    SizedBox(height: spacing.base * 2.5),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _LogEntryCard(event: event);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({required this.event});

  final RemoteCommandDebugEvent event;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final verificationStatus = event.verificationPassed == null
        ? 'No verification run'
        : (event.verificationPassed!
              ? 'Verification passed'
              : 'Verification failed');
    final verificationColor = event.verificationPassed == null
        ? scheme.onSurfaceVariant
        : (event.verificationPassed! ? scheme.primary : scheme.error);

    return Card(
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '[${event.host.name}] ${event.operation}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(event.timestamp),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            SizedBox(height: spacing.md),
            SelectableText(
              'Command: ${event.command}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (event.output.isNotEmpty) ...[
              SizedBox(height: spacing.base * 1.5),
              SelectableText(
                'Output:\n${event.output}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (event.verificationCommand != null ||
                event.verificationOutput != null) ...[
              SizedBox(height: spacing.base * 1.5),
              SelectableText(
                'Check: ${event.verificationCommand ?? 'n/a'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (event.verificationOutput != null)
                SelectableText(
                  'Check output:\n${event.verificationOutput}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            SizedBox(height: spacing.base * 1.5),
            Text(
              verificationStatus,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: verificationColor),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
