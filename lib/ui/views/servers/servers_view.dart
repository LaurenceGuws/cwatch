import 'package:flutter/material.dart';

import '../../../models/ssh_host.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../../widgets/section_nav_bar.dart';
import '../../../services/filesystem/explorer_trash_manager.dart';
import 'widgets/trash_tab.dart';
import 'widgets/file_explorer_tab.dart';
import 'widgets/connectivity_tab.dart';
import 'widgets/resources_tab.dart';
import 'widgets/server_tab_chip.dart';

class ServersView extends StatefulWidget {
  const ServersView({
    super.key,
    required this.hostsFuture,
    this.leading,
  });

  final Future<List<SshHost>> hostsFuture;
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
          trailing: _buildServersMenu(),
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
        if (hosts.isEmpty) {
          return const Center(
            child: Text('No SSH hosts found in available configs.'),
          );
        }
        return _HostList(
          hosts: hosts,
          onSelect: onHostSelected,
          onActivate: onHostActivate ?? _startActionFlowForHost,
        );
      },
    );
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
          trashManager: _trashManager,
        );
      case _ServerAction.connectivity:
        return ConnectivityTab(key: tab.bodyKey, host: tab.host);
      case _ServerAction.resources:
        return ResourcesTab(key: tab.bodyKey, host: tab.host);
      case _ServerAction.trash:
        return TrashTab(key: tab.bodyKey, manager: _trashManager);
    }
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
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost>? onSelect;
  final ValueChanged<SshHost>? onActivate;

  @override
  State<_HostList> createState() => _HostListState();
}

class _HostListState extends State<_HostList> {
  SshHost? _selected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final host = widget.hosts[index];
        final availability = host.available ? 'Online' : 'Offline';
        final selected = _selected?.name == host.name;
        final colorScheme = Theme.of(context).colorScheme;
        final highlightColor = selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent;
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
                      ? Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: colorScheme.primary)
                      : null,
                ),
                subtitle: Text('${host.hostname}:${host.port}'),
                trailing: Text(
                  availability,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: host.available ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: spacing.base),
      itemCount: widget.hosts.length,
    );
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
