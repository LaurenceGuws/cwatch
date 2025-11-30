import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/core/tabs/tab_host_view.dart';
import 'package:cwatch/core/workspace/workspace_persistence.dart';
import 'package:cwatch/models/custom_ssh_host.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/server_workspace_state.dart';
import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'servers/add_server_dialog.dart';
import 'servers/host_list.dart';
import 'servers/server_models.dart';
import 'servers/servers_widgets.dart';
import 'widgets/connectivity_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart';
import 'widgets/resources_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/terminal/terminal_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/trash_tab.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_tab.dart';
import 'package:cwatch/services/ssh/remote_editor_cache.dart';

class ServersList extends StatefulWidget {
  const ServersList({
    super.key,
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.commandLog,
    this.leading,
  });

  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final RemoteCommandLogController commandLog;
  final Widget? leading;

  @override
  State<ServersList> createState() => _ServersListState();
}

class _ServersListState extends State<ServersList> {
  late final TabHostController<ServerTab> _tabController;
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final WorkspacePersistence<ServerWorkspaceState> _workspacePersistence;
  final Map<String, Widget> _tabBodies = {};
  final Map<String, ServerTab> _tabCache = {};
  static int _placeholderSequence = 0;

  List<ServerTab> get _tabs => _tabController.tabs;
  int get _selectedTabIndex => _tabController.selectedIndex;
  void _selectTab(int index) => _tabController.select(index);

