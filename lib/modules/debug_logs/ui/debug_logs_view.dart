import 'package:flutter/material.dart';

import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/form_spacer.dart';
import 'package:cwatch/shared/widgets/section_nav_bar.dart';

class DebugLogsView extends StatelessWidget {
  const DebugLogsView({
    super.key,
    required this.settingsController,
    this.leading,
  });

  final AppSettingsController settingsController;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;
        return Column(
          children: [
            SectionNavBar(
              title: 'Debug Logs',
              tabs: const [],
              showTitle: true,
              leading: leading,
              enableWindowDrag: !settings.windowUseSystemDecorations,
            ),
            Expanded(
              child: _DebugLogsPanel(
                debugEnabled: settings.debugMode,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DebugLogsPanel extends StatelessWidget {
  const _DebugLogsPanel({required this.debugEnabled});

  final bool debugEnabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLogger.remoteCommandLog,
      builder: (context, _) {
        final spacing = context.appTheme.spacing;
        final events = AppLogger.remoteCommandLog.events;
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.xl),
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
                        ? 'No command activity logged yet.'
                        : 'Enable Debug Mode to capture command logs.',
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
                  SizedBox(width: spacing.sm),
                  Text(
                    debugEnabled
                        ? 'Debug logging is ON'
                        : 'Debug logging is OFF',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: AppLogger.remoteCommandLog.clear,
                    icon: const Icon(Icons.delete_outlined),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StructuredDataTable<RemoteCommandDebugEvent>(
                rows: events,
                columns: [
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: '',
                    flex: 1,
                    wrap: true,
                    alignment: Alignment.topLeft,
                    cellBuilder: (context, event) => RepaintBoundary(
                      child: KeyedSubtree(
                        key: ValueKey(event.timestamp),
                        child: _LogEntryRow(event: event),
                      ),
                    ),
                  ),
                ],
                fitColumnsToWidth: true,
                headerHeight: 0,
                autoRowHeight: true,
                shrinkToContent: false,
                useZebraStripes: false,
                rowSelectionEnabled: false,
                enableKeyboardNavigation: false,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogEntryRow extends StatefulWidget {
  const _LogEntryRow({required this.event});

  final RemoteCommandDebugEvent event;

  @override
  State<_LogEntryRow> createState() => _LogEntryRowState();
}

class _LogEntryRowState extends State<_LogEntryRow> {
  bool _showCommand = false;
  bool _showOutput = false;
  bool _showVerification = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
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

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _titleFor(event),
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
          _CollapsibleSection(
            label: 'Command',
            isExpanded: _showCommand,
            onToggle: () => setState(() => _showCommand = !_showCommand),
            maxExpandedHeight: 140,
            child: SelectableText(
              event.command,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (event.output.isNotEmpty) ...[
            SizedBox(height: spacing.base * 1.5),
            _CollapsibleSection(
              label: 'Output',
              isExpanded: _showOutput,
              onToggle: () => setState(() => _showOutput = !_showOutput),
              maxExpandedHeight: 240,
              child: SelectableText(
                event.output,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (event.verificationCommand != null ||
              event.verificationOutput != null) ...[
            SizedBox(height: spacing.base * 1.5),
            _CollapsibleSection(
              label: 'Verification',
              isExpanded: _showVerification,
              onToggle: () =>
                  setState(() => _showVerification = !_showVerification),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    'Check: ${event.verificationCommand ?? 'n/a'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.verificationOutput != null)
                    Padding(
                      padding: EdgeInsets.only(top: spacing.sm),
                      child: SelectableText(
                        'Check output:\n${event.verificationOutput}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
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
    );
  }

  String _titleFor(RemoteCommandDebugEvent event) {
    final hostLabel = event.host?.name;
    if (hostLabel == null || hostLabel.isEmpty) {
      return '[${event.source}] ${event.operation}';
    }
    return '[${event.source}] $hostLabel · ${event.operation}';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.maxExpandedHeight,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;
  final double? maxExpandedHeight;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final expandedBody = maxExpandedHeight == null
        ? child
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxExpandedHeight!),
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.primary,
                ),
                SizedBox(width: spacing.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: EdgeInsets.only(left: spacing.lg),
            child: expandedBody,
          ),
      ],
    );
  }
}
