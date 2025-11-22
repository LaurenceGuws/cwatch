import 'package:flutter/material.dart';

import '../../../../models/custom_ssh_host.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/settings/app_settings_controller.dart';
import '../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';
import 'add_server_dialog.dart';
import '../widgets/file_explorer/external_app_launcher.dart';

/// Host list widget that displays SSH hosts grouped by source
class HostList extends StatefulWidget {
  const HostList({
    super.key,
    required this.hosts,
    required this.onSelect,
    required this.onActivate,
    required this.settingsController,
    required this.builtInVault,
    required this.onHostsChanged,
    required this.onAddServer,
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost>? onActivate;
  final AppSettingsController settingsController;
  final BuiltInSshVault builtInVault;
  final VoidCallback onHostsChanged;
  final VoidCallback onAddServer;

  @override
  State<HostList> createState() => _HostListState();
}

class _HostListState extends State<HostList> {
  SshHost? _selected;

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
    // Extract filename from path
    final parts = source.split('/');
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final grouped = _groupHostsBySource();
    final sources = grouped.keys.toList()..sort();

    // Show sections only if more than one source
    final showSections = sources.length > 1;

    if (widget.hosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No SSH hosts found.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onAddServer,
              icon: const Icon(Icons.add),
              label: const Text('Add Server'),
            ),
          ],
        ),
      );
    }

    if (!showSections) {
      // Single source - no headers needed
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: spacing.base,
                bottom: spacing.base,
              ),
              child: IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Server',
                onPressed: widget.onAddServer,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) => _buildHostTile(widget.hosts[index]),
              separatorBuilder: (_, _) => SizedBox(height: spacing.base),
              itemCount: widget.hosts.length,
            ),
          ),
        ],
      );
    }

    // Multiple sources - show with headers
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: spacing.base,
              bottom: spacing.base,
            ),
            child: IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Server',
              onPressed: widget.onAddServer,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: sources.length * 2 - 1, // Headers + separators
            itemBuilder: (context, index) {
              if (index.isOdd) {
                // Separator
                return SizedBox(height: spacing.base * 2);
              }
              final sourceIndex = index ~/ 2;
              final source = sources[sourceIndex];
              final hosts = grouped[source]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.base * 2,
                      vertical: spacing.base,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getSourceDisplayName(source),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        if (source != 'custom')
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Edit config file',
                            onPressed: () =>
                                ExternalAppLauncher.openConfigFile(source, context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                  ...hosts.map((host) => Padding(
                        padding: EdgeInsets.only(bottom: spacing.base),
                        child: _buildHostTile(host),
                      )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHostTile(SshHost host) {
    final spacing = context.appTheme.spacing;
    final availability = host.available ? 'Online' : 'Offline';
    final selected = _selected?.name == host.name;
    final colorScheme = Theme.of(context).colorScheme;
    final highlightColor = selected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final isCustom = host.source == 'custom';

    return GestureDetector(
      onTapDown: (_) => setState(() => _selected = host),
      onTap: () => widget.onSelect?.call(host),
      onDoubleTap: () {
        widget.onSelect?.call(host);
        widget.onActivate?.call(host);
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: context.appTheme.section.cardRadius,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: highlightColor,
            borderRadius: context.appTheme.section.cardRadius,
          ),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: spacing.base * 2,
              vertical: spacing.base,
            ),
            leading: Icon(
              host.available
                  ? NerdIcon.checkCircle.data
                  : NerdIcon.alert.data,
              color: host.available ? Colors.green : Colors.red,
            ),
            title: Text(
              host.name,
              style: selected
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      )
                  : null,
            ),
            subtitle: Text('${host.hostname}:${host.port}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  availability,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: host.available ? Colors.green : Colors.red,
                  ),
                ),
                if (isCustom) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => _editCustomHost(host),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete',
                    onPressed: () => _deleteCustomHost(host),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editCustomHost(SshHost host) async {
    final customHosts = widget.settingsController.settings.customSshHosts;
    final customHost = customHosts.firstWhere(
      (h) => h.name == host.name && h.hostname == host.hostname,
    );
    final keyStore = BuiltInSshKeyStore();
    final result = await showDialog<CustomSshHost>(
      context: context,
      builder: (context) => AddServerDialog(
        initialHost: customHost,
        keyStore: keyStore,
        vault: widget.builtInVault,
      ),
    );
    if (result != null) {
      final updated = customHosts.map((h) => h == customHost ? result : h).toList();
      widget.settingsController.update(
        (settings) => settings.copyWith(customSshHosts: updated),
      );
      widget.onHostsChanged();
    }
  }

  Future<void> _deleteCustomHost(SshHost host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Are you sure you want to delete "${host.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final customHosts = widget.settingsController.settings.customSshHosts;
      final updated = customHosts.where(
        (h) => !(h.name == host.name && h.hostname == host.hostname),
      ).toList();
      widget.settingsController.update(
        (settings) => settings.copyWith(customSshHosts: updated),
      );
      widget.onHostsChanged();
    }
  }
}
