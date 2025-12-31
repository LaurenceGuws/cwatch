import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/models/custom_ssh_host.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/server_action.dart';
import 'package:cwatch/models/server_workspace_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';
import 'package:cwatch/services/ssh/ssh_config_service.dart';
import 'package:cwatch/modules/servers/services/host_distro_manager.dart';
import 'package:cwatch/services/ssh/ssh_auth_prompter.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/shared/widgets/port_forward_dialog.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/core/navigation/command_palette_registry.dart';
import 'package:cwatch/core/tabs/tab_bar_visibility.dart';
import 'servers/add_server_dialog.dart';
import 'servers/host_list.dart';
import 'servers/server_models.dart';
import 'servers/servers_widgets.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor_loader.dart';
import 'package:cwatch/services/ssh/remote_editor_cache.dart';
import 'server_tab_factory.dart';
import 'server_workspace_controller.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';
import 'package:cwatch/core/widgets/keep_alive.dart';
import 'package:cwatch/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/modules/servers/services/host_distro_key.dart';

class ServersList extends StatefulWidget {
  const ServersList({
    super.key,
    required this.moduleId,
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.shellFactory,
    this.leading,
  });

  final String moduleId;
  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;
  final Widget? leading;

  @override
  State<ServersList> createState() => _ServersListState();
}

class _ServersListState extends State<ServersList> {
  late final TabHostController<ServerTab> _tabController;
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();
  final PortForwardService _portForwardService = PortForwardService();
  late final SshShellFactory _shellFactory;
  late final HostDistroManager _distroManager;
  final Map<String, bool> _hostAvailability = {};
  final Set<String> _pendingCustomAvailabilityChecks = {};
  bool _didProbeHostDistro = false;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabViewRegistry<ServerTab> _tabRegistry;
  final Map<String, ServerTab> _tabCache = {};
  static int _placeholderSequence = 0;
  late final ServerWorkspaceController _workspaceController;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;
  late Future<List<SshHost>> _hostsFuture;
  late final ValueNotifier<Future<List<SshHost>>> _hostsFutureNotifier;
  List<SshHost> _lastHosts = const [];
  String _customHostsSignature = '';
  String _pathsSignature = '';
  // String _workspaceSignature = '';
  ServerTabFactory get _tabFactory => _workspaceController.tabFactory;

  Future<List<SshHost>> _loadHosts() async {
    final settings = widget.settingsController.settings;
    final hosts = await SshConfigService(
      customHosts: settings.customSshHosts,
      additionalEntryPoints: settings.customSshConfigPaths,
      disabledEntryPoints: settings.disabledSshConfigPaths,
    ).loadHosts();
    _lastHosts = hosts;
    return hosts;
  }

  String _buildCustomHostsSignature() {
    final settings = widget.settingsController.settings;
    final customHosts =
        settings.customSshHosts.map((host) {
            final keyParts = [
              host.name,
              host.hostname,
              host.port.toString(),
              host.user ?? '',
              host.identityFile ?? '',
            ];
            return {'key': keyParts.join('|'), 'host': host.toJson()};
          }).toList()
          ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
    return jsonEncode(customHosts.map((entry) => entry['host']).toList());
  }

  String _buildPathsSignature() {
    final settings = widget.settingsController.settings;
    final customPaths = [...settings.customSshConfigPaths]..sort();
    final disabledPaths = [...settings.disabledSshConfigPaths]..sort();
    return jsonEncode({
      'customPaths': customPaths,
      'disabledPaths': disabledPaths,
    });
  }

  String _customHostKey(CustomSshHost host) {
    return [
      host.name,
      host.hostname,
      host.port.toString(),
      host.user ?? '',
      host.identityFile ?? '',
    ].join('|');
  }

  String _customHostKeyFromSsh(SshHost host) {
    return [
      host.name,
      host.hostname,
      host.port.toString(),
      host.user ?? '',
      host.identityFiles.isNotEmpty ? host.identityFiles.first : '',
    ].join('|');
  }