  static String _newPlaceholderId() {
    final sequence = _placeholderSequence++;
    return 'host-tab-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  ServerTab _createPlaceholderTab() {
    final id = _newPlaceholderId();
    return _createTab(
      id: id,
      host: const PlaceholderHost(),
      action: ServerAction.empty,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabHostController<ServerTab>(
      baseTabBuilder: _createPlaceholderTab,
      tabId: (tab) => tab.id,
    );
    final base = _tabController.tabs.first;
    _tabCache[base.id] = base;
    _tabBodies[base.id] = _buildTabWidget(base);
    _tabsListener = _handleTabsChanged;
    _tabController.addListener(_tabsListener);
    _settingsListener = _handleSettingsChanged;
    _workspacePersistence = WorkspacePersistence(
      settingsController: widget.settingsController,
      readFromSettings: (settings) => settings.serverWorkspace,
      writeToSettings: (current, workspace) =>
          current.copyWith(serverWorkspace: workspace),
      signatureOf: (workspace) => workspace.signature,
    );
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void didUpdateWidget(covariant ServersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostsFuture != oldWidget.hostsFuture) {
      _restoreWorkspace();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabsListener);
    _tabController.dispose();
    widget.settingsController.removeListener(_settingsListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _tabs.isEmpty
        ? _buildHostSelection(onHostActivate: _startActionFlowForHost)
        : _buildTabWorkspace();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: workspace,
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
        onOpenConnectivity: (host) =>
            _addTab(host, ServerAction.connectivity),
          onOpenResources: (host) => _addTab(host, ServerAction.resources),
          onOpenTerminal: (host) => _addTab(host, ServerAction.terminal),
          onOpenExplorer: (host) => _addTab(host, ServerAction.fileExplorer),
          onHostsChanged: () {
            // Trigger rebuild when hosts change
            setState(() {});
          },
          onAddServer: (existingNames) =>
              _showAddServerDialog(context, existingNames),
        );
      },
    );
  }

  Future<void> _showAddServerDialog(
    BuildContext context,
    List<String> existingNames,
  ) async {
    final result = await showDialog<CustomSshHost>(
      context: context,
      builder: (context) => AddServerDialog(
        keyService: widget.keyService,
        existingNames: existingNames,
      ),
    );
    if (result != null) {
      final current = widget.settingsController.settings;
      final hosts = [...current.customSshHosts, result];
      final bindings = Map<String, String>.from(
        current.builtinSshHostKeyBindings,
      );
      if (result.identityFile != null && result.identityFile!.isNotEmpty) {
        bindings[result.name] = result.identityFile!;
      }
      widget.settingsController.update(
        (settings) => settings.copyWith(
          customSshHosts: hosts,
          builtinSshHostKeyBindings: bindings,
        ),
      );
    }
  }

  Widget _buildTabWorkspace() {
    final appTheme = context.appTheme;
    return Column(
      children: [
        Expanded(
          child: Material(
            color: appTheme.section.toolbarBackground,
            child: TabHostView<ServerTab>(
              controller: _tabController,
              tabBarHeight: 36,
              leading: widget.leading != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: 36,
                        child: Center(child: widget.leading),
                      ),
                    )
                  : null,
              onReorder: _handleTabReorder,
              onAddTab: _startEmptyTab,
              buildChip: (context, index, tab) {
                return ValueListenableBuilder<List<TabChipOption>>(
                  key: ValueKey(tab.id),
                  valueListenable: tab.optionsController,
                  builder: (context, options, _) {
                    final canRename = tab.action != ServerAction.empty;
                    final canDrag = tab.action != ServerAction.empty;
                    return TabChip(
                      host: tab.host,
                      title: tab.title,
                      label: tab.label,
                      icon: tab.icon,
                      selected: index == _selectedTabIndex,
                      onSelect: () {
                        _selectTab(index);
                        _persistWorkspace();
                      },
                      onClose: () => _closeTab(index),
                      onRename: canRename ? () => _renameTab(index) : null,
                      closeWarning: _closeWarningForTab(tab),
                      dragIndex: canDrag ? index : null,
                      options: options,
                    );
                  },
                );
              },
              buildBody: (tab) => KeyedSubtree(
                key: ValueKey('server-tab-${tab.id}'),
                child: _tabWidgetFor(tab),
              ),
            ),
          ),
        ),
        Padding(
          padding: appTheme.spacing.inset(horizontal: 2, vertical: 0),
          child: Divider(height: 1, color: appTheme.section.divider),
        ),
      ],
    );
  }

  TabCloseWarning? _closeWarningForTab(ServerTab tab) {
    if (tab.action == ServerAction.terminal) {
      return const TabCloseWarning(
        title: 'Disconnect terminal session?',
        message:
            'This tab is hosting a remote shell. Closing it will terminate the SSH session and any running commands.',
        confirmLabel: 'Close tab',
        cancelLabel: 'Keep tab open',
      );
    }
    return null;
  }

  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    _restoreWorkspace();
    _workspacePersistence.persistIfPending(_persistWorkspace);
  }

  void _handleTabsChanged() {
    final currentTabs = _tabController.tabs;
    final currentIds = currentTabs.map((tab) => tab.id).toSet();
    final removedIds = _tabCache.keys.where((id) => !currentIds.contains(id));
    for (final id in removedIds.toList()) {
      _tabCache[id]?.optionsController.dispose();
      _tabCache.remove(id);
      _tabBodies.remove(id);
    }
    for (final tab in currentTabs) {
      _tabCache[tab.id] = tab;
      _tabBodies.putIfAbsent(tab.id, () => _buildTabWidget(tab));
    }
    setState(() {});
    unawaited(_persistWorkspace());
  }

  Future<void> _restoreWorkspace() async {
    List<SshHost> hosts;
    try {
      hosts = await widget.hostsFuture;
    } catch (_) {
      hosts = const [];
    }
    if (!mounted) {
      return;
    }
    final workspace = widget.settingsController.settings.serverWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) {
      return;
    }
    if (!_workspacePersistence.shouldRestore(workspace)) {
      return;
    }
    final restoredTabs = _buildTabsFromState(workspace, hosts);
    if (restoredTabs.isEmpty) {
      return;
    }
    _workspacePersistence.markRestored(workspace);
    _disposeTabControllers(_tabs);
    _tabBodies.clear();
    _tabCache.clear();
    _tabController.replaceAll(
      restoredTabs,
      selectedIndex: workspace.selectedIndex,
    );
  }

  List<ServerTab> _buildTabsFromState(
    ServerWorkspaceState workspace,
    List<SshHost> hosts,
  ) {
    final restored = <ServerTab>[];
    for (final tabState in workspace.tabs) {
      final host = _resolveHost(tabState, hosts);
      if (host == null) {
        continue;
      }
      restored.add(
        _createTab(
          id: tabState.id,
          host: host,
          action: tabState.action,
          customName: tabState.customName,
        ),
      );
    }
    return restored;
  }

  SshHost? _resolveHost(ServerTabState tabState, List<SshHost> hosts) {
    switch (tabState.action) {
      case ServerAction.empty:
        return const PlaceholderHost();
      case ServerAction.trash:
        return _findHostByName(hosts, tabState.hostName) ?? const TrashHost();
      case ServerAction.fileExplorer:
      case ServerAction.connectivity:
      case ServerAction.terminal:
      case ServerAction.resources:
      case ServerAction.editor:
        return _findHostByName(hosts, tabState.hostName);
    }
  }

  SshHost? _findHostByName(List<SshHost> hosts, String target) {
    for (final host in hosts) {
      if (host.name == target) {
        return host;
      }
    }
    return null;
  }

  ServerWorkspaceState _currentWorkspaceState() {
    final tabs = _tabs
        .map(
          (tab) => ServerTabState(
            id: tab.id,
            hostName: tab.host.name,
            action: tab.action,
            customName: tab.customName,
          ),
        )
        .toList();
    final clampedIndex = _tabs.isEmpty
        ? 0
        : _selectedTabIndex.clamp(0, _tabs.length - 1);
    return ServerWorkspaceState(tabs: tabs, selectedIndex: clampedIndex);
  }

  Future<void> _persistWorkspace() async {
    final workspace = _currentWorkspaceState();
    await _workspacePersistence.persist(workspace);
  }

  Future<void> _startActionFlowForHost(SshHost host) async {
    final action = await ActionPickerDialog.show(context, host);
    if (action != null) {
      _addTab(host, action);
    }
  }

  void _addTab(SshHost host, ServerAction action) {
    final tab = _createTab(
      id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: action,
    );
    if (_replacePlaceholderWithSelectedTab(tab)) {
      return;
    }
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.addTab(tab);
  }

  bool _replacePlaceholderWithSelectedTab(ServerTab tab) {
    if (_tabs.isEmpty) {
      return false;
    }
    final index = _selectedTabIndex.clamp(0, _tabs.length - 1);
    final current = _tabAt(index);
    if (current.action != ServerAction.empty) {
      return false;
    }
    current.optionsController.dispose();
    _tabBodies.remove(current.id);
    _tabCache.remove(current.id);
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.replaceTab(current.id, tab);
    return true;
  }

  ServerTab _tabAt(int index) => _tabs[index];

  void _addEmptyTabPlaceholder() {
    final placeholder = _createPlaceholderTab();
    _tabBodies[placeholder.id] = _buildTabWidget(placeholder);
    _tabController.addTab(placeholder);
  }

  Future<void> _startEmptyTab() async {
    _addEmptyTabPlaceholder();
  }

  ServerTab _createTab({
    required String id,
    required SshHost host,
    required ServerAction action,
    String? customName,
    GlobalKey? bodyKey,
    ExplorerContext? explorerContext,
    TabOptionsController? optionsController,
  }) {
    return ServerTab(
      id: id,
      host: host,
      action: action,
      bodyKey: bodyKey ?? GlobalKey(debugLabel: 'server-tab-$id'),
      customName: customName,
      explorerContext: explorerContext,
      optionsController: optionsController,
    );
  }

  Widget _tabWidgetFor(ServerTab tab) {
    return _tabBodies[tab.id] ??= _buildTabWidget(tab);
  }

  void _disposeTabControllers(Iterable<ServerTab> tabs) {
    for (final tab in tabs) {
      tab.optionsController.dispose();
    }
  }

  Widget _buildTabWidget(ServerTab tab) {
    switch (tab.action) {
      case ServerAction.empty:
        return _buildHostSelection(
          onHostActivate: (selectedHost) =>
              _activateEmptyTab(tab.id, selectedHost),
        );
      case ServerAction.fileExplorer:
        final explorerContext = ExplorerContext.server(tab.host);
        return FileExplorerTab(
          key: tab.bodyKey,
          host: tab.host,
          explorerContext: explorerContext,
          shellService: _shellServiceForHost(tab.host),
          keyService: widget.keyService,
          trashManager: _trashManager,
          onOpenTrash: _openTrashTab,
          onOpenEditorTab: _openEditorTab,
          onOpenTerminalTab: (path) =>
              _openTerminalTab(host: tab.host, initialDirectory: path),
          optionsController: tab.optionsController,
        );
      case ServerAction.editor:
        final editorPath = tab.customName ?? '';
        return _EditorTabLoader(
          key: tab.bodyKey,
          host: tab.host,
          shellService: _shellServiceForHost(tab.host),
          path: editorPath,
          settingsController: widget.settingsController,
          optionsController: tab.optionsController,
        );
      case ServerAction.connectivity:
        return ConnectivityTab(key: tab.bodyKey, host: tab.host);
      case ServerAction.resources:
        return ResourcesTab(
          key: tab.bodyKey,
          host: tab.host,
          shellService: _shellServiceForHost(tab.host),
        );
      case ServerAction.terminal:
        return TerminalTab(
          key: tab.bodyKey,
          host: tab.host,
          initialDirectory: tab.customName,
          shellService: _shellServiceForHost(tab.host),
          settingsController: widget.settingsController,
          optionsController: tab.optionsController,
          onExit: () => _closeTabById(tab.id),
        );
      case ServerAction.trash:
        return TrashTab(
          key: tab.bodyKey,
          manager: _trashManager,
          shellService: _shellServiceForHost(tab.host),
          keyService: widget.keyService,
          context: tab.explorerContext,
        );
    }
  }

  RemoteShellService _shellServiceForHost(SshHost host) {
    final settings = widget.settingsController.settings;
    final observer = _debugObserver();
    if (settings.sshClientBackend == SshClientBackend.builtin) {
      return widget.keyService.buildShellService(
        hostKeyBindings: settings.builtinSshHostKeyBindings,
        debugMode: settings.debugMode,
        observer: observer,
        promptUnlock: (keyId, hostName, keyLabel) =>
            _promptUnlockKey(keyId, hostName, keyLabel),
      );
    }
    return ProcessRemoteShellService(
      debugMode: settings.debugMode,
      observer: observer,
    );
  }

  RemoteCommandObserver? _debugObserver() {
    final settings = widget.settingsController.settings;
    if (!settings.debugMode) {
      return null;
    }
    return (event) => widget.commandLog.add(event);
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final removedTab = _tabs[index];
    removedTab.optionsController.dispose();
    _tabBodies.remove(removedTab.id);
    _tabCache.remove(removedTab.id);
    _tabController.closeTab(index);
  }

  void _closeTabById(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index != -1) {
      _closeTab(index);
    }
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _tabController.reorder(oldIndex, newIndex);
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
    final oldTab = _tabs[index];
    oldTab.optionsController.dispose();
    _tabBodies.remove(oldTab.id);
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.replaceTab(oldTab.id, tab);
    _selectTab(index);
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final tab = _tabs[index];
    final controller = TextEditingController(text: tab.title);
    String? newName;
    try {
      newName = await showDialog<String>(
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
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    } finally {
      _disposeControllerAfterFrame(controller);
    }
    if (newName == null) {
      return;
    }
    final trimmedInput = newName.trim();
    final updated = tab.copyWith(
      customName: trimmedInput.isEmpty ? null : trimmedInput,
      setCustomName: true,
    );
    _tabBodies.remove(tab.id);
    _tabBodies[updated.id] = _buildTabWidget(updated);
    _tabCache.remove(tab.id);
    _tabCache[updated.id] = updated;
    _tabController.replaceTab(tab.id, updated);
  }

  void _openTrashTab(ExplorerContext context) {
    final host = context.host;
    final tab = _createTab(
      id: 'trash-${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: ServerAction.trash,
      customName: 'Trash • ${host.name}',
      explorerContext: context,
    );
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.addTab(tab);
  }

  Future<void> _openEditorTab(String path, String initialContent) async {
    // Find existing editor tab for this path, or create a new one
    final existingIndex = _tabs.indexWhere(
      (tab) => tab.action == ServerAction.editor && tab.customName == path,
    );

    if (existingIndex != -1) {
      // Switch to existing tab
      _selectTab(existingIndex);
      return;
    }

    // Create new editor tab
    final tab = _createTab(
      id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
      host:
          _tabs.isNotEmpty && _tabs[_selectedTabIndex].host is! PlaceholderHost
          ? _tabs[_selectedTabIndex].host
          : const PlaceholderHost(),
      action: ServerAction.editor,
      customName: path,
    );
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.addTab(tab);
  }

  Future<void> _openTerminalTab({
    required SshHost host,
    String? initialDirectory,
  }) async {
    final trimmedDirectory = initialDirectory?.trim();
    final normalizedDirectory = (trimmedDirectory?.isNotEmpty ?? false)
        ? trimmedDirectory
        : null;
    final existingIndex = _tabs.indexWhere(
      (tab) =>
          tab.action == ServerAction.terminal &&
          tab.host.name == host.name &&
          tab.customName == normalizedDirectory,
    );
    if (existingIndex != -1) {
      _selectTab(existingIndex);
      return;
    }

    final tab = _createTab(
      id: 'terminal-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: ServerAction.terminal,
      customName: normalizedDirectory,
    );
    _tabBodies[tab.id] = _buildTabWidget(tab);
    _tabController.addTab(tab);
  }

  Future<bool> _promptUnlockKey(
    String keyId,
    String hostName,
    String? keyLabel,
  ) async {
    final initialResult =
        await widget.keyService.unlock(keyId, password: null);
    if (initialResult.status == BuiltInSshKeyUnlockStatus.unlocked) {
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlocked key for this session.')),
      );
      return true;
    }
    if (!mounted) return false;

    final controller = TextEditingController();
    String? errorText;
    bool loading = false;
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> attemptUnlock() async {
              if (loading) return;
              final password = controller.text.trim();
              if (password.isEmpty) {
                setState(() => errorText = 'Password is required');
                return;
              }
              setState(() {
                loading = true;
                errorText = null;
              });
              try {
                final result = await widget.keyService.unlock(
                  keyId,
                  password: password,
                );
                if (result.status == BuiltInSshKeyUnlockStatus.unlocked) {
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Key unlocked for this session.'),
                    ),
                  );
                } else if (result.status ==
                    BuiltInSshKeyUnlockStatus.incorrectPassword) {
                  setState(() {
                    errorText = 'Incorrect password. Please try again.';
                    loading = false;
                  });
                } else {
                  setState(() {
                    errorText = result.message ?? 'Failed to unlock.';
                    loading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  errorText = 'Failed to unlock: $e';
                  loading = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Unlock ${keyLabel ?? 'key'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Host: $hostName'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    enabled: !loading,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : attemptUnlock,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
    _disposeControllerAfterFrame(controller);
    return success == true;
  }

  void _disposeControllerAfterFrame(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }
}

class _EditorTabLoader extends StatefulWidget {
  const _EditorTabLoader({
    super.key,
    required this.host,
    required this.shellService,
    required this.path,
    required this.settingsController,
    this.optionsController,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;
  final TabOptionsController? optionsController;

  @override
  State<_EditorTabLoader> createState() => _EditorTabLoaderState();
}

class _EditorTabLoaderState extends State<_EditorTabLoader> {
  String? _content;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final content = await widget.shellService.readFile(
        widget.host,
        widget.path,
      );
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Failed to load file: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadFile, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_content == null) {
      return const Center(child: Text('No content'));
    }
    final cache = RemoteEditorCache();
    return RemoteFileEditorTab(
      host: widget.host,
      shellService: widget.shellService,
      path: widget.path,
      initialContent: _content!,
      settingsController: widget.settingsController,
      onSave: (content) async {
        await widget.shellService.writeFile(widget.host, widget.path, content);
        await cache.materialize(
          host: widget.host.name,
          remotePath: widget.path,
          contents: content,
        );
      },
      optionsController: widget.optionsController,
    );
  }
}
