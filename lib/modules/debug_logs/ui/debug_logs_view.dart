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

class _DebugLogsPanel extends StatefulWidget {
  const _DebugLogsPanel({required this.debugEnabled});

  final bool debugEnabled;

  @override
  State<_DebugLogsPanel> createState() => _DebugLogsPanelState();
}

class _DebugLogsPanelState extends State<_DebugLogsPanel> {
  final Map<RemoteCommandDebugEvent, ValueNotifier<bool>> _expandedRows = {};
  int? _sortColumnIndex;
  bool _sortAscending = true;

  ValueNotifier<bool> _expansionFor(RemoteCommandDebugEvent event) {
    return _expandedRows.putIfAbsent(event, () => ValueNotifier<bool>(false));
  }

  void _syncExpandedRows(List<RemoteCommandDebugEvent> events) {
    if (_expandedRows.isEmpty) {
      return;
    }
    final active = events.toSet();
    _expandedRows.removeWhere((event, _) => !active.contains(event));
  }

  @override
  void dispose() {
    for (final notifier in _expandedRows.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLogger.remoteCommandLog,
      builder: (context, _) {
        final spacing = context.appTheme.spacing;
        final rawEvents = AppLogger.remoteCommandLog.events;
        _syncExpandedRows(rawEvents);
        if (rawEvents.isEmpty) {
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
                    widget.debugEnabled
                        ? 'No command activity logged yet.'
                        : 'Enable Debug Mode to capture command logs.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final events = _sortedEvents(rawEvents);

        return Column(
          children: [
            Padding(
              padding: spacing.inset(horizontal: 3, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    widget.debugEnabled
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    widget.debugEnabled
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
                    width: 44,
                    alignment: Alignment.topCenter,
                    cellBuilder: (context, event) => _DetailsToggleCell(
                      expanded: _expansionFor(event),
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Level',
                    width: 90,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.level.index,
                    cellBuilder: (context, event) => _LevelCell(event: event),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Client',
                    width: 100,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.source,
                    cellBuilder: (context, event) => Text(
                      event.source,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Client Context',
                    width: 180,
                    wrap: true,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.contextLabel,
                    cellBuilder: (context, event) => Text(
                      event.contextLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Action',
                    flex: 1,
                    wrap: true,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.operation,
                    cellBuilder: (context, event) => _ActionCell(
                      event: event,
                      expanded: _expansionFor(event),
                    ),
                  ),
                  StructuredDataColumn<RemoteCommandDebugEvent>(
                    label: 'Time',
                    width: 90,
                    alignment: Alignment.topLeft,
                    sortValue: (event) => event.timestamp,
                    cellBuilder: (context, event) => Text(
                      _formatTimestamp(event.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                fitColumnsToWidth: true,
                headerHeight: 32,
                autoRowHeight: true,
                shrinkToContent: false,
                useZebraStripes: false,
                rowSelectionEnabled: false,
                enableKeyboardNavigation: false,
                onSortChanged: (columnIndex, ascending) {
                  setState(() {
                    _sortColumnIndex = columnIndex;
                    _sortAscending = ascending;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<RemoteCommandDebugEvent> _sortedEvents(
    List<RemoteCommandDebugEvent> events,
  ) {
    final columnIndex = _sortColumnIndex;
    if (columnIndex == null) {
      return events;
    }
    final columns = _columnsForSort();
    if (columnIndex < 0 || columnIndex >= columns.length) {
      return events;
    }
    final sortValue = columns[columnIndex];
    if (sortValue == null) {
      return events;
    }
    final sorted = [...events];
    sorted.sort((a, b) {
      final aValue = sortValue(a);
      final bValue = sortValue(b);
      final compare = _compareComparable(aValue, bValue);
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  List<Comparable<Object?>? Function(RemoteCommandDebugEvent)?>
  _columnsForSort() {
    return [
      null,
      (event) => event.level.index,
      (event) => event.source,
      (event) => event.contextLabel,
      (event) => event.operation,
      (event) => event.timestamp,
    ];
  }
}

class _DetailsToggleCell extends StatelessWidget {
  const _DetailsToggleCell({required this.expanded});

  final ValueNotifier<bool> expanded;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: expanded,
      builder: (context, isExpanded, _) => Padding(
        padding: EdgeInsets.only(top: spacing.xs),
        child: IconButton(
          tooltip: isExpanded ? 'Hide details' : 'Show details',
          iconSize: 18,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: scheme.primary,
          icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
          onPressed: () => expanded.value = !isExpanded,
        ),
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({required this.event});

  final RemoteCommandDebugEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final levelLabel = _levelLabel(event.level);
    final color = _levelColor(event.level, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        levelLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

class _ActionCell extends StatefulWidget {
  const _ActionCell({required this.event, required this.expanded});

  final RemoteCommandDebugEvent event;
  final ValueNotifier<bool> expanded;

  @override
  State<_ActionCell> createState() => _ActionCellState();
}

class _ActionCellState extends State<_ActionCell> {
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
    return ValueListenableBuilder<bool>(
      valueListenable: widget.expanded,
      builder: (context, isExpanded, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.operation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isExpanded) ...[
            SizedBox(height: spacing.sm),
            if (event.command.isNotEmpty)
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
        ],
      ),
    );
  }
}

String _levelLabel(LogLevel level) {
  switch (level) {
    case LogLevel.trace:
      return 'Trace';
    case LogLevel.debug:
      return 'Debug';
    case LogLevel.info:
      return 'Info';
    case LogLevel.warning:
      return 'Warn';
    case LogLevel.error:
      return 'Error';
    case LogLevel.critical:
      return 'Critical';
  }
}

Color _levelColor(LogLevel level, ColorScheme scheme) {
  switch (level) {
    case LogLevel.trace:
      return scheme.onSurfaceVariant;
    case LogLevel.debug:
      return scheme.onSurfaceVariant;
    case LogLevel.info:
      return scheme.primary;
    case LogLevel.warning:
      return scheme.tertiary;
    case LogLevel.error:
    case LogLevel.critical:
      return scheme.error;
  }
}

int _compareComparable(Comparable<Object?>? a, Comparable<Object?>? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

String _formatTimestamp(DateTime timestamp) {
  return '${timestamp.hour.toString().padLeft(2, '0')}:'
      '${timestamp.minute.toString().padLeft(2, '0')}:'
      '${timestamp.second.toString().padLeft(2, '0')}';
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
