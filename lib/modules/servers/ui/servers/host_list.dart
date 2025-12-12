import 'package:flutter/material.dart';

import 'package:cwatch/models/custom_ssh_host.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/lists/selectable_list_controller.dart';
import 'package:cwatch/shared/widgets/lists/selectable_list_item.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';

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
  final SelectableListController _listController = SelectableListController();
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'HostList');
  Offset? _lastPointerPosition;

  Map<String, List<SshHost>> _groupHostsBySource() {
    final grouped = <String, List<SshHost>>{};
    for (final host in widget.hosts) {
      final source = host.source ?? 'unknown';
      grouped.putIfAbsent(source, () => []).add(host);
    }
    return grouped;
  }

  @override
  void dispose() {
    _listController.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  String _getSourceDisplayName(String source) {
    if (source == 'custom') {
      return 'Added Servers';
    }
    final parts = source.split('/');
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final grouped = _groupHostsBySource();
    final sources = grouped.keys.toList()..sort();

    if (widget.hosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No SSH hosts found.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => widget.onAddServer(_displayNames()),
              icon: const Icon(Icons.add),
              label: const Text('Add Server'),
            ),
          ],
        ),
      );
    }

    final addButton = Padding(
      padding: EdgeInsets.only(
        left: spacing.base * 2,
        right: spacing.base * 2,
        bottom: spacing.base,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton.icon(
          onPressed: () => widget.onAddServer(_displayNames()),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Server'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.base * 1.5,
              vertical: spacing.sm,
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _listController,
      builder: (context, _) {
        final list = sources.length == 1
            ? SectionList(children: widget.hosts.map(_buildHostTile).toList())
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final hosts = grouped[source]!;
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing.base * 1.5),
                    child: SectionList(
                      title: _getSourceDisplayName(source),
                      trailing: source == 'custom'
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: 'Edit config file',
                              onPressed: () =>
                                  ExternalAppLauncher.openConfigFile(
                                    source,
                                    context,
                                  ),
                            ),
                      children: hosts.map(_buildHostTile).toList(),
                    ),
                  );
                },
              );
        return Column(
          children: [
            addButton,
            Expanded(
              child: SelectableListKeyboardHandler(
                controller: _listController,
                itemCount: widget.hosts.length,
                focusNode: _listFocusNode,
                onActivate: (index) {
                  final host = widget.hosts[index];
                  widget.onActivate?.call(host);
                },
                child: list,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHostTile(SshHost host) {
    final availability = host.available ? 'Online' : 'Offline';
    final index = widget.hosts.indexOf(host);
    final selected = _listController.selectedIndices.contains(index);
    final focused = _listController.focusedIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = host.available ? scheme.primary : scheme.error;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        availability,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return SelectableListItem(
      selected: selected,
      focused: focused,
      title: host.name,
      subtitle:
          '${host.hostname}:${host.port}'
          '${host.user?.isNotEmpty == true ? ' • ${host.user}' : ''}',
      leading: Icon(
        NerdIcon.servers.data,
        size: 20,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      badge: badge,
      onTapDown: (details) {
        _lastPointerPosition = details.globalPosition;
        _handleSelect(index, host, focusOnly: false);
      },
      onTap: () => _handleSelect(index, host, focusOnly: false),
      onDoubleTap: () {
        _handleSelect(index, host, focusOnly: false);
        _showContextMenu(host, scheme, _lastPointerPosition);
      },
      onLongPress: () {
        _handleSelect(index, host, focusOnly: false);
        _showContextMenu(host, scheme, _lastPointerPosition);
      },
      onSecondaryTapDown: (details) {
        _lastPointerPosition = details.globalPosition;
        _handleSelect(index, host, focusOnly: true);
        _showContextMenu(host, scheme, details.globalPosition);
      },
    );
  }

  void _handleSelect(int index, SshHost host, {required bool focusOnly}) {
    _listController.focus(index);
    if (!focusOnly) {
      _listController.selectSingle(index);
    }
    widget.onSelect?.call(host);
  }

  List<String> _displayNames() => widget.hosts.map((h) => h.name).toList();

  List<PopupMenuEntry<String>> _hostActions(ColorScheme scheme, SshHost host) {
    final isCustom = host is CustomSshHost || host.source == 'custom';
    return [
      PopupMenuItem(
        value: 'connect',
        child: Row(
          children: [
            Icon(NerdIcon.terminal.data, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Open terminal'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'explore',
        child: Row(
          children: [
            Icon(NerdIcon.folderOpen.data, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Open file explorer'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'portForward',
        child: Row(
          children: [
            Icon(Icons.link, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Port forwarding'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'connectivity',
        child: Row(
          children: [
            Icon(NerdIcon.accessPoint.data, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Connectivity'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'resources',
        child: Row(
          children: [
            Icon(NerdIcon.database.data, color: scheme.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Resources'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        enabled: isCustom,
        value: 'remove',
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: scheme.error, size: 18),
            const SizedBox(width: 8),
            Text('Remove', style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
    ];
  }

  void _handleHostAction(String? choice, SshHost host) {
    switch (choice) {
      case 'connect':
        if (widget.onOpenTerminal != null) {
          widget.onOpenTerminal!(host);
        } else {
          widget.onActivate?.call(host);
        }
        break;
      case 'explore':
        if (widget.onOpenExplorer != null) {
          widget.onOpenExplorer!(host);
        } else {
          widget.onActivate?.call(host);
        }
        break;
      case 'connectivity':
        widget.onOpenConnectivity?.call(host);
        break;
      case 'resources':
        widget.onOpenResources?.call(host);
        break;
      case 'portForward':
        widget.onOpenPortForward?.call(host);
        break;
      case 'remove':
        final isCustom = host is CustomSshHost || host.source == 'custom';
        if (isCustom) {
          final current = widget.settingsController.settings;
          final updated = [...current.customSshHosts]
            ..removeWhere((h) => h.name == host.name);
          widget.settingsController.update(
            (settings) => settings.copyWith(customSshHosts: updated),
          );
          widget.onHostsChanged();
        }
        break;
      default:
        break;
    }
  }

  void _showContextMenu(
    SshHost host,
    ColorScheme scheme, [
    Offset? tapPosition,
  ]) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final basePosition = overlay?.localToGlobal(Offset.zero) ?? Offset.zero;
    final anchor = tapPosition ?? basePosition + const Offset(200, 200);
    final relative = RelativeRect.fromLTRB(
      anchor.dx - basePosition.dx,
      anchor.dy - basePosition.dy,
      anchor.dx - basePosition.dx,
      anchor.dy - basePosition.dy,
    );
    final choice = await showMenu<String>(
      context: context,
      position: relative,
      items: _hostActions(scheme, host),
    );
    _handleHostAction(choice, host);
  }
}