  Future<List<SshHost>> _updateCustomHosts(List<CustomSshHost> customHosts) {
    if (_lastHosts.isEmpty) {
      return _loadHosts();
    }
    final existingCustom = <String, SshHost>{
      for (final host in _lastHosts.where((host) => host.source == 'custom'))
        _customHostKeyFromSsh(host): host,
    };
    final nonCustomHosts = _lastHosts
        .where((host) => host.source != 'custom')
        .toList();
    final updatedCustomHosts = <SshHost>[];
    for (final customHost in customHosts) {
      final key = _customHostKey(customHost);
      final existing = existingCustom[key];
      final available = existing?.available ?? false;
      if (existing == null) {
        _scheduleCustomAvailabilityCheck(customHost, key);
      }
      updatedCustomHosts.add(
        SshHost(
          name: customHost.name,
          hostname: customHost.hostname,
          port: customHost.port,
          available: available,
          user: customHost.user,
          identityFiles: customHost.identityFile != null
              ? [customHost.identityFile!]
              : const [],
          source: 'custom',
        ),
      );
    }
    final nextHosts = [...nonCustomHosts, ...updatedCustomHosts];
    _lastHosts = nextHosts;
    return Future.value(nextHosts);
  }

  void _scheduleCustomAvailabilityCheck(CustomSshHost host, String key) {
    if (!_pendingCustomAvailabilityChecks.add(key)) {
      return;
    }
    unawaited(
      _checkAvailability(host)
          .then((available) {
            if (!mounted) {
              return;
            }
            _applyCustomAvailability(host, available);
          })
          .whenComplete(() {
            _pendingCustomAvailabilityChecks.remove(key);
          }),
    );
  }

  void _applyCustomAvailability(CustomSshHost host, bool available) {
    final key = _customHostKey(host);
    final index = _lastHosts.indexWhere(
      (entry) =>
          entry.source == 'custom' && _customHostKeyFromSsh(entry) == key,
    );
    if (index == -1) {
      return;
    }
    final existing = _lastHosts[index];
    if (existing.available == available) {
      return;
    }
    final updated = SshHost(
      name: existing.name,
      hostname: existing.hostname,
      port: existing.port,
      available: available,
      user: existing.user,
      identityFiles: existing.identityFiles,
      source: existing.source,
    );
    final nextHosts = [..._lastHosts];
    nextHosts[index] = updated;
    _lastHosts = nextHosts;
    _hostsFuture = Future.value(nextHosts);
    _hostsFutureNotifier.value = _hostsFuture;

    final distroKey = hostDistroCacheKey(updated);
    final wasAvailable = _hostAvailability[distroKey] ?? false;
    _hostAvailability[distroKey] = available;
    if (available && !_distroManager.hasCached(distroKey)) {
      unawaited(
        _distroManager.ensureDistroForHost(updated, force: !wasAvailable),
      );
    }
  }

