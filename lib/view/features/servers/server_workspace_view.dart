import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/custom_ssh_host.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_config_service.dart';
import 'package:cwatch/model/features/servers/services/host_distro_manager.dart';
import 'package:cwatch/controller/adapters/server_workspace_ui_adapter.dart';
import 'package:cwatch/controller/controllers/server_port_forward_controller.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/controller/di/bindings/server_workspace_binding.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/services_infra/network/connectivity_probe.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'servers/host_list.dart';
import 'servers/server_models.dart';
import 'servers/servers_widgets.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';
import 'server_tab_builder.dart';
import 'server_workspace_controller.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/view/features/settings/settings/server_list_settings_controls.dart';
import 'package:cwatch/view/features/settings/settings/ssh_settings_controls.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:cwatch/controller/di/bindings/settings_binding.dart';
import 'package:cwatch/controller/di/bindings/server_tab_builder_binding.dart';
import 'package:cwatch/controller/di/bindings/ssh_shell_factory_binding.dart';

class ServerWorkspaceView extends StatefulWidget {
  const ServerWorkspaceView({
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
  State<ServerWorkspaceView> createState() => _ServerWorkspaceViewState();
}

class _ServerWorkspaceViewState extends State<ServerWorkspaceView> {
  final ServerWorkspaceBinding _binding = const ServerWorkspaceBinding();
  final SettingsBinding _settingsBinding = const SettingsBinding();
  final SshShellFactoryBinding _shellFactoryBinding =
      const SshShellFactoryBinding();
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();
  final PortForwardService _portForwardService = PortForwardService();
  late ServerWorkspaceUiAdapter _uiAdapter;
  late ServerPortForwardController _portForwardController;
  late final SshShellFactory _shellFactory;
  late final HostDistroManager _distroManager;
  final Map<String, bool> _hostAvailability = {};
  final Set<String> _pendingCustomAvailabilityChecks = {};
  bool _didProbeHostDistro = false;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;
  static int _placeholderSequence = 0;
  late final ServerWorkspaceController _workspaceController;
  late final ServerTabBuilder _tabBuilder;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;
  late Future<List<SshHost>> _hostsFuture;
  late final ValueNotifier<Future<List<SshHost>>> _hostsFutureNotifier;
  late final SettingsController _settingsController;
  List<SshHost> _lastHosts = const [];
  String _customHostsSignature = '';
  String _pathsSignature = '';
  String _disabledHostsSignature = '';
  bool _showListSettings = false;

  void _toggleListSettings() {
    setState(() {
      _showListSettings = !_showListSettings;
    });
  }

  Future<List<SshHost>> _loadHosts() async {
    final settings = widget.settingsController.settings;
    // Load hosts without blocking on availability checks for initial render
    final hosts = await SshConfigService(
      customHosts: settings.customSshHosts,
      additionalEntryPoints: settings.customSshConfigPaths,
      disabledEntryPoints: settings.disabledSshConfigPaths,
    ).loadHosts(
      disabledHosts: settings.disabledServerHosts.toSet(),
      checkAvailability: false, // Defer availability checks to background
    );
    _lastHosts = hosts;
    
    // Update availability in background without blocking
    _updateAvailabilityInBackground(hosts);
    
    return hosts;
  }
  
  void _updateAvailabilityInBackground(List<SshHost> hosts) {
    // Check availability for hosts in background and update as results arrive
    for (final host in hosts) {
      if (isNoShellHost(host) || _isHostDisabled(host, _disabledHostKeys())) {
        continue;
      }
      unawaited(
        _checkAvailabilityForHost(host).then((available) {
          if (!mounted) return;
          final index = _lastHosts.indexWhere(
            (h) => h.name == host.name && h.hostname == host.hostname && h.port == host.port,
          );
          if (index != -1 && _lastHosts[index].available != available) {
            final existing = _lastHosts[index];
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
          }
        }),
      );
    }
  }
  
  Future<bool> _checkAvailabilityForHost(SshHost host) async {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 2),
      hostLabel: host.name,
    );
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

  Future<bool> _checkAvailability(CustomSshHost host) {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 2),
      hostLabel: host.name,
    );
  }

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedTabIndex => _workspaceController.selectedIndex;
  void _selectTab(int index) => _workspaceController.select(index);

  static String _newPlaceholderId() {
    final sequence = _placeholderSequence++;
    return 'host-tab-${DateTime.now().microsecondsSinceEpoch}-$sequence';
  }

  WorkspaceTab _createPlaceholderTab() {
    final id = _newPlaceholderId();
    return _tabBuilder.emptyTab(
      id: id,
      body: _buildHostSelection(
        onHostActivate: (host) => _activateEmptyTab(id, host),
        onAction: (host, action) => _replaceTabWithAction(id, host, action),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _uiAdapter = _binding.createUiAdapter(context: context);
    final authCoordinator = _uiAdapter.buildSshAuthCoordinator(
      keyService: widget.keyService,
    );
    _shellFactory = _shellFactoryBinding.create(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      authCoordinator: authCoordinator,
    );
    _distroManager = HostDistroManager(
      settingsController: widget.settingsController,
      shellFactory: _shellFactory,
    );
    _portForwardService.setAuthCoordinator(_shellFactory.authCoordinator);
    _portForwardController = _binding.createPortForwardController(
      context: context,
      portForwardService: _portForwardService,
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      uiAdapter: _uiAdapter,
    );
    _hostsFuture = _loadHosts();
    _hostsFutureNotifier = ValueNotifier(_hostsFuture);

    final settingsUiAdapter = _settingsBinding.createUiAdapter(
      context: context,
    );
    _settingsController = _settingsBinding.createController(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsFuture: _hostsFuture,
      uiAdapter: settingsUiAdapter,
    );

    final tabBuilderBinding = const ServerTabBuilderBinding();
    _tabBuilder = tabBuilderBinding.create(
      settingsController: widget.settingsController,
      trashManager: _trashManager,
      shellServiceForHost: (host) => _shellFactory.forHost(host),
      keyService: widget.keyService,
      hostsFuture: _hostsFuture,
    );

    _workspaceController = ServerWorkspaceController(
      settingsController: widget.settingsController,
      hostsLoader: _loadHosts,
      baseTabBuilder: _createPlaceholderTab,
    );

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
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

    _tabsListener = () {
      setState(() {});
    };
    _workspaceController.addListener(_tabsListener);

    _customHostsSignature = _buildCustomHostsSignature();
    _pathsSignature = _buildPathsSignature();
    _disabledHostsSignature = _buildDisabledHostsSignature();

    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);

    _restoreWorkspace();
  }

  @override
  void didUpdateWidget(covariant ServerWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostsFuture != oldWidget.hostsFuture) {
      _hostsFuture = _loadHosts();
      _hostsFutureNotifier.value = _hostsFuture;
    }
  }

  @override
  void dispose() {
    _workspaceController.removeListener(_tabsListener);
    _workspaceController.dispose();
    _hostsFutureNotifier.dispose();
    widget.settingsController.removeListener(_settingsListener);
    _settingsController.dispose();
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
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;

    return Padding(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      child: _buildTabWorkspace(),
    );
  }

  Widget _buildHostSelection({
    ValueChanged<SshHost>? onHostSelected,
    ValueChanged<SshHost>? onHostActivate,
    void Function(SshHost, ServerAction)? onAction,
  }) {
    final selection = ValueListenableBuilder<Future<List<SshHost>>>(
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
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final hosts = snapshot.data ?? cachedHosts;
            // Filter out no-shell hosts, but let HostList handle disabled server filtering
            final shellCapableHosts = hosts
                .where((host) => !isNoShellHost(host))
                .toList();
            _trackHostDistroChecks(shellCapableHosts);
            return HostList(
              key: const ValueKey('host-list'),
              hosts: shellCapableHosts,
              onSelect: onHostSelected,
              onActivate: onHostActivate ?? _startActionFlowForHost,
              settingsController: widget.settingsController,
              keyService: widget.keyService,
              onHostVisible: _ensureDistroForHostOnDemand,
              onOpenConnectivity: (host) {
                // Always use _addTab for multi-select support
                _addTab(host, ServerAction.connectivity);
              },
              onOpenResources: (host) {
                // Always use _addTab for multi-select support
                _addTab(host, ServerAction.resources);
              },
              onOpenTerminal: (host) {
                AppLogger().debug(
                  'onOpenTerminal called for: ${host.name}, onAction=${onAction != null}',
                  tag: 'ServersList',
                );
                // Always use _addTab for multi-select support
                // onAction is only for single-selection in placeholder tabs
                _addTab(host, ServerAction.terminal);
              },
              onOpenExplorer: (host) {
                // Always use _addTab for multi-select support
                _addTab(host, ServerAction.fileExplorer);
              },
              onOpenPortForward: _openPortForwardDialog,
              onHostsChanged: () {
                setState(() {});
              },
              onAddServer: (existingNames) =>
                  _showAddServerDialog(context, existingNames),
              showDisabledServers: false, // Initial state, each HostList manages its own
              onToggleDisabledServersVisibility: () {
                // Callback for logging, but state is managed in HostList
                AppLogger().debug(
                  'Toggle disabled servers visibility',
                  tag: 'ServersList',
                );
              },
            );
          },
        );
      },
    );

    if (!_showListSettings) return selection;
    return Stack(
      children: [
        selection,
        FloatingSettingsWindow(
          title: 'Server List Settings',
          onClose: _toggleListSettings,
          child: Column(
            children: [
              ServerListSettingsControls(
                settings: _settingsController.settings,
                settingsController: _settingsController,
                hosts: _lastHosts,
              ),
              const Divider(),
              SshSettingsControls(controller: _settingsController),
            ],
          ),
        ),
      ],
    );
  }

  void _trackHostDistroChecks(List<SshHost> hosts) {
    // Defer distro detection - only check cached hosts initially
    // Actual detection will happen on-demand when rows are visible or interacted with
    if (_didProbeHostDistro) {
      return;
    }
    _didProbeHostDistro = true;
    
    // Only track availability state, don't trigger distro detection yet
    for (final host in hosts) {
      if (isNoShellHost(host)) {
        continue;
      }
      if (_isHostDisabled(host, _disabledHostKeys())) {
        continue;
      }
      final key = hostDistroCacheKey(host);
      _hostAvailability[key] = host.available;
      // Skip immediate distro detection - will be done on-demand
    }
  }
  
  void _ensureDistroForHostOnDemand(SshHost host) {
    if (isNoShellHost(host)) {
      return;
    }
    if (_isHostDisabled(host, _disabledHostKeys())) {
      return;
    }
    final key = hostDistroCacheKey(host);
    final hasCache = _distroManager.hasCached(key);
    if (hasCache) {
      return;
    }
    if (!host.available) {
      return;
    }
    // Only detect if not already in progress
    final wasAvailable = _hostAvailability[key] ?? false;
    unawaited(
      _distroManager.ensureDistroForHost(host, force: !wasAvailable),
    );
  }

  Widget _buildTabWorkspace() {
    final appTheme = context.appTheme;
    return Column(
      children: [
        Expanded(
          child: Material(
            color: appTheme.section.toolbarBackground,
            child: TabbedWorkspaceShell<WorkspaceTab>(
              controller: _workspaceController,
              registry: _tabRegistry,
              tabBarHeight: 36,
              showTabBar: TabBarVisibilityController.instance,
              enableWindowDrag: !widget
                  .settingsController
                  .settings
                  .windowUseSystemDecorations,
              leading: widget.leading,
              onReorder: _workspaceController.reorder,
              onAddTab: _startEmptyTab,
              buildChip: (context, index, tab) {
                return ValueListenableBuilder<List<TabChipOption>>(
                  key: ValueKey(tab.id),
                  valueListenable: tab.optionsController ?? ValueNotifier([]),
                  builder: (context, options, _) {
                    final data = tab.workspaceState as ServerTabData?;
                    final host = data?.host ?? const PlaceholderHost();
                    final canRename = tab.canRename;
                    final canDrag = tab.canDrag;

                    final chipOptions = [
                      ...options,
                      TabChipOption(
                        label: 'Add server',
                        icon: Icons.add,
                        onSelected: _openAddServerDialog,
                      ),
                      TabChipOption(
                        label: 'Reload server list',
                        icon: NerdIcon.refresh.data,
                        onSelected: _reloadServerListView,
                      ),
                      TabChipOption(
                        label: _showListSettings
                            ? 'Hide list settings'
                            : 'List settings',
                        icon: Icons.settings,
                        onSelected: _toggleListSettings,
                      ),
                    ];

                    return TabChip(
                      host: host,
                      title: tab.title,
                      label: tab.label,
                      icon: tab.icon,
                      selected: index == _selectedTabIndex,
                      onSelect: () => _selectTab(index),
                      onClose: () => _workspaceController.closeTab(index),
                      onRename: canRename ? () => _renameTab(index) : null,
                      dragIndex: canDrag ? index : null,
                      options: chipOptions,
                      closeWarning: _closeWarningForTab(tab),
                    );
                  },
                );
              },
              buildBody: (tab) => tab.body,
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

  TabCloseWarning? _closeWarningForTab(WorkspaceTab tab) {
    final data = tab.workspaceState as ServerTabData?;
    if (data?.action == ServerAction.terminal) {
      return const TabCloseWarning(
        title: 'Disconnect terminal session?',
        message:
            'This tab is hosting a remote shell. Closing it will terminate the SSH session.',
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
      if (tab.optionsController != null) {
        entries.addAll(
          tab.optionsController!.value.map(
            (option) => CommandPaletteEntry(
              id: '${widget.moduleId}:tabOption:${option.label}',
              label: option.label,
              category: 'Tab options',
              onSelected: option.onSelected,
              icon: option.icon,
            ),
          ),
        );
      }
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
          onSelected: () => _workspaceController.closeTab(_selectedTabIndex),
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
    final nextDisabledSignature = _buildDisabledHostsSignature();
    final customHostsChanged = nextCustomSignature != _customHostsSignature;
    final pathsChanged = nextPathsSignature != _pathsSignature;
    final disabledChanged = nextDisabledSignature != _disabledHostsSignature;
    if (pathsChanged) {
      _customHostsSignature = nextCustomSignature;
      _pathsSignature = nextPathsSignature;
      _disabledHostsSignature = nextDisabledSignature;
      AppLogger().debug('ServersList hosts updated', tag: 'ServersList');
      _hostsFuture = _loadHosts();
      _hostsFutureNotifier.value = _hostsFuture;
    } else if (customHostsChanged) {
      _customHostsSignature = nextCustomSignature;
      AppLogger().debug('ServersList custom hosts updated', tag: 'ServersList');
      _hostsFuture = _updateCustomHosts(
        widget.settingsController.settings.customSshHosts,
      );
      _hostsFutureNotifier.value = _hostsFuture;
    } else if (disabledChanged) {
      _disabledHostsSignature = nextDisabledSignature;
      setState(() {});
    }

    final persistedSignature =
        widget.settingsController.settings.serverWorkspace?.signature;
    if (persistedSignature != null &&
        persistedSignature !=
            _workspaceController.currentWorkspaceSignature()) {
      unawaited(_restoreWorkspace());
    }

    _workspaceController.workspacePersistence.persistIfPending(
      () => _workspaceController.persistState(),
    );
  }

  String _buildDisabledHostsSignature() {
    final disabled = [...widget.settingsController.settings.disabledServerHosts]
      ..sort();
    return disabled.join('|');
  }

  void _reloadServerListView() {
    if (!mounted) return;
    AppLogger().debug('ServersList manual reload', tag: 'ServersList');
    _hostsFuture = _loadHosts();
    _hostsFutureNotifier.value = _hostsFuture;
    _hostAvailability.clear();
    _didProbeHostDistro = false;
  }

  Future<void> _restoreWorkspace() async {
    final hosts = await _workspaceController.loadHosts();
    if (!mounted) return;
    await _workspaceController.restore(
      builder: _tabBuilder,
      hosts: hosts,
      onCloseTab: () {
        if (_selectedTabIndex >= 0 && _selectedTabIndex < _tabs.length) {
          _workspaceController.closeTab(_selectedTabIndex);
        }
      },
      onOpenEditor: _openEditorTabForHost,
      onOpenTerminal: (host, dir) =>
          _openTerminalTab(host, initialDirectory: dir),
      onOpenTrash: _openTrashTab,
      hostListBuilder: (tabId) => _buildHostSelection(
        onHostActivate: (selectedHost) =>
            _activateEmptyTab(tabId, selectedHost),
        onAction: (host, action) => _replaceTabWithAction(tabId, host, action),
      ),
    );
  }

  void _replaceTabWithAction(String tabId, SshHost host, ServerAction action) {
    if (action == ServerAction.portForward) {
      _openPortForwardDialog(host);
      return;
    }
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1) return;

    _ensureDistroOnInteraction(host);
    final tab = _createTab(
      id: '${host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      action: action,
    );
    _workspaceController.replaceTab(tabId, tab);
    _selectTab(index);
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
    if (action == ServerAction.portForward) {
      await _openPortForwardDialog(host);
      return;
    }
    final tab = _createTab(id: tabId, host: host, action: action);
    _workspaceController.replaceTab(tabId, tab);
    _selectTab(index);
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
    // Use a more unique ID to prevent collisions when adding multiple tabs quickly
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    final tab = _createTab(
      id: '${host.name}-$timestamp-$random',
      host: host,
      action: action,
    );

    AppLogger().debug(
      '_addTab: host=${host.name}, action=$action, tabId=${tab.id}, currentTabs=${_tabs.length}, selectedIndex=$_selectedTabIndex',
      tag: 'ServersList',
    );

    // Always add new tab when opening multiple terminals - don't replace
    // Only replace if explicitly opening a single terminal and current tab is empty
    final currentTab = _tabs.isNotEmpty && _selectedTabIndex >= 0 && _selectedTabIndex < _tabs.length
        ? _tabs[_selectedTabIndex]
        : null;
    final shouldReplace = currentTab != null &&
        (currentTab.workspaceState as ServerTabData?)?.action == ServerAction.empty;
    
    if (shouldReplace) {
      AppLogger().debug(
        '_addTab: replacing empty tab at index $_selectedTabIndex, tabId=${currentTab.id}',
        tag: 'ServersList',
      );
      _workspaceController.replaceTab(currentTab.id, tab);
    } else {
      AppLogger().debug(
        '_addTab: adding new tab, will have ${_tabs.length + 1} tabs after add',
        tag: 'ServersList',
      );
      _workspaceController.addTab(tab);
      AppLogger().debug(
        '_addTab: tab added, now have ${_tabs.length} tabs',
        tag: 'ServersList',
      );
    }
  }

  WorkspaceTab _createTab({
    required String id,
    required SshHost host,
    required ServerAction action,
  }) {
    switch (action) {
      case ServerAction.fileExplorer:
        return _tabBuilder.explorerTab(
          id: id,
          host: host,
          onOpenEditor: (p, c) => _openEditorTabForHost(host, p, c),
          onOpenTerminal: (h, d) => _openTerminalTab(h, initialDirectory: d),
          onOpenTrash: _openTrashTab,
        );
      case ServerAction.terminal:
        return _tabBuilder.terminalTab(
          id: id,
          host: host,
          onClose: () {
            final index = _tabs.indexWhere((t) => t.id == id);
            if (index != -1) _workspaceController.closeTab(index);
          },
          onOpenEditor: (p, c) => _openEditorTabForHost(host, p, c),
        );
      case ServerAction.editor:
        return _tabBuilder.editorTab(id: id, host: host, path: '');
      case ServerAction.resources:
        return _tabBuilder.resourcesTab(id: id, host: host);
      case ServerAction.connectivity:
        return _tabBuilder.connectivityTab(id: id, host: host);
      case ServerAction.trash:
        return _tabBuilder.trashTab(id: id, host: host);
      default:
        return _tabBuilder.emptyTab(
          id: id,
          body: _buildHostSelection(
            onHostActivate: (host) => _activateEmptyTab(id, host),
            onAction: (host, action) => _replaceTabWithAction(id, host, action),
          ),
        );
    }
  }

  void _ensureDistroOnInteraction(SshHost host) {
    // Trigger distro detection on user interaction
    _ensureDistroForHostOnDemand(host);
  }

  Future<void> _openPortForwardDialog(SshHost host) {
    return _portForwardController.openDialog(host);
  }

  Future<void> _showAddServerDialog(
    BuildContext context,
    List<String> existingNames,
  ) async {
    final result = await _uiAdapter.showAddServerDialog(
      keyService: widget.keyService,
      existingNames: existingNames,
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

  void _openAddServerDialog() {
    final existingNames = _lastHosts.isNotEmpty
        ? _lastHosts.map((host) => host.name).toList()
        : widget.settingsController.settings.customSshHosts
              .map((host) => host.name)
              .toList();
    _showAddServerDialog(context, existingNames);
  }

  void _startEmptyTab() {
    _workspaceController.addTab(_createPlaceholderTab());
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final tab = _tabs[index];
    final newName = await _uiAdapter.showRenameTabDialog(
      initialName: tab.title,
    );
    if (newName == null) {
      return;
    }
    final trimmedInput = newName.trim();
    if (trimmedInput.isEmpty) return;

    final updated = tab.copyWith(title: trimmedInput, label: trimmedInput);
    if (tab.workspaceState is ServerTabData) {
      final oldData = tab.workspaceState as ServerTabData;
      final newTabWithState = updated.copyWith(
        workspaceState: ServerTabData(
          host: oldData.host,
          action: oldData.action,
          persistedState: oldData.persistedState.copyWith(title: trimmedInput),
        ),
      );
      _workspaceController.replaceTab(tab.id, newTabWithState);
    } else {
      _workspaceController.replaceTab(tab.id, updated);
    }
  }

  void _openTrashTab(ExplorerContext context) {
    final tab = _tabBuilder.trashTab(
      id: 'trash-${context.host.name}-${DateTime.now().microsecondsSinceEpoch}',
      host: context.host,
      explorerContext: context,
    );
    _workspaceController.addTab(tab);
  }

  Future<void> _openEditorTabForHost(
    SshHost host,
    String path,
    String content,
  ) async {
    final tab = _tabBuilder.editorTab(
      id: 'editor-${DateTime.now().microsecondsSinceEpoch}',
      host: host,
      path: path,
      initialContent: content,
    );
    _workspaceController.addTab(tab);
  }

  Future<void> _openTerminalTab(
    SshHost host, {
    String? initialDirectory,
  }) async {
    final newId = 'terminal-${DateTime.now().microsecondsSinceEpoch}';
    final newTab = _tabBuilder.terminalTab(
      id: newId,
      host: host,
      initialDirectory: initialDirectory,
      onClose: () => _workspaceController.closeTab(
        _workspaceController.tabs.indexWhere((t) => t.id == newId),
      ),
      onOpenEditor: (p, c) => _openEditorTabForHost(host, p, c),
    );
    _workspaceController.addTab(newTab);
  }

  // Missing helpers
  Set<String> _disabledHostKeys() =>
      widget.settingsController.settings.disabledServerHosts.toSet();
  bool _isHostDisabled(SshHost host, Set<String> disabledKeys) =>
      disabledKeys.any((key) => disabledKeyMatchesHost(key, host));
}
