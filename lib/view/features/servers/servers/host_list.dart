import 'package:flutter/material.dart';

import 'package:cwatch/model/models/custom_ssh_host.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/view/features/servers/servers/add_server_dialog.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/distro_icons.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';
import 'package:cwatch/controller/adapters/external_app_launcher.dart';
import 'package:cwatch/view/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

/// Host list widget that displays SSH hosts grouped by source
class HostList extends StatefulWidget {
  const HostList({
    super.key,
    required this.hosts,
    required this.onSelect,
    required this.onActivate,
    required this.settingsController,
    required this.distroCacheController,
    required this.keyService,
    required this.onHostsChanged,
    required this.onAddServer,
    required this.showDisabledServers,
    required this.onToggleDisabledServersVisibility,
    this.onOpenConnectivity,
    this.onOpenResources,
    this.onOpenTerminal,
    this.onOpenExplorer,
    this.onOpenPortForward,
    this.onHostVisible,
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost>? onActivate;
  final AppSettingsController settingsController;
  final DistroCacheController distroCacheController;
  final BuiltInSshKeyService keyService;
  final VoidCallback onHostsChanged;
  final ValueChanged<List<String>> onAddServer;
  final bool showDisabledServers;
  final VoidCallback onToggleDisabledServersVisibility;
  final ValueChanged<SshHost>? onOpenConnectivity;
  final ValueChanged<SshHost>? onOpenResources;
  final ValueChanged<SshHost>? onOpenTerminal;
  final ValueChanged<SshHost>? onOpenExplorer;
  final ValueChanged<SshHost>? onOpenPortForward;
  final ValueChanged<SshHost>? onHostVisible;

  @override
  State<HostList> createState() => _HostListState();
}

class _HostListState extends State<HostList> {
  final Map<String, bool> _collapsedBySource = {};
  final Set<String> _selectedHostKeys = {};
  int _lastHostCount = -1;
  late bool _showDisabledServers;
  late final String _instanceId;
  final Map<String, int> _lastSectionRowCounts = {};
  // Per-section toggle state - each section can independently show/hide disabled servers
  final Map<String, bool> _showDisabledBySection = {};
  
  @override
  void initState() {
    super.initState();
    _instanceId = '${DateTime.now().microsecondsSinceEpoch}-$hashCode';
    _showDisabledServers = widget.showDisabledServers;
    AppLogger().debug(
      'HostList instance created: $_instanceId',
      tag: 'ServersList',
    );
  }
  
  @override
  void didUpdateWidget(HostList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showDisabledServers != widget.showDisabledServers) {
      _showDisabledServers = widget.showDisabledServers;
    }
  }
  

  Map<String, List<SshHost>> _groupHostsBySource(List<SshHost> hosts) {
    final grouped = <String, List<SshHost>>{};
    for (final host in hosts) {
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
    // Get all hosts (unfiltered) - filtering will happen per-section
    final allHosts = widget.hosts;
    final grouped = _groupHostsBySource(allHosts);
    final sources = grouped.keys.toList()..sort();
    final totalVisibleHosts = grouped.values.expand((h) => h).length;
    if (_lastHostCount != totalVisibleHosts) {
      _lastHostCount = totalVisibleHosts;
      AppLogger().debug(
        'HostList rebuild - Instance: $_instanceId, total hosts=$totalVisibleHosts',
        tag: 'ServersList',
      );
    }

    if (allHosts.isEmpty) {
      return const StandardEmptyState(
        message: 'No SSH hosts found.',
        icon: Icons.dns,
      );
    }

    Widget buildSection(String source, int index) {
      final allSectionHosts = grouped[source]!;
      // Filter hosts for this specific section based on its own toggle state
      final sectionShowDisabled = _showDisabledBySection[source] ?? _showDisabledServers;
      final sectionHosts = sectionShowDisabled
          ? allSectionHosts
          : allSectionHosts
              .where((host) => !_isHostDisabled(host))
              .toList();
      
      final sectionColor = _sectionBackgroundForIndex(context, index);
      final collapsed = _isCollapsed(source);
      final lastRowCount = _lastSectionRowCounts[source];
      final rowCountChanged = lastRowCount != sectionHosts.length;
      if (rowCountChanged) {
        _lastSectionRowCounts[source] = sectionHosts.length;
        AppLogger().debug(
          'Section $source row count changed: $lastRowCount -> ${sectionHosts.length}, Instance: $_instanceId',
          tag: 'ServersList',
        );
      }
      
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
                  if (value == 'toggleDisabled') {
                    final currentState = _showDisabledBySection[source] ?? _showDisabledServers;
                    final newState = !currentState;
                    AppLogger().debug(
                      'Toggle disabled servers - Instance: $_instanceId, Section: $source, Current: $currentState -> $newState',
                      tag: 'ServersList',
                    );
                    // Only update this specific section's state
                    setState(() {
                      _showDisabledBySection[source] = newState;
                      // Clear cache for this section only
                      _lastSectionRowCounts.remove(source);
                    });
                    // Don't call parent callback - state is managed locally per section
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
                    value: 'toggleDisabled',
                    child: Text(
                      (_showDisabledBySection[source] ?? _showDisabledServers)
                          ? 'Hide disabled servers'
                          : 'Show disabled servers',
                    ),
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
              : [_buildHostTable(context, sectionHosts, surfaceColor: sectionColor, sourceKey: source)],
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

  String _hostSelectionKey(SshHost host) => hostDisableKey(host);

  void _syncSelection(List<SshHost> hosts, List<SshHost> selected) {
    final tableKeys = hosts.map(_hostSelectionKey).toSet();
    _selectedHostKeys
      ..removeAll(tableKeys)
      ..addAll(selected.map(_hostSelectionKey));
  }

  Set<String> _disabledHostKeys() =>
      widget.settingsController.settings.disabledServerHosts.toSet();

  bool _matchesDisabledKey(SshHost host, Set<String> disabled) =>
      disabled.any((key) => disabledKeyMatchesHost(key, host));

  bool _isHostDisabled(SshHost host) =>
      _matchesDisabledKey(host, _disabledHostKeys());

  Future<void> _setHostsDisabled(List<SshHost> hosts, bool disabled) async {
    final current = _disabledHostKeys();
    final next = {...current}
      ..removeWhere(
        (key) => hosts.any((host) => disabledKeyMatchesHost(key, host)),
      );
    if (disabled) {
      next.addAll(hosts.map(canonicalDisabledHostKey));
    }
    await widget.settingsController.update(
      (settings) => settings.copyWith(disabledServerHosts: next.toList()),
    );
    AppLogger().debug(
      '${disabled ? 'Disabled' : 'Enabled'} ${hosts.length} server(s)',
      tag: 'ServersList',
    );
  }

  Widget _buildHostTable(
    BuildContext context,
    List<SshHost> hosts, {
    required Color surfaceColor,
    required String sourceKey,
  }) {
    final spacing = context.appTheme.spacing;
    final tableKey = ValueKey('host-table-$sourceKey');
    final lastRowCount = _lastSectionRowCounts[sourceKey];
    final rowCountChanged = lastRowCount != hosts.length;
    
    if (rowCountChanged || lastRowCount == null) {
      AppLogger().debug(
        'Building table for section: $sourceKey, rows: ${hosts.length} (was: $lastRowCount), Instance: $_instanceId',
        tag: 'ServersList',
      );
    }
    
    // Use a stable key per section source to avoid unnecessary rebuilds across tabs
    // The key stays the same for a given source, allowing the table to update rows efficiently
    return StructuredDataTable<SshHost>(
      key: tableKey,
      rows: hosts,
      columns: _columns(),
      rowHeight: context.scale(64),
      shrinkToContent: true,
      primaryDoubleClickOpensContextMenu: true,
      useZebraStripes: false,
      surfaceBackgroundColor: surfaceColor,
      onRowTap: (host) {
        widget.onHostVisible?.call(host);
        widget.onSelect?.call(host);
      },
      onRowDoubleTap: (host) {
        if (_isHostDisabled(host)) {
          return;
        }
        widget.onHostVisible?.call(host);
        widget.onActivate?.call(host);
      },
      onRowPointerEnter: (index, host, event) {
        // Trigger distro detection when row is hovered
        widget.onHostVisible?.call(host);
      },
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
      animation: widget.distroCacheController,
      builder: (context, _) {
        final slug = widget.distroCacheController.serverSlug(
          hostDistroCacheKey(host),
        );
        final iconColor = colorForDistro(slug, context.appTheme);
        final isDisabled = _isHostDisabled(host);
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
                  Flexible(
                    child: Text(
                      host.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: host.hostname,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(height: 1.0),
                        children: [
                          if (isDisabled)
                            TextSpan(
                              text: ' · Disabled',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.0,
                                  ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    // Use the selectedRows parameter from StructuredDataTable
    // It already includes the right-clicked row if not selected
    final selection = selected.isNotEmpty ? selected : [host];
    final canRemoveAll = selection.every(
      (item) => item is CustomSshHost || item.source == 'custom',
    );
    final singleSelection = selection.length == 1;
    final isCustom = host.source == 'custom';
    final allDisabled =
        selection.isNotEmpty && selection.every(_isHostDisabled);
    final selectionHasDisabled = selection.any(_isHostDisabled);

    return [
      StructuredDataMenuAction<SshHost>(
        label: 'Open terminal',
        icon: NerdIcon.terminal.data,
        enabled: selection.isNotEmpty && !selectionHasDisabled,
        onSelected: (selectedRows, primaryRow) {
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          AppLogger().debug(
            'Open terminal action: selectedRows=${selectedRows.length}, targets=${targets.length}, selection=${selection.length}',
            tag: 'ServersList',
          );
          for (final target in targets) {
            AppLogger().debug(
              'Opening terminal for: ${target.name}',
              tag: 'ServersList',
            );
            if (widget.onOpenTerminal != null) {
              widget.onOpenTerminal!(target);
            } else if (target == targets.first) {
              widget.onActivate?.call(target);
            }
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Open file explorer',
        icon: NerdIcon.folderOpen.data,
        enabled: selection.isNotEmpty && !selectionHasDisabled,
        onSelected: (selectedRows, _) {
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          for (final target in targets) {
            if (widget.onOpenExplorer != null) {
              widget.onOpenExplorer!(target);
            } else if (target == targets.first) {
              widget.onActivate?.call(target);
            }
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Port forwarding',
        icon: Icons.link,
        enabled: singleSelection && !selectionHasDisabled,
        onSelected: (_, primary) => widget.onOpenPortForward?.call(primary),
      ),
      if (singleSelection && isCustom)
        StructuredDataMenuAction<SshHost>(
          label: 'Edit server',
          icon: Icons.edit_outlined,
          onSelected: (_, primary) async {
            final customHost = widget.settingsController.settings.customSshHosts
                .firstWhere((h) => h.name == primary.name);
            final otherNames = widget.settingsController.settings.customSshHosts
                .where((h) => h.name != primary.name)
                .map((h) => h.name)
                .toList();
            final result = await showDialog<CustomSshHost>(
              context: context,
              builder: (context) => AddServerDialog(
                initialHost: customHost,
                keyService: widget.keyService,
                existingNames: otherNames,
              ),
            );
            if (result != null && mounted) {
              final current = widget.settingsController.settings;
              final updated = [...current.customSshHosts];
              final idx = updated.indexWhere((h) => h.name == customHost.name);
              if (idx != -1) {
                updated[idx] = result;
                widget.settingsController.update(
                  (s) => s.copyWith(customSshHosts: updated),
                );
              }
            }
          },
        ),
      StructuredDataMenuAction<SshHost>(
        label: 'Connectivity',
        icon: NerdIcon.accessPoint.data,
        enabled: selection.isNotEmpty && !selectionHasDisabled,
        onSelected: (selectedRows, _) {
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          for (final target in targets) {
            widget.onOpenConnectivity?.call(target);
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Resources',
        icon: NerdIcon.database.data,
        enabled: selection.isNotEmpty && !selectionHasDisabled,
        onSelected: (selectedRows, _) {
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          for (final target in targets) {
            widget.onOpenResources?.call(target);
          }
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: allDisabled ? 'Enable server' : 'Disable server',
        icon: allDisabled ? Icons.visibility : Icons.visibility_off,
        enabled: selection.isNotEmpty,
        onSelected: (selectedRows, _) async {
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          await _setHostsDisabled(targets, !allDisabled);
        },
      ),
      StructuredDataMenuAction<SshHost>(
        label: 'Remove',
        icon: Icons.delete_outline,
        destructive: true,
        enabled: canRemoveAll,
        onSelected: (selectedRows, _) {
          if (!canRemoveAll) return;
          // selectedRows parameter contains all selected servers
          final targets = selectedRows.isNotEmpty ? selectedRows : selection;
          final current = widget.settingsController.settings;
          final removalNames = targets.map((item) => item.name).toSet();
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
    // Scale with zoom factor to match text scaling
    return (titleSize * 1.9) * context.zoomFactor;
  }
}