  Future<bool> _checkAvailability(CustomSshHost host) async {
    try {
      final socket = await Socket.connect(
        host.hostname,
        host.port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (error, stackTrace) {
      return false;
    }
  }

  List<ServerTab> get _tabs => _tabController.tabs;
  int get _selectedTabIndex => _tabController.selectedIndex;
  void _selectTab(int index) => _tabController.select(index);

  static String _newPlaceholderId() {
    final sequence = _placeholderSequence++;
    return 'host-tab-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  ServerTab _createPlaceholderTab() {
    final id = _newPlaceholderId();
    return _tabFactory.emptyTab(id: id);
  }

  @override
  void initState() {
    super.initState();
    final authCoordinator = SshAuthPrompter.forContext(
      context: context,
      keyService: widget.keyService,
    );
    _shellFactory = SshShellFactory(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      authCoordinator: authCoordinator,
    );
    _distroManager = HostDistroManager(
      settingsController: widget.settingsController,
      shellFactory: _shellFactory,
    );
    _portForwardService.setAuthCoordinator(_shellFactory.authCoordinator);
    _hostsFuture = _loadHosts();
    _hostsFutureNotifier = ValueNotifier(_hostsFuture);
    _workspaceController = ServerWorkspaceController(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsLoader: _loadHosts,
      trashManager: _trashManager,
      shellServiceForHost: _shellServiceForHost,
      editorBuilder: _buildEditorBody,
    );
    _tabController = TabHostController<ServerTab>(
      baseTabBuilder: _createPlaceholderTab,
      tabId: (tab) => tab.id,
    );
    _tabRegistry = TabViewRegistry<ServerTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'server-tab',
    );
    _tabNavigator = TabNavigationHandle(
      next: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final next = (_selectedTabIndex + 1) % length;
        _selectTab(next);
        return true;
      },
      previous: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final prev = (_selectedTabIndex - 1 + length) % length;
        _selectTab(prev);
        return true;
      },
    );
    TabNavigationRegistry.instance.register(widget.moduleId, _tabNavigator);
    _commandPaletteHandle = CommandPaletteHandle(
      loader: () => _buildCommandPaletteEntries(),
    );
    CommandPaletteRegistry.instance.register(
      widget.moduleId,
      _commandPaletteHandle,
    );
    final base = _tabController.tabs.first;
    _syncTabOverlayOptions(base);
    _tabCache[base.id] = base;
    _tabRegistry.widgetFor(base, () => _buildTabWidget(base));
    _tabsListener = _handleTabsChanged;
    _tabController.addListener(_tabsListener);
    _customHostsSignature = _buildCustomHostsSignature();
    _pathsSignature = _buildPathsSignature();
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void didUpdateWidget(covariant ServersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostsFuture != oldWidget.hostsFuture) {
      _hostsFuture = _loadHosts();
      _hostsFutureNotifier.value = _hostsFuture;
      _refreshHostSelectionTabs();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabsListener);
    _tabController.dispose();
    _hostsFutureNotifier.dispose();
    widget.settingsController.removeListener(_settingsListener);
    _portForwardService.dispose();
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      widget.moduleId,
      _commandPaletteHandle,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final workspace = _tabs.isEmpty
        ? _buildHostSelection(onHostActivate: _startActionFlowForHost)
        : _buildTabWorkspace();

