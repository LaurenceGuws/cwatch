import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/features/servers/models/server_tab_data.dart';
import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/server_action.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/view/features/servers/server_workspace_ui_adapter.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/controller/di/bindings/server_workspace_binding.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'servers/servers_widgets.dart';
import 'server_tab_builder.dart';
import 'server_workspace_controller.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'server_host_surface_controller.dart';
import 'server_host_selection_surface.dart';
import 'server_workspace_runtime.dart';
import 'server_workspace_shell.dart';
import 'server_workspace_tab_surface.dart';

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
  late final ServerWorkspaceRuntime _runtime;
  late final ServerWorkspaceShell _viewShell;
  late final ServerHostSurfaceController _hostSurfaceController;
  late final ServerTabBuilder _tabBuilder;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;
  static int _placeholderSequence = 0;
  bool _showListSettings = false;

  ServerWorkspaceUiAdapter get _uiAdapter => _runtime.uiAdapter;
  DistroCacheController get _distroCacheController =>
      _runtime.distroCacheController;
  ServerWorkspaceController get _workspaceController =>
      _runtime.workspaceController;
  SettingsController get _settingsController => _runtime.settingsController;
  List<SshHost> get _lastHosts => _hostSurfaceController.lastHosts;

  void _toggleListSettings() {
    setState(() {
      _showListSettings = !_showListSettings;
    });
  }

  String _buildCustomHostsSignature() {
    return _hostSurfaceController.buildCustomHostsSignature();
  }

  String _buildPathsSignature() {
    return _hostSurfaceController.buildPathsSignature();
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
        onHostActivate: (host) => _viewShell.activateEmptyTab(id, host),
        onAction: (host, action) => _viewShell.replaceTabWithAction(id, host, action),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _hostSurfaceController = ServerHostSurfaceController(
      appSettingsController: widget.settingsController,
      distroManager: () => _runtime.distroManager,
    );
    _viewShell = ServerWorkspaceShell(
      moduleId: widget.moduleId,
      loadHosts: _hostSurfaceController.loadHosts,
      updateCustomHosts: (customHosts) => _hostSurfaceController.updateCustomHosts(
        customHosts,
        onHostsChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
      buildCustomHostsSignature: _buildCustomHostsSignature,
      buildPathsSignature: _buildPathsSignature,
      buildDisabledHostsSignature: _buildDisabledHostsSignature,
      setHostsFuture: _hostSurfaceController.setHostsFuture,
      requestViewRefresh: () {
        if (mounted) {
          setState(() {});
        }
      },
      persistedWorkspaceSignature: () =>
          _workspaceController.workspacePersistence.read()?.signature,
      currentWorkspaceSignature: () =>
          _workspaceController.currentWorkspaceSignature(),
      restoreWorkspace: _restoreWorkspace,
      persistIfPending: () async {
        _workspaceController.workspacePersistence.persistIfPending(
          () => _workspaceController.persistState(),
        );
      },
      tabs: () => _tabs,
      selectedIndex: () => _selectedTabIndex,
      selectTab: _selectTab,
      closeTab: (index) => _workspaceController.closeTab(index),
      replaceTab: (tabId, replacement) =>
          _workspaceController.replaceTab(tabId, replacement),
      addTab: (tab) => _workspaceController.addTab(tab),
      createPlaceholderTab: _createPlaceholderTab,
      createTab: _createTab,
      onHostInteraction: _ensureDistroOnInteraction,
      openPortForwardDialog: _openPortForwardDialog,
      pickAction: (host) => ActionPickerDialog.show(context, host),
      renameTab: _renameTab,
      customHosts: () => widget.settingsController.settings.sshPreferences.customHosts,
    );
    final initialHostsFuture = _viewShell.initializeHosts();
    _hostSurfaceController.setHostsFuture(initialHostsFuture);
    _tabBuilder = ServerTabBuilder(
      settingsController: widget.settingsController,
      trashManager: ExplorerTrashManager(),
      shellServiceForHost: (host) => widget.shellFactory.forHost(host),
      keyService: widget.keyService,
      hostsFuture: initialHostsFuture,
    );
    _runtime = _binding.createRuntime(
      context: context,
      appSettingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsFuture: initialHostsFuture,
      hostsLoader: _hostSurfaceController.loadHosts,
      tabBuilder: _tabBuilder,
      baseTabBuilder: _createPlaceholderTab,
    );

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'server-tab',
    );
    _viewShell.initializeWorkspaceChrome();

    _tabsListener = () {
      setState(() {});
    };
    _workspaceController.addListener(_tabsListener);

    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);

    _restoreWorkspace();
  }

  @override
  void didUpdateWidget(covariant ServerWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostsFuture != oldWidget.hostsFuture) {
      _hostSurfaceController.setHostsFuture(_hostSurfaceController.loadHosts());
    }
  }

  @override
  void dispose() {
    _workspaceController.removeListener(_tabsListener);
    _hostSurfaceController.dispose();
    widget.settingsController.removeListener(_settingsListener);
    _viewShell.dispose();
    _runtime.dispose();
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
    return ValueListenableBuilder<Future<List<SshHost>>>(
      valueListenable: _hostSurfaceController.hostsFutureNotifier,
      builder: (context, hostsFuture, _) {
        return ServerHostSelectionSurface(
          hostsFuture: hostsFuture,
          cachedHosts: _lastHosts,
          showListSettings: _showListSettings,
          appSettingsController: widget.settingsController,
          settingsController: _settingsController,
          distroCacheController: _distroCacheController,
          keyService: widget.keyService,
          lastHosts: _lastHosts,
          disabledHostKeys: _disabledHostKeys(),
          trackHostDistroChecks: _hostSurfaceController.trackHostDistroChecks,
          ensureDistroForHostOnDemand: _ensureDistroForHostOnDemand,
          onSelect: onHostSelected,
          onActivate: onHostActivate ?? _viewShell.startActionFlowForHost,
          onAction: onAction,
          onOpenConnectivity: (host) => _addServerTab(host, ServerAction.connectivity),
          onOpenResources: (host) => _addServerTab(host, ServerAction.resources),
          onOpenTerminal: (host) => _addServerTab(host, ServerAction.terminal),
          onOpenExplorer: (host) => _addServerTab(host, ServerAction.fileExplorer),
          onOpenPortForward: _openPortForwardDialog,
          onHostsChanged: () {
            setState(() {});
          },
          onAddServer: (existingNames) => _showAddServerDialog(context, existingNames),
          onToggleDisabledServersVisibility: () {
            AppLogger().debug(
              'Toggle disabled servers visibility',
              tag: 'ServersList',
            );
          },
          onCloseSettings: _toggleListSettings,
        );
      },
    );
  }
  
  void _ensureDistroForHostOnDemand(SshHost host) {
    _hostSurfaceController.ensureDistroForHostOnDemand(
      host,
      disabledHostKeys: _disabledHostKeys(),
    );
  }

  Widget _buildTabWorkspace() {
    return ServerWorkspaceTabSurface(
      controller: _workspaceController,
      registry: _tabRegistry,
      leading: widget.leading,
      useSystemDecorations: widget
          .settingsController
          .settings
          .shellPreferences.useSystemDecorations,
      selectedTabIndex: _selectedTabIndex,
      showListSettings: _showListSettings,
      onSelectTab: _selectTab,
      onAddTab: _viewShell.startEmptyTab,
      onRenameTab: _renameTab,
      onOpenAddServerDialog: _openAddServerDialog,
      onReloadServerList: _reloadServerListView,
      onToggleListSettings: _toggleListSettings,
      closeWarningForTab: _closeWarningForTab,
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

  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_viewShell.handleSettingsChanged());
  }

  String _buildDisabledHostsSignature() {
    final disabled = [...widget.settingsController.settings.sshPreferences.disabledServerHosts]
      ..sort();
    return disabled.join('|');
  }

  void _reloadServerListView() {
    if (!mounted) return;
    AppLogger().debug('ServersList manual reload', tag: 'ServersList');
    _viewShell.reloadServerList();
    _hostSurfaceController.resetAvailabilityTracking();
  }

  void _addServerTab(SshHost host, ServerAction action) {
    _ensureDistroOnInteraction(host);
    _viewShell.addTab(host, action);
  }

  Future<void> _restoreWorkspace() async {
    final hosts = await _workspaceController.loadHosts();
    if (!mounted) return;
    await _workspaceController.restore(
      buildEmptyTab: _tabBuilder.emptyTab,
      buildExplorerTab: _tabBuilder.explorerTab,
      buildEditorTab: _tabBuilder.editorTab,
      buildTerminalTab: _tabBuilder.terminalTab,
      buildResourcesTab: _tabBuilder.resourcesTab,
      buildConnectivityTab: _tabBuilder.connectivityTab,
      buildTrashTab: _tabBuilder.trashTab,
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
            _viewShell.activateEmptyTab(tabId, selectedHost),
        onAction: (host, action) =>
            _viewShell.replaceTabWithAction(tabId, host, action),
      ),
    );
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
            onHostActivate: (host) => _viewShell.activateEmptyTab(id, host),
            onAction: (host, action) =>
                _viewShell.replaceTabWithAction(id, host, action),
          ),
        );
    }
  }

  void _ensureDistroOnInteraction(SshHost host) {
    // Trigger distro detection on user interaction
    _ensureDistroForHostOnDemand(host);
  }

  Future<void> _openPortForwardDialog(SshHost host) {
    return _runtime.portForwardController.openDialog(host);
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
      final ssh = current.sshPreferences;
      final hosts = [...ssh.customHosts, result];
      final bindings = Map<String, String>.from(
        ssh.builtinHostKeyBindings,
      );
      if (result.identityFile != null && result.identityFile!.isNotEmpty) {
        bindings[result.name] = result.identityFile!;
      }
      widget.settingsController.update(
        (settings) => settings.copyWith(
          sshPreferences: settings.sshPreferences.copyWith(
            customHosts: hosts,
            builtinHostKeyBindings: bindings,
          ),
        ),
      );
    }
  }

  void _openAddServerDialog() {
    final existingNames = _lastHosts.isNotEmpty
        ? _lastHosts.map((host) => host.name).toList()
        : widget.settingsController.settings.sshPreferences.customHosts
            .map((host) => host.name)
            .toList();
    _showAddServerDialog(context, existingNames);
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
      widget.settingsController.settings.sshPreferences.disabledServerHosts.toSet();
}
