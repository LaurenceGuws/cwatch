import 'package:flutter/material.dart';

import '../../../models/custom_ssh_host.dart';
import '../../../models/ssh_client_backend.dart';
import '../../../models/ssh_host.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../services/filesystem/explorer_trash_manager.dart';
import '../../../services/ssh/remote_shell_service.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../../widgets/section_nav_bar.dart';
import 'servers/add_server_dialog.dart';
import 'servers/host_list.dart';
import 'servers/server_models.dart';
import 'servers/servers_widgets.dart';
import 'widgets/connectivity_tab.dart';
import 'widgets/file_explorer_tab.dart';
import 'widgets/resources_tab.dart';
import 'widgets/server_tab_chip.dart';
import 'widgets/trash_tab.dart';

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
  final List<ServerTab> _tabs = [];
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
          return ErrorState(error: snapshot.error.toString());
        }
        final hosts = snapshot.data ?? <SshHost>[];
        return HostList(
          hosts: hosts,
          onSelect: onHostSelected,
          onActivate: onHostActivate ?? _startActionFlowForHost,
          settingsController: widget.settingsController,
          builtInVault: widget.builtInVault,
          onHostsChanged: () {
            // Trigger rebuild when hosts change
            setState(() {});
          },
          onAddServer: () => _showAddServerDialog(context),
        );
      },
    );
  }

  Future<void> _showAddServerDialog(BuildContext context) async {
    final keyStore = BuiltInSshKeyStore();
    final result = await showDialog<CustomSshHost>(
      context: context,
      builder: (context) => AddServerDialog(
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
    final action = await ActionPickerDialog.show(context, host);
    if (action != null) {
      _addTab(host, action);
    }
  }

  void _addTab(SshHost host, ServerAction action) {
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
          host: const PlaceholderHost(),
          action: ServerAction.empty,
        ),
      );
      _selectedTabIndex = tabIndex;
    });
  }

  ServerTab _createTab({
    required String id,
    required SshHost host,
    required ServerAction action,
    String? customName,
    GlobalKey? bodyKey,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: action,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      customName: customName,
    );
  }

  Widget _buildTabChild(ServerTab tab) {
    switch (tab.action) {
      case ServerAction.empty:
        return _buildHostSelection(
          onHostActivate: (selectedHost) =>
              _activateEmptyTab(tab.id, selectedHost),
        );
      case ServerAction.fileExplorer:
        return FileExplorerTab(
          key: tab.bodyKey,
          host: tab.host,
          shellService: _shellServiceForHost(tab.host),
          builtInVault: widget.builtInVault,
          trashManager: _trashManager,
        );
      case ServerAction.connectivity:
        return ConnectivityTab(key: tab.bodyKey, host: tab.host);
      case ServerAction.resources:
        return ResourcesTab(key: tab.bodyKey, host: tab.host);
      case ServerAction.trash:
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
    final action = await ActionPickerDialog.show(context, host);
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

  Widget _buildServersMenu() {
    return ServersMenu(
      onOpenTrash: _openTrashTab,
    );
  }

  void _openTrashTab() {
    setState(() {
      _tabs.add(
        _createTab(
          id: 'trash-${DateTime.now().microsecondsSinceEpoch}',
          host: const TrashHost(),
          action: ServerAction.trash,
          customName: 'Trash',
        ),
      );
      _selectedTabIndex = _tabs.length - 1;
    });
  }
}
