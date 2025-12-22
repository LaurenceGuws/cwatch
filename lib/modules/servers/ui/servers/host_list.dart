import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

import 'package:cwatch/models/custom_ssh_host.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
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
      return const Center(child: Text('No SSH hosts found.'));
    }

    Widget buildSection(String source, int index) {
      final hosts = grouped[source]!;
      final sectionColor = _sectionBackgroundForIndex(context, index);
      final collapsed = _isCollapsed(source);
      return Padding(
        padding: EdgeInsets.only(bottom: spacing.base * 1.5),
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
                icon: const Icon(Icons.settings, size: 18),
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
              : [_buildHostTable(hosts, surfaceColor: sectionColor)],
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

    return Column(children: [Expanded(child: list)]);
  }

  Widget _buildHostTable(List<SshHost> hosts, {required Color surfaceColor}) {
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
      emptyState: const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No servers in this group.'),
      ),
    );
  }

  List<StructuredDataColumn<SshHost>> _columns() {
    return [
      StructuredDataColumn<SshHost>(
        label: 'Distro',
        width: 64,
        autoFitText: (host) => labelForDistro(_slugForHost(host)),
        cellBuilder: _buildDistroCell,
      ),
      StructuredDataColumn<SshHost>(
        label: 'Name',
        autoFitText: (host) => host.name,
        cellBuilder: (context, host) =>
            Text(host.name, style: Theme.of(context).textTheme.titleMedium),
      ),
      StructuredDataColumn<SshHost>(
        label: 'Host',
        autoFitText: (host) => host.hostname,
        cellBuilder: (context, host) => Text(host.hostname),
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

  Widget _buildDistroCell(BuildContext context, SshHost host) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = host.available ? scheme.primary : scheme.error;
    final iconSize = _distroIconSize(context);
    final iconColor = colorForDistro(_slugForHost(host), context.appTheme);
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final slug = widget
            .settingsController
            .settings
            .serverDistroMap[hostDistroCacheKey(host)];
        return Tooltip(
          message: labelForDistro(slug),
          child: DistroLeadingSlot(
            slug: slug,
            iconSize: iconSize,
            iconColor: iconColor,
            statusColor: statusColor,
          ),
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
  ) {
    final selection = selected.isNotEmpty ? selected : [host];
    final canRemoveAll = selection.every(
      (item) => item is CustomSshHost || item.source == 'custom',
    );
    final singleSelection = selection.length == 1;

    return [
      StructuredDataMenuAction<SshHost>(
        label: 'Open terminal',
        icon: NerdIcon.terminal.data,
        enabled: singleSelection,
        onSelected: (_, primary) {
          if (widget.onOpenTerminal != null) {
            widget.onOpenTerminal!(primary);
          } else {
            widget.onActivate?.call(primary);
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Open file explorer',
        icon: NerdIcon.folderOpen.data,
        enabled: singleSelection,
        onSelected: (_, primary) {
          if (widget.onOpenExplorer != null) {
            widget.onOpenExplorer!(primary);
          } else {
            widget.onActivate?.call(primary);
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
        enabled: singleSelection,
        onSelected: (_, primary) => widget.onOpenConnectivity?.call(primary),
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Resources',
        icon: NerdIcon.database.data,
        enabled: singleSelection,
        onSelected: (_, primary) => widget.onOpenResources?.call(primary),
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Remove',
        icon: Icons.delete_outline,
        destructive: true,
        enabled: canRemoveAll,
        onSelected: (selectedRows, _) {
          if (!canRemoveAll) return;
          final current = widget.settingsController.settings;
          final removalNames = selectedRows.map((item) => item.name).toSet();
          final updated = [...current.customSshHosts]
            ..removeWhere((item) => removalNames.contains(item.name));
          widget.settingsController.update(
            (settings) => settings.copyWith(customSshHosts: updated),
          );
        },
      ),
    ];
  }

  List<String> _displayNames() => widget.hosts.map((h) => h.name).toList();

  double _distroIconSize(BuildContext context) {
    final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
    // Larger than text without overflowing the row.
    return titleSize * 1.9;
  }

  String? _slugForHost(SshHost host) {
    final settings = widget.settingsController.settings;
    return settings.serverDistroMap[hostDistroCacheKey(host)];
  }
}
