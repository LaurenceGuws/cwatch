import 'package:flutter/material.dart';

import '../../../models/ssh_host.dart';
import '../../widgets/section_nav_bar.dart';
import 'widgets/file_explorer_tab.dart';
import 'widgets/ping_tab.dart';
import 'widgets/server_tab_chip.dart';

class ServersView extends StatefulWidget {
  const ServersView({
    super.key,
    required this.hostsFuture,
  });

  final Future<List<SshHost>> hostsFuture;

  @override
  State<ServersView> createState() => _ServersViewState();
}

class _ServersViewState extends State<ServersView> {
  final List<_ServerTab> _tabs = [];
  List<SshHost> _knownHosts = [];
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final workspace = _tabs.isEmpty ? _buildHostSelection() : _buildTabWorkspace();

    return Column(
      children: [
        const SectionNavBar(
          title: 'Servers',
          tabs: [],
        ),
        Expanded(child: workspace),
      ],
    );
  }

  Widget _buildHostSelection() {
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
        _knownHosts = hosts;
        if (hosts.isEmpty) {
          return const Center(
            child: Text('No SSH hosts found in available configs.'),
          );
        }
        return _HostList(
          hosts: hosts,
          onSelect: _startActionFlowForHost,
        );
      },
    );
  }

  Widget _buildTabWorkspace() {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: _tabs.isEmpty
                      ? const SizedBox.shrink()
                      : ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          buildDefaultDragHandles: false,
                          onReorder: _handleTabReorder,
                          itemCount: _tabs.length,
                          itemBuilder: (context, index) {
                            final tab = _tabs[index];
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(tab.id),
                              index: index,
                              child: ServerTabChip(
                                host: tab.host,
                                label: tab.label,
                                icon: tab.icon,
                                selected: index == _selectedTabIndex,
                                onSelect: () => setState(() => _selectedTabIndex = index),
                                onClose: () => _closeTab(index),
                              ),
                            );
                          },
                        ),
                ),
              ),
              IconButton(
                tooltip: 'New tab',
                icon: const Icon(Icons.add),
                onPressed: _knownHosts.isEmpty ? null : _startNewTabFlow,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex.clamp(0, _tabs.length - 1),
            children: _tabs.map((tab) => tab.child).toList(),
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

  Future<void> _startNewTabFlow() async {
    final host = await _pickHost();
    if (host == null) {
      return;
    }
    final action = await _pickAction(host);
    if (action != null) {
      _addTab(host, action);
    }
  }

  Future<SshHost?> _pickHost() {
    return showDialog<SshHost>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select server'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: _knownHosts.length,
            itemBuilder: (context, index) {
              final host = _knownHosts[index];
              return ListTile(
                leading: Icon(
                  host.available ? Icons.check_circle : Icons.error,
                  color: host.available ? Colors.green : Colors.red,
                ),
                title: Text(host.name),
                subtitle: Text('${host.hostname}:${host.port}'),
                onTap: () => Navigator.of(context).pop(host),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_ServerAction?> _pickAction(SshHost host) {
    return showDialog<_ServerAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actions for ${host.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open File Explorer'),
              onTap: () => Navigator.of(context).pop(_ServerAction.fileExplorer),
            ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('Run Ping Test'),
              onTap: () => Navigator.of(context).pop(_ServerAction.pingTest),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addTab(SshHost host, _ServerAction action) {
    setState(() {
      final tab = _ServerTab(
        id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
        host: host,
        action: action,
        child: _buildTabChild(host, action),
      );
      _tabs.add(tab);
      _selectedTabIndex = _tabs.length - 1;
    });
  }

  Widget _buildTabChild(SshHost host, _ServerAction action) {
    switch (action) {
      case _ServerAction.fileExplorer:
        return FileExplorerTab(
          key: ValueKey('explorer-${host.name}-${DateTime.now().microsecondsSinceEpoch}'),
          host: host,
        );
      case _ServerAction.pingTest:
        return PingTab(
          key: ValueKey('ping-${host.name}-${DateTime.now().microsecondsSinceEpoch}'),
          host: host,
        );
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
      } else if (_selectedTabIndex >= oldIndex && _selectedTabIndex < newIndex) {
        _selectedTabIndex -= 1;
      } else if (_selectedTabIndex <= oldIndex && _selectedTabIndex > newIndex) {
        _selectedTabIndex += 1;
      }
    });
  }
}

class _HostList extends StatelessWidget {
  const _HostList({
    required this.hosts,
    required this.onSelect,
  });

  final List<SshHost> hosts;
  final ValueChanged<SshHost> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemBuilder: (context, index) {
        final host = hosts[index];
        final availability = host.available ? 'Online' : 'Offline';
        return Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(
              host.available ? Icons.check_circle : Icons.error,
              color: host.available ? Colors.green : Colors.red,
            ),
            title: Text(host.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${host.hostname}:${host.port}'),
                const SizedBox(height: 4),
                const Text(
                  'View options',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
            trailing: Text(
              availability,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: host.available ? Colors.green : Colors.red,
              ),
            ),
            onTap: () => onSelect(host),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: hosts.length,
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
          const Icon(Icons.warning, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to read SSH config',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
          ),
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
    required this.child,
  });

  final String id;
  final SshHost host;
  final _ServerAction action;
  final Widget child;

  String get label {
    switch (action) {
      case _ServerAction.fileExplorer:
        return 'File Explorer';
      case _ServerAction.pingTest:
        return 'Ping Test';
    }
  }

  IconData get icon {
    switch (action) {
      case _ServerAction.fileExplorer:
        return Icons.folder_open;
      case _ServerAction.pingTest:
        return Icons.wifi_tethering;
    }
  }
}

enum _ServerAction { fileExplorer, pingTest }
