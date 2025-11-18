import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/custom_ssh_host.dart';
import '../../../models/ssh_client_backend.dart';
import '../../../models/ssh_host.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_entry.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../../widgets/section_nav_bar.dart';
import '../../../services/filesystem/explorer_trash_manager.dart';
import '../../../services/ssh/remote_shell_service.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import 'widgets/trash_tab.dart';
import 'widgets/file_explorer_tab.dart';
import 'widgets/connectivity_tab.dart';
import 'widgets/resources_tab.dart';
import 'widgets/server_tab_chip.dart';

class ServersView extends StatefulWidget {
  const ServersView({
    super.key,
    required this.hostsFuture,
    required this.settingsController,
    required this.builtInVault,
    this.leading,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshVault builtInVault;
  final Widget? leading;

  @override
  State<ServersView> createState() => _ServersViewState();
}

class _ServersViewState extends State<ServersView> {
  final List<_ServerTab> _tabs = [];
  int _selectedTabIndex = 0;
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();

  @override
  Widget build(BuildContext context) {
    final workspace = _tabs.isEmpty
        ? _buildHostSelection(onHostActivate: _startActionFlowForHost)
        : _buildTabWorkspace();

    return Column(
      children: [
        SectionNavBar(
          title: 'Servers',
          tabs: const [],
          leading: widget.leading,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Server',
                onPressed: () => _showAddServerDialog(context),
              ),
              _buildServersMenu(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: workspace,
          ),
        ),
      ],
    );
  }

  Widget _buildHostSelection({
    ValueChanged<SshHost>? onHostSelected,
    ValueChanged<SshHost>? onHostActivate,
  }) {
    return FutureBuilder<List<SshHost>>(
      future: widget.hostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }
        final hosts = snapshot.data ?? <SshHost>[];
        return _HostList(
          hosts: hosts,
          onSelect: onHostSelected,
          onActivate: onHostActivate ?? _startActionFlowForHost,
          settingsController: widget.settingsController,
          builtInVault: widget.builtInVault,
          onHostsChanged: () {
            // Trigger rebuild when hosts change
            setState(() {});
          },
        );
      },
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    // Get keyStore from settings view or create it
    final keyStore = BuiltInSshKeyStore();
    final result = await showDialog<CustomSshHost>(
      context: context,
      builder: (context) => _AddServerDialog(
        keyStore: keyStore,
        vault: widget.builtInVault,
      ),
    );
    if (result != null) {
      final current = widget.settingsController.settings.customSshHosts;
      widget.settingsController.update(
        (settings) => settings.copyWith(
          customSshHosts: [...current, result],
        ),
      );
    }
  }

