import 'package:flutter/material.dart';

import 'package:cwatch/models/custom_ssh_host.dart';

import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/widgets/standard_empty_state.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';
import 'package:cwatch/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/modules/servers/services/host_distro_key.dart';
import 'package:cwatch/services/logging/app_logger.dart';

/// Host list widget that displays SSH hosts grouped by source
class HostList extends StatefulWidget {
  const HostList({
    super.key,
    required this.hosts,
    required this.onSelect,
    required this.onActivate,
    required this.settingsController,
    required this.onHostsChanged,
    required this.onAddServer,
    this.onOpenConnectivity,
    this.onOpenResources,
    this.onOpenTerminal,
    this.onOpenExplorer,
    this.onOpenPortForward,
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost>? onActivate;
  final AppSettingsController settingsController;
  final VoidCallback onHostsChanged;
  final ValueChanged<List<String>> onAddServer;
  final ValueChanged<SshHost>? onOpenConnectivity;
  final ValueChanged<SshHost>? onOpenResources;
  final ValueChanged<SshHost>? onOpenTerminal;
  final ValueChanged<SshHost>? onOpenExplorer;
  final ValueChanged<SshHost>? onOpenPortForward;

  @override
  State<HostList> createState() => _HostListState();
}

class _HostListState extends State<HostList> {
  final Map<String, bool> _collapsedBySource = {};
  final Set<String> _selectedHostKeys = {};
  int _lastHostCount = -1;

  Map<String, List<SshHost>> _groupHostsBySource() {
    final grouped = <String, List<SshHost>>{};
    for (final host in widget.hosts) {
      final source = host.source ?? 'unknown';
      grouped.putIfAbsent(source, () => []).add(host);
    }
    return grouped;
  }

  String _getSourceDisplayName(String source) {
    if (source == 'custom') {
      return 'Added Servers';
    }
    final parts = source.split('/');
    return parts.last;
  }

  bool _isCollapsed(String source) => _collapsedBySource[source] ?? false;

  void _toggleCollapsed(String source) {
    setState(() {
      _collapsedBySource[source] = !(_collapsedBySource[source] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final grouped = _groupHostsBySource();
    final sources = grouped.keys.toList()..sort();
    if (_lastHostCount != widget.hosts.length) {
      _lastHostCount = widget.hosts.length;
      AppLogger.d(
        'HostList rebuild: hosts=${widget.hosts.length}',
        tag: 'ServersList',
      );
    }

    if (widget.hosts.isEmpty) {
      return const StandardEmptyState(
        message: 'No SSH hosts found.',
        icon: Icons.dns,
      );
    }

    Widget buildSection(String source, int index) {
      final hosts = grouped[source]!;
      final sectionColor = _sectionBackgroundForIndex(context, index);
      final collapsed = _isCollapsed(source);
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.sm),
        child: SectionList(
          backgroundColor: sectionColor,
          title: _getSourceDisplayName(source),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 18,
                ),
                tooltip: collapsed ? 'Expand' : 'Collapse',
                onPressed: () => _toggleCollapsed(source),
              ),
              PopupMenuButton<String>(
                tooltip: 'Section options',
                icon: const Icon(Icons.more_horiz, size: 18),

                onSelected: (value) {
                  if (value == 'reloadHosts') {
                    widget.onHostsChanged();
                    return;
                  }
                  if (value == 'editConfig') {
                    ExternalAppLauncher.openConfigFile(source, context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'reloadHosts',
                    child: Text('Reload server list'),
                  ),
                  PopupMenuItem<String>(
                    value: 'editConfig',
                    enabled: source != 'custom',
                    child: const Text('Edit config file'),
                  ),
                ],
              ),
            ],
          ),
          children: collapsed
              ? const []
              : [
                  _buildHostTable(context, hosts, surfaceColor: sectionColor),
                ],
        ),
      );
    }

    final list = sources.length == 1
        ? buildSection(sources.first, 0)
        : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: sources.length,
            itemBuilder: (context, index) =>
                buildSection(sources[index], index),
          );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.base),
      child: Column(children: [Expanded(child: list)]),
    );
  }

  String _hostSelectionKey(SshHost host) => hostDistroCacheKey(host);

  void _syncSelection(List<SshHost> hosts, List<SshHost> selected) {
    final tableKeys = hosts.map(_hostSelectionKey).toSet();
    _selectedHostKeys
      ..removeAll(tableKeys)
      ..addAll(selected.map(_hostSelectionKey));
  }

  List<SshHost> _selectedHostsForAction(SshHost fallback) {
    final selected = widget.hosts
        .where((host) => _selectedHostKeys.contains(_hostSelectionKey(host)))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  Widget _buildHostTable(
    BuildContext context,
    List<SshHost> hosts, {
    required Color surfaceColor,
  }) {
    final spacing = context.appTheme.spacing;
    return StructuredDataTable<SshHost>(
      rows: hosts,
      columns: _columns(),
      rowHeight: 64,
      shrinkToContent: true,
      primaryDoubleClickOpensContextMenu: true,
      useZebraStripes: false,
      surfaceBackgroundColor: surfaceColor,
      onRowTap: (host) => widget.onSelect?.call(host),
      onRowDoubleTap: (host) => widget.onActivate?.call(host),
      refreshListenable: widget.settingsController,
      rowContextMenuBuilder: _buildContextMenuActions,
      onSelectionChanged: (selectedRows) {
        _syncSelection(hosts, selectedRows);
      },
      emptyState: Padding(
        padding: EdgeInsets.all(spacing.xl),
        child: const StandardEmptyState(message: 'No servers in this group.'),
      ),
    );
  }

  List<StructuredDataColumn<SshHost>> _columns() {
    return [
      StructuredDataColumn<SshHost>(
        label: 'Server',
        autoFitText: (host) => '${host.name} ${host.hostname}',
        cellBuilder: _buildCombinedCell,
      ),
      StructuredDataColumn<SshHost>(
        label: 'Port',
        autoFitText: (host) => host.port.toString(),
        cellBuilder: (context, host) => Text('${host.port}'),
        alignment: Alignment.centerRight,
      ),
      StructuredDataColumn<SshHost>(
        label: 'User',
        autoFitText: (host) => host.user ?? '',
        cellBuilder: (context, host) => Text(host.user ?? '-'),
      ),
    ];
  }

  Widget _buildCombinedCell(BuildContext context, SshHost host) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final statusColor = host.available ? scheme.primary : scheme.error;
    final iconSize = _distroIconSize(context);
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final slug = widget
            .settingsController
            .settings
            .serverDistroMap[hostDistroCacheKey(host)];
        final iconColor = colorForDistro(slug, context.appTheme);
        return Row(
          children: [
            Tooltip(
              message: labelForDistro(slug),
              child: DistroLeadingSlot(
                slug: slug,
                iconSize: iconSize,
                iconColor: iconColor,
                statusColor: statusColor,
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    host.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    host.hostname,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.appTheme.section.surface.background;
    final overlay = scheme.surfaceTint.withValues(alpha: 0.08);
    final alternate = Color.alphaBlend(overlay, base);
    return index.isEven ? base : alternate;
  }

  List<StructuredDataMenuAction<SshHost>> _buildContextMenuActions(
    SshHost host,
    List<SshHost> selected,
    Offset? anchor,
  ) {
    final selection = _selectedHostsForAction(host);
    final canRemoveAll = selection.every(
      (item) => item is CustomSshHost || item.source == 'custom',
    );
    final singleSelection = selection.length == 1;

    return [
      StructuredDataMenuAction<SshHost>(
        label: 'Open terminal',
        icon: NerdIcon.terminal.data,
        enabled: selection.isNotEmpty,
        onSelected: (_, _) {
          for (final target in selection) {
            if (widget.onOpenTerminal != null) {
              widget.onOpenTerminal!(target);
            } else if (target == selection.first) {
              widget.onActivate?.call(target);
            }
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Open file explorer',
        icon: NerdIcon.folderOpen.data,
        enabled: selection.isNotEmpty,
        onSelected: (_, _) {
          for (final target in selection) {
            if (widget.onOpenExplorer != null) {
              widget.onOpenExplorer!(target);
            } else if (target == selection.first) {
              widget.onActivate?.call(target);
            }
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Port forwarding',
        icon: Icons.link,
        enabled: singleSelection,
        onSelected: (_, primary) => widget.onOpenPortForward?.call(primary),
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Connectivity',
        icon: NerdIcon.accessPoint.data,
        enabled: selection.isNotEmpty,
        onSelected: (_, _) {
          for (final target in selection) {
            widget.onOpenConnectivity?.call(target);
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Resources',
        icon: NerdIcon.database.data,
        enabled: selection.isNotEmpty,
        onSelected: (_, _) {
          for (final target in selection) {
            widget.onOpenResources?.call(target);
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Remove',
        icon: Icons.delete_outline,
        destructive: true,
        enabled: canRemoveAll,
        onSelected: (_, _) {
          if (!canRemoveAll) return;
          final current = widget.settingsController.settings;
          final removalNames = selection.map((item) => item.name).toSet();
          final updated = [...current.customSshHosts]
            ..removeWhere((item) => removalNames.contains(item.name));
          widget.settingsController.update(
            (settings) => settings.copyWith(customSshHosts: updated),
          );
        },
      ),
    ];
  }

  double _distroIconSize(BuildContext context) {
    final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
    // Larger than text without overflowing the row.
    return titleSize * 1.9;
  }

}