    return Padding(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      child: workspace,
    );
  }

  Widget _buildHostSelection({
    ValueChanged<SshHost>? onHostSelected,
    ValueChanged<SshHost>? onHostActivate,
  }) {
    return ValueListenableBuilder<Future<List<SshHost>>>(
      valueListenable: _hostsFutureNotifier,
      builder: (context, hostsFuture, _) {
        return FutureBuilder<List<SshHost>>(
          future: hostsFuture,
          builder: (context, snapshot) {
            final cachedHosts = _lastHosts;
            if (snapshot.connectionState == ConnectionState.waiting &&
                cachedHosts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && cachedHosts.isEmpty) {
              return ErrorState(error: snapshot.error.toString());
            }
            final hosts = snapshot.data ?? cachedHosts;
            final shellCapableHosts = hosts
                .where((host) => !_isNoShellHost(host))
                .toList();
            _trackHostDistroChecks(shellCapableHosts);
            return HostList(
              hosts: shellCapableHosts,
              onSelect: onHostSelected,
              onActivate: onHostActivate ?? _startActionFlowForHost,
              settingsController: widget.settingsController,
              onOpenConnectivity: (host) =>
                  _addTab(host, ServerAction.connectivity),
              onOpenResources: (host) => _addTab(host, ServerAction.resources),
              onOpenTerminal: (host) => _addTab(host, ServerAction.terminal),
              onOpenExplorer: (host) =>
                  _addTab(host, ServerAction.fileExplorer),
              onOpenPortForward: _openPortForwardDialog,
              onHostsChanged: () {
                // Trigger rebuild when hosts change
                _refreshHostSelectionTabs();
              },
              onAddServer: (existingNames) =>
                  _showAddServerDialog(context, existingNames),
            );
          },
        );
      },
    );
  }

  bool _isNoShellHost(SshHost host) {
    final hostname = host.hostname.trim().toLowerCase();
    return hostname == 'github.com' || hostname == 'bitbucket.org';
  }

  void _trackHostDistroChecks(List<SshHost> hosts) {
    if (_didProbeHostDistro) {
      return;
    }
    _didProbeHostDistro = true;
    for (final host in hosts) {
      final key = hostDistroCacheKey(host);
      final wasAvailable = _hostAvailability[key] ?? false;
      _hostAvailability[key] = host.available;
      final hasCache = _distroManager.hasCached(key);
      if (hasCache) {
        continue; // Skip already-tagged hosts to avoid extra SSH prompts.
      }
      final needsProbe = host.available && !hasCache;
      if (needsProbe) {
        unawaited(
          _distroManager.ensureDistroForHost(host, force: !wasAvailable),
        );
      }
    }
  }

  void _openAddServerDialog() {
    final existingNames = _lastHosts.isNotEmpty
        ? _lastHosts.map((host) => host.name).toList()
        : widget.settingsController.settings.customSshHosts
              .map((host) => host.name)
              .toList();
    _showAddServerDialog(context, existingNames);
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
    final spacing = appTheme.spacing;
    return Column(
      children: [
        Expanded(
          child: Material(
            color: appTheme.section.toolbarBackground,
            child: TabbedWorkspaceShell<ServerTab>(
              controller: _tabController,
              registry: _tabRegistry,
              tabBarHeight: 36,
              showTabBar: TabBarVisibilityController.instance,
              enableWindowDrag:
                  !widget.settingsController.settings.windowUseSystemDecorations,
              leading: widget.leading != null
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            (!kIsWeb &&
                                    (defaultTargetPlatform ==
                                            TargetPlatform.windows ||
                                        defaultTargetPlatform ==
                                            TargetPlatform.macOS ||
                                        defaultTargetPlatform ==
                                            TargetPlatform.linux))
                                ? 0
                                : spacing.sm,
                      ),
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
                    final chipOptions = [
                      ...options,
                      if (tab.optionsController
                          is! CompositeTabOptionsController) ...[
                        TabChipOption(
                          label: 'Add server',
                          icon: Icons.add,
                          onSelected: _openAddServerDialog,
                        ),
                        TabChipOption(
                          label: 'Reload tab view',
                          icon: NerdIcon.refresh.data,
                          onSelected: () => _reloadTabView(tab),
                        ),
                        TabChipOption(
                          label: 'Reload server list',
                          icon: NerdIcon.refresh.data,
                          onSelected: _reloadServerListView,
                        ),
                      ],
                    ];

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
                      options: chipOptions,
                    );
                  },
                );
              },
              buildBody: _buildTabWidget,
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

  List<CommandPaletteEntry> _buildCommandPaletteEntries() {
    final entries = <CommandPaletteEntry>[];
    if (_tabs.isNotEmpty) {
      final tab = _tabs[_selectedTabIndex];
      entries.addAll(
        tab.optionsController.value.map(
          (option) => CommandPaletteEntry(
            id: '${widget.moduleId}:tabOption:${option.label}',
            label: option.label,
            category: 'Tab options',
            onSelected: option.onSelected,
            icon: option.icon,
          ),
        ),
      );
      entries.add(
        CommandPaletteEntry(
          id: '${widget.moduleId}:renameTab',
          label: 'Rename tab',
          category: 'Tabs',
          onSelected: () => _renameTab(_selectedTabIndex),
        ),
      );
      entries.add(
        CommandPaletteEntry(
          id: '${widget.moduleId}:closeTab',
          label: 'Close tab',
          category: 'Tabs',
          onSelected: () => _closeTab(_selectedTabIndex),
        ),
      );
    }
    entries.add(
      CommandPaletteEntry(
        id: '${widget.moduleId}:newTab',
        label: 'New tab',
        category: 'Tabs',
        onSelected: _startEmptyTab,
      ),
    );
    return entries;
  }

  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    final nextCustomSignature = _buildCustomHostsSignature();
    final nextPathsSignature = _buildPathsSignature();
    final customHostsChanged = nextCustomSignature != _customHostsSignature;
    final pathsChanged = nextPathsSignature != _pathsSignature;
    if (pathsChanged) {
      _customHostsSignature = nextCustomSignature;
      _pathsSignature = nextPathsSignature;
      AppLogger.d('ServersList hosts updated', tag: 'ServersList');
      _hostsFuture = _loadHosts();
      _hostsFutureNotifier.value = _hostsFuture;
      _refreshHostSelectionTabs();
    } else if (customHostsChanged) {
      _customHostsSignature = nextCustomSignature;
      AppLogger.d('ServersList custom hosts updated', tag: 'ServersList');
      _hostsFuture = _updateCustomHosts(
        widget.settingsController.settings.customSshHosts,
      );
      _hostsFutureNotifier.value = _hostsFuture;
    }

    _workspaceController.workspacePersistence.persistIfPending(
      _persistWorkspace,
    );
  }

  void _reloadServerListView() {
    if (!mounted) return;
    AppLogger.d('ServersList manual reload', tag: 'ServersList');
    _hostsFuture = _loadHosts();
    _hostsFutureNotifier.value = _hostsFuture;
    _hostAvailability.clear();
    _didProbeHostDistro = false;
    _refreshHostSelectionTabs();
  }

  void _reloadTabView(ServerTab tab) {
    if (!mounted) return;
    AppLogger.d('ServersList tab view reload', tag: 'ServersList');
    _tabRegistry.remove(tab);
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
  }

  void _syncTabOverlayOptions(ServerTab tab) {
    final controller = tab.optionsController;
    if (controller is! CompositeTabOptionsController) {
      return;
    }
    controller.updateOverlay([
      TabChipOption(
        label: 'Add server',
        icon: Icons.add,
        onSelected: _openAddServerDialog,
      ),
      TabChipOption(
        label: 'Reload tab view',
        icon: NerdIcon.refresh.data,
        onSelected: () => _reloadTabView(tab),
      ),
      TabChipOption(
        label: 'Reload server list',
        icon: NerdIcon.refresh.data,
        onSelected: _reloadServerListView,
      ),
    ]);
  }

  void _refreshHostSelectionTabs() {
    final emptyTabs = _tabs
        .where((tab) => tab.action == ServerAction.empty)
        .toList(growable: false);
    if (emptyTabs.isEmpty) {
      return;
    }
    for (final tab in emptyTabs) {
      _tabRegistry.remove(tab);
      _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
    }
  }

  void _handleTabsChanged() {
    final currentTabs = _tabController.tabs;
    final currentIds = currentTabs.map((tab) => tab.id).toSet();
    final removedIds = _tabCache.keys.where((id) => !currentIds.contains(id));
    for (final id in removedIds.toList()) {
      _tabCache[id]?.optionsController.dispose();
      _tabCache.remove(id);
      _tabRegistry.remove(_placeholderTab(id));
    }
    for (final tab in currentTabs) {
      _syncTabOverlayOptions(tab);
      _tabCache[tab.id] = tab;
      _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
    }
    setState(() {});
    unawaited(_persistWorkspace());
  }

  Future<void> _restoreWorkspace() async {
    final hosts = await _workspaceController.loadHosts();
    if (!mounted) {
      return;
    }
    final workspace = widget.settingsController.settings.serverWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) {
      return;
    }
    if (!_workspaceController.workspacePersistence.shouldRestore(workspace)) {
      return;
    }
    final restoredTabs = _workspaceController.buildTabsFromState(
      workspace,
      hosts,
    );
    if (restoredTabs.isEmpty) {
      return;
    }
    _workspaceController.workspacePersistence.markRestored(workspace);
    _disposeTabControllers(_tabs);
    _tabRegistry.reset(restoredTabs);
    _tabCache.clear();
    _tabController.replaceAll(
      restoredTabs,
      selectedIndex: workspace.selectedIndex,
    );
  }

  ServerWorkspaceState _currentWorkspaceState() {
    return _workspaceController.currentWorkspaceState(_tabs, _selectedTabIndex);
  }

  Future<void> _persistWorkspace() async {
    final workspace = _currentWorkspaceState();
    await _workspaceController.workspacePersistence.persist(workspace);
  }

  Future<void> _startActionFlowForHost(SshHost host) async {
    final action = await ActionPickerDialog.show(context, host);
    if (action == null) return;
    if (action == ServerAction.portForward) {
      await _openPortForwardDialog(host);
      return;
    }
    _addTab(host, action);
  }

  void _addTab(SshHost host, ServerAction action) {
    _ensureDistroOnInteraction(host);
    final tab = _createTab(
      id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: action,
    );
    if (_replacePlaceholderWithSelectedTab(tab)) {
      return;
    }
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
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
    _tabRegistry.remove(current);
    _tabCache.remove(current.id);
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
    _tabController.replaceTab(current.id, tab);
    return true;
  }

  ServerTab _tabAt(int index) => _tabs[index];

  void _addEmptyTabPlaceholder() {
    final placeholder = _tabFactory.emptyTab(id: _newPlaceholderId());
    _tabRegistry.widgetFor(placeholder, () => _buildTabWidget(placeholder));
    _tabController.addTab(placeholder);
  }

  Future<void> _startEmptyTab() async {
    _addEmptyTabPlaceholder();
  }

  void _ensureDistroOnInteraction(SshHost host) {
    final key = hostDistroCacheKey(host);
    if (_distroManager.hasCached(key)) {
      return;
    }
    unawaited(
      _distroManager.ensureDistroForHost(
        host,
        force: true,
        allowUnavailable: true,
      ),
    );
  }

  Future<void> _openPortForwardDialog(SshHost host) async {
    final active = _portForwardService.forwardsForHost(host).toList();
    final hostKeyBindings =
        widget.settingsController.settings.builtinSshHostKeyBindings;
    final initial = active.isNotEmpty
        ? active.expand((f) => f.requests.map((r) => r.copy())).toList()
        : [
            PortForwardRequest(
              remoteHost: '127.0.0.1',
              remotePort: 0,
              localPort: 0,
              label: 'Mapping 1',
            ),
          ];
    final result = await showPortForwardDialog(
      context: context,
      title: 'Port forwarding (${host.name})',
      requests: initial,
      portValidator: _portForwardService.isPortAvailable,
      active: active,
    );
    if (!mounted || result == null || result.isEmpty) return;
    try {
      await _portForwardService.startForward(
        host: host,
        requests: result,
        settingsController: widget.settingsController,
        builtInKeyService: widget.keyService,
        hostKeyBindings: hostKeyBindings,
        authCoordinator: SshAuthPrompter.forContext(
          context: context,
          keyService: widget.keyService,
        ),
      );
      if (!mounted) return;
      final summary = result
          .map((r) => '${r.localPort}->${r.remotePort}')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarding $summary for ${host.name}.')),
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to start port forwarding for ${host.name}',
        tag: 'Servers',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Port forward failed: $error')));
    }
  }

  ServerTab _createTab({
    required String id,
    required SshHost host,
    required ServerAction action,
    String? customName,
    GlobalKey? bodyKey,
    ExplorerContext? explorerContext,
    String? initialContent,
  }) {
    switch (action) {
      case ServerAction.fileExplorer:
        return _tabFactory.explorerTab(
          id: id,
          host: host,
          bodyKey: bodyKey,
          explorerContext: explorerContext,
        );
      case ServerAction.editor:
        return _tabFactory.editorTab(
          id: id,
          host: host,
          path: customName ?? '',
          initialContent: initialContent,
          bodyKey: bodyKey,
        );
      case ServerAction.terminal:
        return _tabFactory.terminalTab(
          id: id,
          host: host,
          initialDirectory: customName,
          bodyKey: bodyKey,
        );
      case ServerAction.resources:
        return _tabFactory.resourcesTab(id: id, host: host, bodyKey: bodyKey);
      case ServerAction.connectivity:
        return _tabFactory.connectivityTab(
          id: id,
          host: host,
          bodyKey: bodyKey,
        );
      case ServerAction.portForward:
        return _tabFactory.emptyTab(id: id);
      case ServerAction.trash:
        return _tabFactory.trashTab(
          id: id,
          host: host,
          explorerContext: explorerContext,
          bodyKey: bodyKey,
        );
      case ServerAction.empty:
        return _tabFactory.emptyTab(id: id);
    }
  }

  void _disposeTabControllers(Iterable<ServerTab> tabs) {
    for (final tab in tabs) {
      tab.optionsController.dispose();
    }
  }

  ServerTab _placeholderTab(String id) => ServerTab(
    id: id,
    host: const PlaceholderHost(),
    action: ServerAction.empty,
    bodyKey: GlobalKey(),
  );

  Widget _buildTabWidget(ServerTab tab) {
    if (tab.action == ServerAction.empty) {
      return _buildHostSelection(
        onHostActivate: (selectedHost) =>
            _activateEmptyTab(tab.id, selectedHost),
      );
    }
    return _tabFactory.buildBody(
      tab,
      onOpenEditorTab: (path, content) =>
          _openEditorTabForHost(tab.host, path, content),
      onOpenTerminalTab: (host, {initialDirectory}) =>
          _openTerminalTab(host: host, initialDirectory: initialDirectory),
      onOpenTrash: _openTrashTab,
      onCloseTab: _closeTabById,
      onExplorerPathChanged: (path) => _updateExplorerPath(tab, path),
    );
  }

  Widget _buildEditorBody(ServerTab tab) {
    final editorPath = tab.customName ?? '';
    return _EditorTabLoader(
      key: tab.bodyKey,
      host: tab.host,
      shellService: _shellServiceForHost(tab.host),
      path: editorPath,
      settingsController: widget.settingsController,
      initialContent: tab.initialContent,
      optionsController: tab.optionsController,
    );
  }

  RemoteShellService _shellServiceForHost(SshHost host) {
    return _shellFactory.forHost(host);
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final removedTab = _tabs[index];
    removedTab.optionsController.dispose();
    _tabRegistry.remove(removedTab);
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
    _tabRegistry.remove(oldTab);
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
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
        builder: (context) => DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
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
        ),
      );
    } finally {
      controller.dispose();
    }
    if (newName == null) {
      return;
    }
    final trimmedInput = newName.trim();
    final updated = tab.copyWith(
      customName: trimmedInput.isEmpty ? null : trimmedInput,
      setCustomName: true,
    );
    _tabRegistry.remove(tab);
    _tabRegistry.widgetFor(updated, () => _buildTabWidget(updated));
    _tabCache.remove(tab.id);
    _tabCache[updated.id] = updated;
    _tabController.replaceTab(tab.id, updated);
  }

  void _openTrashTab(ExplorerContext context) {
    final host = context.host;
    final tab = _tabFactory.trashTab(
      id: 'trash-${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      explorerContext: context,
    );
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
    _tabController.addTab(tab);
  }

  void _updateExplorerPath(ServerTab tab, String path) {
    final updated = tab.copyWith(explorerPath: path);
    _tabRegistry.remove(tab);
    _tabRegistry.widgetFor(updated, () => _buildTabWidget(updated));
    _tabCache
      ..remove(tab.id)
      ..[updated.id] = updated;
    _tabController.replaceTab(tab.id, updated);
    unawaited(_persistWorkspace());
  }

  Future<void> _openEditorTabForHost(
    SshHost host,
    String path,
    String initialContent,
  ) async {
    final existingIndex = _tabs.indexWhere(
      (tab) =>
          tab.action == ServerAction.editor &&
          tab.customName == path &&
          tab.host.name == host.name,
    );

    if (existingIndex != -1) {
      _selectTab(existingIndex);
      return;
    }

    final tab = _tabFactory.editorTab(
      id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      path: path,
      initialContent: initialContent,
    );
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
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

    final tab = _tabFactory.terminalTab(
      id: 'terminal-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      initialDirectory: normalizedDirectory,
    );
    _tabRegistry.widgetFor(tab, () => _buildTabWidget(tab));
    _tabController.addTab(tab);
  }
}

class _EditorTabLoader extends StatelessWidget {
  const _EditorTabLoader({
    super.key,
    required this.host,
    required this.shellService,
    required this.path,
    required this.settingsController,
    this.initialContent,
    this.optionsController,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;
  final String? initialContent;
  final TabOptionsController? optionsController;

  @override
  Widget build(BuildContext context) {
    final cache = RemoteEditorCache();
    return RemoteFileEditorLoader(
      host: host,
      shellService: shellService,
      path: path,
      settingsController: settingsController,
      initialContent: initialContent,
      optionsController: optionsController,
      onSave: (content) async {
        await shellService.writeFile(host, path, content);
        await cache.materialize(
          host: host.name,
          remotePath: path,
          contents: content,
        );
      },
    );
  }
}