  Widget _buildTabWorkspace() {
    final appTheme = context.appTheme;
    return Column(
      children: [
        Material(
          color: appTheme.section.toolbarBackground,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: _tabs.isEmpty
                      ? const SizedBox.shrink()
                      : ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: appTheme.spacing.inset(
                            horizontal: 1,
                            vertical: 0,
                          ),
                          buildDefaultDragHandles: false,
                          onReorder: _handleTabReorder,
                          itemCount: _tabs.length,
                          itemBuilder: (context, index) {
                            final tab = _tabs[index];
                            return ServerTabChip(
                              key: ValueKey(tab.id),
                              host: tab.host,
                              title: tab.title,
                              label: tab.label,
                              icon: tab.icon,
                              selected: index == _selectedTabIndex,
                              onSelect: () =>
                                  setState(() => _selectedTabIndex = index),
                              onClose: () => _closeTab(index),
                              onRename: () => _renameTab(index),
                              dragIndex: index,
                            );
                          },
                        ),
                ),
              ),
              IconButton(
                tooltip: 'New tab',
                icon: Icon(NerdIcon.add.data),
                onPressed: _startEmptyTab,
              ),
            ],
          ),
        ),
        Padding(
          padding: appTheme.spacing.inset(horizontal: 2, vertical: 0),
          child: Divider(height: 1, color: appTheme.section.divider),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex.clamp(0, _tabs.length - 1),
            children: _tabs
                .map(
                  (tab) => KeyedSubtree(
                    key: ValueKey('server-tab-${tab.id}'),
                    child: _buildTabChild(tab),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _startActionFlowForHost(SshHost host) async {
    final action = await _pickAction(host);
    if (action != null) {
      _addTab(host, action);
    }
  }

  void _addTab(SshHost host, _ServerAction action) {
    setState(() {
      final tab = _createTab(
        id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
        host: host,
        action: action,
      );
      _tabs.add(tab);
      _selectedTabIndex = _tabs.length - 1;
    });
  }

  Future<void> _startEmptyTab() async {
    final tabIndex = _tabs.length;
    setState(() {
      _tabs.add(
        _createTab(
          id: 'empty-${DateTime.now().microsecondsSinceEpoch}',
          host: const _PlaceholderHost(),
          action: _ServerAction.empty,
        ),
      );
      _selectedTabIndex = tabIndex;
    });
  }

  _ServerTab _createTab({
    required String id,
    required SshHost host,
    required _ServerAction action,
    String? customName,
    GlobalKey? bodyKey,
  }) {
    return _ServerTab(
      id: id,
      host: host,
      action: action,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      customName: customName,
    );
  }

  Widget _buildTabChild(_ServerTab tab) {
    switch (tab.action) {
      case _ServerAction.empty:
        return _buildHostSelection(
          onHostActivate: (selectedHost) =>
              _activateEmptyTab(tab.id, selectedHost),
        );
      case _ServerAction.fileExplorer:
        return FileExplorerTab(
          key: tab.bodyKey,
          host: tab.host,
          shellService: _shellServiceForHost(tab.host),
          builtInVault: widget.builtInVault,
          trashManager: _trashManager,
        );
      case _ServerAction.connectivity:
        return ConnectivityTab(key: tab.bodyKey, host: tab.host);
      case _ServerAction.resources:
        return ResourcesTab(key: tab.bodyKey, host: tab.host);
      case _ServerAction.trash:
        return TrashTab(
          key: tab.bodyKey,
          manager: _trashManager,
          shellService: _shellServiceForHost(tab.host),
          builtInVault: widget.builtInVault,
        );
    }
  }

  RemoteShellService _shellServiceForHost(SshHost host) {
    final settings = widget.settingsController.settings;
    if (settings.sshClientBackend == SshClientBackend.builtin) {
      return BuiltInRemoteShellService(
        vault: widget.builtInVault,
        hostKeyBindings: settings.builtinSshHostKeyBindings,
      );
    }
    return const ProcessRemoteShellService();
  }

  void _closeTab(int index) {
    setState(() {
      if (index < 0 || index >= _tabs.length) {
        return;
      }
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _selectedTabIndex = 0;
      } else if (_selectedTabIndex >= _tabs.length) {
        _selectedTabIndex = _tabs.length - 1;
      } else if (_selectedTabIndex > index) {
        _selectedTabIndex -= 1;
      }
    });
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final moved = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, moved);
      if (_selectedTabIndex == oldIndex) {
        _selectedTabIndex = newIndex;
      } else if (_selectedTabIndex >= oldIndex &&
          _selectedTabIndex < newIndex) {
        _selectedTabIndex -= 1;
      } else if (_selectedTabIndex <= oldIndex &&
          _selectedTabIndex > newIndex) {
        _selectedTabIndex += 1;
      }
    });
  }

  Future<void> _activateEmptyTab(String tabId, SshHost host) async {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1) {
      return;
    }
    final action = await _pickAction(host);
    if (action == null) {
      return;
    }
    final tab = _createTab(
      id: tabId,
      host: host,
      action: action,
      customName: _tabs[index].customName,
    );
    setState(() {
      _tabs[index] = tab;
      _selectedTabIndex = index;
    });
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final tab = _tabs[index];
    final controller = TextEditingController(text: tab.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename tab'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tab name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null) {
      return;
    }
    setState(() {
      final trimmed = newName.trim();
      _tabs[index] = tab.copyWith(
        customName: trimmed.isEmpty ? null : trimmed,
        setCustomName: true,
      );
    });
  }

  Future<_ServerAction?> _pickAction(SshHost host) {
    return showDialog<_ServerAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Actions for ${host.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(NerdIcon.folderOpen.data),
              title: const Text('Open File Explorer'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(_ServerAction.fileExplorer),
            ),
            ListTile(
              leading: Icon(NerdIcon.accessPoint.data),
              title: const Text('Connectivity Dashboard'),
              subtitle: const Text('Latency, jitter & throughput'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(_ServerAction.connectivity),
            ),
            ListTile(
              leading: Icon(Icons.memory),
              title: const Text('Resources Dashboard'),
              subtitle: const Text('CPU, memory, disks, processes'),
              onTap: () =>
                  Navigator.of(dialogContext).pop(_ServerAction.resources),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildServersMenu() {
    return PopupMenuButton<_ServersMenuAction>(
      tooltip: 'Server options',
      icon: const Icon(Icons.settings),
      onSelected: (value) {
        switch (value) {
          case _ServersMenuAction.openTrash:
            _openTrashTab();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ServersMenuAction.openTrash,
          child: Text('Open trash tab'),
        ),
      ],
    );
  }

  void _openTrashTab() {
    setState(() {
      _tabs.add(
        _createTab(
          id: 'trash-${DateTime.now().microsecondsSinceEpoch}',
          host: const _TrashHost(),
          action: _ServerAction.trash,
          customName: 'Trash',
        ),
      );
      _selectedTabIndex = _tabs.length - 1;
    });
  }
}

class _HostList extends StatefulWidget {
  const _HostList({
    required this.hosts,
    required this.onSelect,
    required this.onActivate,
    required this.settingsController,
    required this.builtInVault,
    required this.onHostsChanged,
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost>? onActivate;
  final AppSettingsController settingsController;
  final BuiltInSshVault builtInVault;
  final VoidCallback onHostsChanged;

  @override
  State<_HostList> createState() => _HostListState();
}

class _HostListState extends State<_HostList> {
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
              onPressed: () => _showAddServerDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Server'),
            ),
          ],
        ),
      );
    }

    if (!showSections) {
      // Single source - no headers needed
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => _buildHostTile(widget.hosts[index]),
        separatorBuilder: (_, _) => SizedBox(height: spacing.base),
        itemCount: widget.hosts.length,
      );
    }

    // Multiple sources - show with headers
    return ListView.builder(
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
                      onPressed: () => _editConfigFile(source),
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
      builder: (context) => _AddServerDialog(
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

  Future<void> _showAddServerDialog(BuildContext context) async {
    final keyStore = BuiltInSshKeyStore();
    final result = await showDialog<CustomSshHost>(
      context: context,
      builder: (context) => _AddServerDialog(
        keyStore: keyStore,
        vault: widget.builtInVault,
      ),
    );
    if (result != null) {
      final current = widget.settingsController.settings.customSshHosts;
      widget.settingsController.update(
        (settings) => settings.copyWith(
          customSshHosts: [...current, result],
        ),
      );
      widget.onHostsChanged();
    }
  }

  Future<void> _editConfigFile(String sourcePath) async {
    try {
      final editor = Platform.environment['EDITOR']?.trim();
      if (editor != null && editor.isNotEmpty) {
        final parts = editor
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          // Try to find the executable
          String? executable;
          if (parts.first.contains('/') || parts.first.contains('\\')) {
            // Absolute or relative path
            executable = parts.first;
          } else {
            // Command name - try to find it
            final whichCmd = Platform.isWindows ? 'where' : 'which';
            final result = await Process.run(whichCmd, [parts.first]);
            if (result.exitCode == 0) {
              executable = result.stdout.toString().trim().split('\n').first;
            }
          }
          if (executable != null) {
            await Process.start(
              executable,
              [...parts.sublist(1), sourcePath],
            );
            return;
          }
        }
      }

      // Fallback to platform-specific defaults
      if (Platform.isMacOS) {
        await Process.start('open', ['-t', sourcePath]);
      } else if (Platform.isWindows) {
        await Process.start('notepad', [sourcePath]);
      } else {
        // Linux/Unix - try common editors
        final editors = ['nano', 'vim', 'vi', 'gedit', 'kate'];
        for (final editor in editors) {
          try {
            final whichCmd = 'which';
            final result = await Process.run(whichCmd, [editor]);
            if (result.exitCode == 0) {
              await Process.start(editor, [sourcePath]);
              return;
            }
          } catch (_) {
            continue;
          }
        }
        // Last resort: xdg-open
        await Process.start('xdg-open', [sourcePath]);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open editor: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(NerdIcon.alert.data, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to read SSH config',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ServerTab {
  const _ServerTab({
    required this.id,
    required this.host,
    required this.action,
    required this.bodyKey,
    this.customName,
  });

  final String id;
  final SshHost host;
  final _ServerAction action;
  final GlobalKey bodyKey;
  final String? customName;

  String get title =>
      customName?.isNotEmpty == true ? customName! : '${host.name} - $label';

  String get label {
    switch (action) {
      case _ServerAction.empty:
        return 'Explorer';
      case _ServerAction.fileExplorer:
        return 'File Explorer';
      case _ServerAction.connectivity:
        return 'Connectivity';
      case _ServerAction.resources:
        return 'Resources';
      case _ServerAction.trash:
        return 'Trash';
    }
  }

  IconData get icon {
    switch (action) {
      case _ServerAction.empty:
        return NerdIcon.folderOpen.data;
      case _ServerAction.fileExplorer:
        return NerdIcon.folder.data;
      case _ServerAction.connectivity:
        return NerdIcon.accessPoint.data;
      case _ServerAction.resources:
        return NerdIcon.database.data;
      case _ServerAction.trash:
        return Icons.delete_outline;
    }
  }

  _ServerTab copyWith({
    String? id,
    SshHost? host,
    _ServerAction? action,
    GlobalKey? bodyKey,
    String? customName,
    bool setCustomName = false,
  }) {
    return _ServerTab(
      id: id ?? this.id,
      host: host ?? this.host,
      action: action ?? this.action,
      bodyKey: bodyKey ?? this.bodyKey,
      customName: setCustomName ? customName : this.customName,
    );
  }
}

enum _ServerAction { fileExplorer, connectivity, resources, empty, trash }

class _PlaceholderHost extends SshHost {
  const _PlaceholderHost()
    : super(name: 'Explorer', hostname: '', port: 0, available: true);
}

class _TrashHost extends SshHost {
  const _TrashHost()
    : super(name: 'Trash', hostname: '', port: 0, available: true);
}

enum _ServersMenuAction { openTrash }

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog({
    this.initialHost,
    required this.keyStore,
    required this.vault,
  });

  final CustomSshHost? initialHost;
  final BuiltInSshKeyStore keyStore;
  final BuiltInSshVault vault;

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initialHost?.name ?? '',
  );
  late final _hostnameController = TextEditingController(
    text: widget.initialHost?.hostname ?? '',
  );
  late final _portController = TextEditingController(
    text: widget.initialHost?.port.toString() ?? '22',
  );
  late final _userController = TextEditingController(
    text: widget.initialHost?.user ?? '',
  );
  
  String? _selectedKeyId;
  Future<List<BuiltInSshKeyEntry>>? _keysFuture;

  @override
  void initState() {
    super.initState();
    _keysFuture = widget.keyStore.listEntries();
    // Set initial key selection if editing
    if (widget.initialHost?.identityFile != null) {
      // Try to find matching key by ID
      _keysFuture!.then((keys) {
        final matchingKey = keys.firstWhere(
          (key) => key.id == widget.initialHost!.identityFile,
          orElse: () => keys.isNotEmpty ? keys.first : throw StateError('No keys'),
        );
        if (mounted && keys.isNotEmpty) {
          setState(() => _selectedKeyId = matchingKey.id);
        }
      }).catchError((_) {
        // Ignore if no matching key found
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialHost == null ? 'Add Server' : 'Edit Server',
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      helperText: 'Display name for this server',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _hostnameController,
                    decoration: const InputDecoration(
                      labelText: 'Hostname',
                      helperText: 'Hostname or IP address',
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Hostname is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      helperText: 'SSH port (default: 22)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Port is required';
                      }
                      final port = int.tryParse(value.trim());
                      if (port == null || port < 1 || port > 65535) {
                        return 'Invalid port number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: 'Username (optional)',
                      helperText: 'SSH username',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<BuiltInSshKeyEntry>>(
                    future: _keysFuture,
                    builder: (context, snapshot) {
                      final keys = snapshot.data ?? [];
                      final keyItems = <DropdownMenuItem<String?>>[
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None (use default)'),
                        ),
                        ...keys.map((key) => DropdownMenuItem(
                              value: key.id,
                              child: Text(key.label),
                            )),
                        const DropdownMenuItem(
                          value: '__add_key__',
                          child: Row(
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 8),
                              Text('Add new key...'),
                            ],
                          ),
                        ),
                      ];

                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedKeyId,
                        decoration: const InputDecoration(
                          labelText: 'SSH Key (optional)',
                          helperText: 'Select a configured SSH key',
                        ),
                        items: keyItems,
                        onChanged: (value) async {
                          if (value == '__add_key__') {
                            // Show add key dialog
                            final newKey = await _showAddKeyDialog(context);
                            if (newKey != null && mounted) {
                              setState(() {
                                _selectedKeyId = newKey.id;
                                _keysFuture = widget.keyStore.listEntries();
                              });
                            }
                          } else {
                            setState(() => _selectedKeyId = value);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final port = int.tryParse(_portController.text.trim()) ?? 22;
              Navigator.of(context).pop(
                CustomSshHost(
                  name: _nameController.text.trim(),
                  hostname: _hostnameController.text.trim(),
                  port: port,
                  user: _userController.text.trim().isEmpty
                      ? null
                      : _userController.text.trim(),
                  identityFile: _selectedKeyId,
                ),
              );
            }
          },
          child: Text(widget.initialHost == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Future<BuiltInSshKeyEntry?> _showAddKeyDialog(BuildContext context) async {
    return showDialog<BuiltInSshKeyEntry>(
      context: context,
      builder: (context) => _AddKeyDialog(
        keyStore: widget.keyStore,
        vault: widget.vault,
      ),
    );
  }
}

class _AddKeyDialog extends StatefulWidget {
  const _AddKeyDialog({
    required this.keyStore,
    required this.vault,
  });

  final BuiltInSshKeyStore keyStore;
  final BuiltInSshVault vault;

  @override
  State<_AddKeyDialog> createState() => _AddKeyDialogState();
}

class _AddKeyDialogState extends State<_AddKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSaving = false;
  String? _selectedFilePath;

  @override
  void dispose() {
    _labelController.dispose();
    _keyController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem', 'key', 'id_rsa', 'id_ed25519', 'id_ecdsa'],
      dialogTitle: 'Select SSH Private Key',
    );
    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final file = File(filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        setState(() {
          _selectedFilePath = filePath;
          _keyController.text = contents;
          if (_labelController.text.isEmpty) {
            // Auto-fill label from filename
            final fileName = filePath.split('/').last;
            _labelController.text = fileName;
          }
        });
      }
    }
  }

  Future<void> _handleAddKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final label = _labelController.text.trim();
    final keyText = _keyController.text.trim();
    final password = _passwordController.text.trim();
    
    // Validate encrypted keys (same logic as settings view)
    bool keyIsEncrypted = false;
    bool parseSucceeded = false;
    try {
      SSHKeyPair.fromPem(keyText);
      parseSucceeded = true;
      keyIsEncrypted = false;
    } on ArgumentError catch (e) {
      if (e.message == 'passphrase is required for encrypted key') {
        keyIsEncrypted = true;
      }
    } on StateError catch (e) {
      if (e.message.contains('encrypted')) {
        keyIsEncrypted = true;
      }
    } catch (_) {
      // Parsing failed - might be encrypted or unsupported
    }

    // If parsing failed, validate with passphrase
    if (!parseSucceeded) {
      String? passphrase;
      if (password.isNotEmpty) {
        passphrase = password;
      } else {
        // Prompt for passphrase
        final passphraseResult = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('Key validation needed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The key could not be parsed. It may be encrypted with a passphrase, '
                    'or it may be unsupported. Please try providing a passphrase if the key is encrypted.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Key passphrase',
                      helperText: 'Leave empty if the key is not encrypted.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('Try without passphrase'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Validate'),
                ),
              ],
            );
          },
        );
        if (passphraseResult == null) {
          return; // User cancelled
        }
        passphrase = passphraseResult.isEmpty ? null : passphraseResult;
      }

      if (passphrase != null && passphrase.isNotEmpty) {
        try {
          SSHKeyPair.fromPem(keyText, passphrase);
          keyIsEncrypted = true;
        } on SSHKeyDecryptError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid passphrase: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } on UnsupportedError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unsupported key cipher or format: ${e.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Key cannot be parsed even with passphrase. '
                'It may be unsupported or malformed: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      } else {
        // No passphrase provided but parsing failed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Key cannot be parsed without passphrase. '
              'It may be encrypted, unsupported, or malformed.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
    } else if (keyIsEncrypted) {
      // Key was detected as encrypted, validate passphrase
      if (password.isEmpty) {
        // Prompt for passphrase
        final passphraseResult = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text(
                'Key passphrase required',
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Key passphrase',
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Validate'),
                ),
              ],
            );
          },
        );
        if (passphraseResult == null) {
          return; // User cancelled
        }
        try {
          SSHKeyPair.fromPem(keyText, passphraseResult);
        } on SSHKeyDecryptError catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid passphrase: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to validate key: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final entry = await widget.keyStore.addEntry(
        label: label,
        keyData: utf8.encode(keyText),
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add key: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add SSH Key',
        overflow: TextOverflow.visible,
        softWrap: true,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Key label',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Label is required';
                  }
                  return null;
                },
                autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _keyController,
                      decoration: InputDecoration(
                        labelText: 'Private key (PEM format)',
                        helperText: _selectedFilePath != null
                            ? 'Selected: ${_selectedFilePath!.split('/').last}'
                            : null,
                      ),
                      maxLines: null,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Key is required';
                        }
                        return null;
                      },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: 'Select key file',
                        onPressed: _pickKeyFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Encryption password (optional)',
                  helperText:
                      'If provided, the key will be encrypted in storage. '
                      'Leave empty to store unencrypted keys as plaintext.',
                ),
                obscureText: true,
              ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleAddKey,
          child: Text(_isSaving ? 'Saving...' : 'Add'),
        ),
      ],
    );
  }
}
