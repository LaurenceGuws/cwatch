import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/models/docker_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_command_logging.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/ssh/ssh_shell_factory.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';
import 'package:cwatch/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/core/navigation/command_palette_registry.dart';
import 'package:cwatch/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/core/widgets/keep_alive.dart';
import 'engine_tab.dart';
import 'widgets/docker_engine_picker.dart';
import 'widgets/remote_scan_dialog.dart';
import '../services/docker_container_shell_service.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'docker_tab_factory.dart';
import 'docker_workspace_controller.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';

class DockerView extends StatefulWidget {
  const DockerView({
    super.key,
    required this.moduleId,
    this.leading,
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.commandLog,
    required this.shellFactory,
  });

  final String moduleId;
  final Widget? leading;
  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final RemoteCommandLogController commandLog;
  final SshShellFactory shellFactory;

  @override
  State<DockerView> createState() => _DockerViewState();
}

class _DockerViewState extends State<DockerView> {
  final DockerClientService _docker = const DockerClientService();
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();
  final PortForwardService _portForwardService = PortForwardService();
  DockerTabFactory get _tabFactory => DockerTabFactory(
    docker: _docker,
    settingsController: widget.settingsController,
    trashManager: _trashManager,
    keyService: widget.keyService,
    portForwardService: _portForwardService,
  );
  late final TabHostController<EngineTab> _tabController;
  final Map<String, TabState> _tabStates = {};
  late final TabViewRegistry<EngineTab> _tabRegistry;
  List<EngineTab> _tabSnapshot = const [];
  late final DockerWorkspaceController _workspaceController;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;

  Future<List<DockerContext>>? _contextsFuture;
  Future<List<RemoteDockerStatus>>? _remoteStatusFuture;
  bool _remoteScanRequested = false;
  bool _scanningRemotes = false;
  int _scanToken = 0;
  final Set<int> _cancelledScans = {};
  final ValueNotifier<List<SshHost>> _scanHostsNotifier =
      ValueNotifier<List<SshHost>>(const []);
  final ValueNotifier<List<RemoteDockerStatus>> _scanStatusesNotifier =
      ValueNotifier<List<RemoteDockerStatus>>(const []);
  final ValueNotifier<bool> _scanningNotifier = ValueNotifier<bool>(false);
  List<RemoteDockerStatus> _cachedReady = const [];

  List<EngineTab> get _tabs => _tabController.tabs;
  int get _selectedIndex => _tabController.selectedIndex;
  void _replaceBaseTab(EngineTab tab) {
    final selectedId = _tabs.isEmpty
        ? null
        : _tabs[_selectedIndex.clamp(0, _tabs.length - 1)].id;
    if (_tabController.tabs.isEmpty) {
      _tabController.addTab(tab);
    } else {
      _tabRegistry.remove(_tabController.tabs.first);
      _tabController.replaceBaseTab(tab);
    }
    _tabRegistry.widgetFor(tab, () => tab.body);
    if (selectedId != null) {
      final restoredIndex = _tabs.indexWhere((t) => t.id == selectedId);
      if (restoredIndex != -1) {
        _tabController.select(restoredIndex);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _contextsFuture = _loadContexts();
    _tabController = TabHostController<EngineTab>(
      baseTabBuilder: () => _enginePickerTab(),
      tabId: (tab) => tab.id,
    );
    _tabRegistry = TabViewRegistry<EngineTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'engine-tab',
    );
    _tabNavigator = TabNavigationHandle(
      next: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final next = (_selectedIndex + 1) % length;
        _tabController.select(next);
        return true;
      },
      previous: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final prev = (_selectedIndex - 1 + length) % length;
        _tabController.select(prev);
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
    final picker = _tabController.tabs.first;
    _tabRegistry.widgetFor(picker, () => picker.body);
    _registerTabState(picker.workspaceState as TabState);
    _tabSnapshot = _tabController.tabs.toList();
    _tabsListener = _handleTabsChanged;
    _tabController.addListener(_tabsListener);
    _settingsListener = _handleSettingsChanged;
    _workspaceController = DockerWorkspaceController(
      settingsController: widget.settingsController,
    );
    _portForwardService.setAuthCoordinator(widget.shellFactory.authCoordinator);
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabsListener);
    widget.settingsController.removeListener(_settingsListener);
    _portForwardService.dispose();
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      widget.moduleId,
      _commandPaletteHandle,
    );
    super.dispose();
  }

  EngineTab _enginePickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    final tab = EngineTab(
      id: tabId,
      title: 'Docker Engines',
      label: 'Docker Engines',
      icon: NerdIcon.docker.data,
      canDrag: false,
      isPicker: true,
      workspaceState: TabState(id: tabId, kind: DockerTabKind.picker.name),
      body: EnginePicker(
        tabId: tabId,
        contextsFuture: _contextsFuture,
        cachedReady: _cachedReady,
        remoteStatusFuture: _remoteStatusFuture,
        remoteScanRequested: _remoteScanRequested,
        onRefreshContexts: _refreshContexts,
        onScanRemotes: _scanRemotes,
        onOpenContext: (contextName, anchor) =>
            _openContextDashboard(tabId, contextName, anchor),
        onOpenHost: (host, anchor) => _openHostDashboard(tabId, host, anchor),
        settingsController: widget.settingsController,
      ),
    );
    _tabStates[tab.id] = TabState(id: tab.id, kind: DockerTabKind.picker.name);
    return tab;
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<List<DockerContext>> _loadContexts() async {
    try {
      return await _docker.listContexts();
    } catch (_) {
      return const <DockerContext>[];
    }
  }

  void _refreshContexts() {
    _contextsFuture = _loadContexts();
    final currentId = _tabs.first.id;
    final picker = _enginePickerTab(id: currentId);
    _disposeTabOptions(_tabs[0]);
    _tabRegistry.remove(_tabs[0]);
    _replaceBaseTab(picker);
    _registerTabState(picker.workspaceState as TabState);
    _persistWorkspace();
  }

  void _scanRemotes() {
    if (_scanningRemotes) return;
    final token = ++_scanToken;
    _scanningRemotes = true;
    _scanningNotifier.value = true;
    _remoteScanRequested = true;
    _scanStatusesNotifier.value = const [];
    _remoteStatusFuture = _loadRemoteStatuses(manual: true, token: token);
    bool dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return RemoteScanDialog(
          onCancel: () {
            _cancelledScans.add(token);
            dialogOpen = false;
            Navigator.of(dialogContext).pop();
            setState(() {
              _scanningRemotes = false;
              _scanningNotifier.value = false;
            });
          },
          hostsListenable: _scanHostsNotifier,
          statusesListenable: _scanStatusesNotifier,
          scanningListenable: _scanningNotifier,
        );
      },
    );
    _remoteStatusFuture!.whenComplete(() {
      if (!mounted) return;
      if (!_isScanCancelled(token) && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() {
        _scanningRemotes = false;
        _scanningNotifier.value = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Padding(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: context.appTheme.section.toolbarBackground,
              child: TabbedWorkspaceShell<EngineTab>(
                controller: _tabController,
                registry: _tabRegistry,
                tabBarHeight: 36,
                showTabBar: TabBarVisibilityController.instance,
                leading: widget.leading != null
                    ? Padding(
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                        child: SizedBox(
                          height: 36,
                          child: Center(child: widget.leading),
                        ),
                      )
                    : null,
                onReorder: (oldIndex, newIndex) {
                  final selectedTabId = _tabs.isEmpty
                      ? null
                      : _tabs[_selectedIndex].id;
                  if (oldIndex < newIndex) newIndex -= 1;
                  _tabController.reorder(oldIndex, newIndex);
                  if (selectedTabId != null) {
                    final newIndexOfSelected = _tabs.indexWhere(
                      (tab) => tab.id == selectedTabId,
                    );
                    _tabController.select(
                      newIndexOfSelected.clamp(0, _tabs.length - 1),
                    );
                  }
                  _persistWorkspace();
                },
                onAddTab: _addEnginePickerTab,
                buildChip: (context, index, tab) {
                  final optionsController = tab.optionsController;
                  final state = tab.workspaceState is TabState
                      ? tab.workspaceState as TabState
                      : null;
                  final isPicker =
                      tab.isPicker || state?.kind == DockerTabKind.picker.name;
                  final canDrag = tab.canDrag && !isPicker;
                  final canRename = tab.canRename && !isPicker;
                  final closeWarning = _isCommandWorkspace(tab.workspaceState)
                      ? const TabCloseWarning(
                          title: 'Disconnect session?',
                          message:
                              'Closing this tab will end the running shell/command.',
                          confirmLabel: 'Close tab',
                        )
                      : null;
                  Widget buildTab(List<TabChipOption> options) {
                    return TabChip(
                      host: SshHost(
                        name: tab.label,
                        hostname: '',
                        port: 0,
                        available: true,
                      ),
                      title: tab.title,
                      label: tab.label,
                      icon: tab.icon,
                      selected: index == _selectedIndex,
                      onSelect: () {
                        _tabController.select(index);
                        _persistWorkspace();
                      },
                      onClose: () => _closeTab(index),
                      closable: true,
                      onRename: canRename ? () => _renameTab(index) : null,
                      dragIndex: canDrag ? index : null,
                      options: options,
                      closeWarning: closeWarning,
                    );
                  }

                  if (optionsController == null) {
                    return KeyedSubtree(
                      key: ValueKey(tab.id),
                      child: buildTab(const []),
                    );
                  }
                  return ValueListenableBuilder<List<TabChipOption>>(
                    key: ValueKey(tab.id),
                    valueListenable: optionsController,
                    builder: (context, options, _) => buildTab(options),
                  );
                },
                buildBody: (tab) => tab.body,
              ),
            ),
          ),
          Padding(
            padding: context.appTheme.spacing.inset(horizontal: 2, vertical: 0),
            child: Divider(height: 1, color: context.appTheme.section.divider),
          ),
        ],
      ),
    );
  }

  void _addEnginePickerTab() {
    final picker = _enginePickerTab();
    _registerTabState(picker.workspaceState as TabState);
    _tabRegistry.widgetFor(picker, () => picker.body);
    _tabController.addTab(picker);
  }

  void _disposeTabOptions(EngineTab tab) {
    tab.optionsController?.dispose();
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final removedTab = _tabs[index];
    _disposeTabOptions(removedTab);
    _tabStates.remove(removedTab.id);
    _tabRegistry.remove(removedTab);
    _tabSnapshot = _tabController.tabs
        .where((tab) => tab.id != removedTab.id)
        .toList();
    _tabController.closeTab(index);
    _persistWorkspace();
  }

  List<CommandPaletteEntry> _buildCommandPaletteEntries() {
    final entries = <CommandPaletteEntry>[];
    if (_tabs.isNotEmpty) {
      final tab = _tabs[_selectedIndex];
      final options = tab.optionsController?.value ?? const <TabChipOption>[];
      entries.addAll(
        options.map(
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
          onSelected: () => _renameTab(_selectedIndex),
        ),
      );
      entries.add(
        CommandPaletteEntry(
          id: '${widget.moduleId}:closeTab',
          label: 'Close tab',
          category: 'Tabs',
          onSelected: () => _closeTab(_selectedIndex),
        ),
      );
    }
    entries.add(
      CommandPaletteEntry(
        id: '${widget.moduleId}:newTab',
        label: 'New tab',
        category: 'Tabs',
        onSelected: _addEnginePickerTab,
      ),
    );
    return entries;
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;
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
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == tab.title) return;

    final updated = tab.copyWith(title: trimmed, label: trimmed);
    final state = _resolvedStateForTab(tab);
    if (state != null) {
      _tabStates[tab.id] = _copyStateWithTitle(state, trimmed);
    }
    _tabRegistry.widgetFor(updated, () => updated.body);
    _tabController.replaceTab(tab.id, updated);
    setState(() {});
    unawaited(_persistWorkspace());
  }

  Future<void> _openContextDashboard(
    String tabId,
    String contextName,
    Offset? anchor,
  ) async {
    final icons = context.appTheme.icons;
    final choice = await _pickDashboardTarget(contextName, icons.cloud, anchor);
    if (choice == null || !mounted) return;
    final newId = 'ctx-$contextName-${DateTime.now().microsecondsSinceEpoch}';
    final newTab = choice == _DashboardTarget.resources
        ? _buildResourcesTab(
            id: newId,
            title: contextName,
            label: contextName,
            icon: icons.cloud,
            contextName: contextName,
          )
        : _buildOverviewTab(
            id: newId,
            title: contextName,
            label: contextName,
            icon: icons.cloud,
            contextName: contextName,
          );
    _replaceTab(tabId, newTab);
  }

  Future<void> _openHostDashboard(
    String tabId,
    SshHost host,
    Offset? anchor,
  ) async {
    final shell = _shellServiceForHost(host);
    final icons = context.appTheme.icons;
    final choice = await _pickDashboardTarget(
      host.name,
      icons.cloudOutline,
      anchor,
    );
    if (choice == null || !mounted) return;
    final newId = 'host-${host.name}-${DateTime.now().microsecondsSinceEpoch}';
    final newTab = choice == _DashboardTarget.resources
        ? _buildResourcesTab(
            id: newId,
            title: host.name,
            label: host.name,
            icon: icons.cloudOutline,
            remoteHost: host,
            shellService: shell,
          )
        : _buildOverviewTab(
            id: newId,
            title: host.name,
            label: host.name,
            icon: icons.cloudOutline,
            remoteHost: host,
            shellService: shell,
          );
    _replaceTab(tabId, newTab);
  }

  void _replaceTab(String tabId, EngineTab tab) {
    final currentIndex = _tabs.indexWhere((existing) => existing.id == tabId);
    if (currentIndex == -1) {
      return;
    }
    _disposeTabOptions(_tabs[currentIndex]);
    _tabStates.remove(tabId);
    _tabRegistry.remove(_tabs[currentIndex]);
    if (tab.workspaceState is TabState) {
      _registerTabState(tab.workspaceState as TabState);
    }
    _tabRegistry.widgetFor(tab, () => tab.body);
    _tabController.replaceTab(tabId, tab);
  }

  Future<_DashboardTarget?> _pickDashboardTarget(
    String title,
    IconData icon,
    Offset? anchor,
  ) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlay = overlayState.context.findRenderObject() as RenderBox?;
    final overlaySize = overlay?.size ?? MediaQuery.sizeOf(context);
    final overlayBase = overlay?.localToGlobal(Offset.zero) ?? Offset.zero;
    final anchorPoint =
        anchor ??
        overlayBase + Offset(overlaySize.width / 2, overlaySize.height / 2);
    final left = anchorPoint.dx - overlayBase.dx;
    final top = anchorPoint.dy - overlayBase.dy;
    return showMenu<_DashboardTarget>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlaySize.width - left,
        overlaySize.height - top,
      ),
      items: [
        PopupMenuItem(
          value: _DashboardTarget.overview,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: const Text('Overview'),
            subtitle: const Text('Containers, images, networks, volumes'),
          ),
        ),
        PopupMenuItem(
          value: _DashboardTarget.resources,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              context.appTheme.icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Resources'),
            subtitle: const Text('Resource usage and performance'),
          ),
        ),
      ],
    );
  }

  Future<void> _loadCachedReady() async {
    final cached = await _workspaceController.loadCachedReady(
      widget.hostsFuture,
    );
    if (!mounted) return;
    setState(() {
      _cachedReady = cached;
      _refreshPickerTabs();
    });
  }

  Future<List<RemoteDockerStatus>> _loadRemoteStatuses({
    bool manual = false,
    int token = 0,
  }) async {
    List<SshHost> hosts;
    try {
      hosts = await widget.hostsFuture;
    } catch (error) {
      throw Exception('Failed to load SSH hosts: $error');
    }
    if (!mounted || hosts.isEmpty) {
      return const [];
    }
    setState(() {
      _scanHostsNotifier.value = hosts;
    });
    final statuses = await _workspaceController.discoverRemoteStatuses(
      hostsFuture: widget.hostsFuture,
      probeHost: _probeHost,
      manual: manual,
      cancelled: _isScanCancelled(token),
    );
    final ready = statuses.where((s) => s.available).toList();
    if (manual && !_isScanCancelled(token)) {
      if (mounted) {
        setState(() {
          _scanStatusesNotifier.value = statuses;
          _cachedReady = ready;
        });
        _refreshPickerTabs();
      }
    }
    return statuses;
  }

  bool _isScanCancelled(int token) => _cancelledScans.contains(token);

  bool _isCommandWorkspace(Object? workspaceState) {
    if (workspaceState is TabState) {
      return workspaceState.kind == DockerTabKind.command.name;
    }
    return false;
  }

  void _refreshPickerTabs() {
    final pickerIds = _tabs
        .where((tab) {
          if (tab.workspaceState is TabState) {
            final state = tab.workspaceState as TabState;
            return state.kind == DockerTabKind.picker.name;
          }
          return tab.body is EnginePicker;
        })
        .map((t) => t.id)
        .toList();
    for (final id in pickerIds) {
      _replaceTab(id, _enginePickerTab(id: id));
    }
  }

  Future<RemoteDockerStatus> _probeHost(SshHost host) async {
    final shell = _shellServiceForHost(host);
    const probeCommand =
        "if command -v docker >/dev/null 2>&1; then docker info >/dev/null 2>&1 && echo '__DOCKER_OK__' || echo '__DOCKER_ERROR__'; else echo '__NO_DOCKER__'; fi";
    try {
      final output = await shell.runCommand(
        host,
        probeCommand,
        timeout: const Duration(seconds: 8),
      );
      final trimmed = output.trim();
      if (trimmed.contains('__DOCKER_OK__')) {
        return RemoteDockerStatus(host: host, available: true, detail: 'Ready');
      }
      if (trimmed.contains('__NO_DOCKER__')) {
        return RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker not installed',
        );
      }
      if (trimmed.contains('__DOCKER_ERROR__')) {
        return RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker command failed',
        );
      }
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: trimmed.isEmpty
            ? 'Unknown response'
            : trimmed.split('\n').first,
      );
    } catch (error, stack) {
      AppLogger.w(
        'Docker probe failed for ${host.name}: $error',
        tag: 'Docker',
        stackTrace: stack,
      );
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: error.toString(),
      );
    }
  }

  RemoteShellService _shellServiceForHost(SshHost host) {
    return widget.shellFactory.forHost(host);
  }

  void _openChildTab(EngineTab tab) {
    final uniqueId = _ensureUniqueId(tab.id);
    final uniqueTab = tab.copyWith(id: uniqueId);
    _tabRegistry.widgetFor(uniqueTab, () => uniqueTab.body);
    _tabController.addTab(uniqueTab);
    TabState? state;
    if (uniqueTab.workspaceState is TabState) {
      state = uniqueTab.workspaceState as TabState;
    } else {
      state = _tabStateFromBody(
        uniqueTab.id,
        uniqueTab.body,
        uniqueTab.workspaceState is TabState
            ? uniqueTab.workspaceState as TabState
            : null,
      );
    }
    if (state != null) {
      _registerTabState(_workspaceController.copyStateWithId(state, uniqueId));
    }
    _persistWorkspace();
  }

  EngineTab _buildOverviewTab({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
  }) {
    return _tabFactory.overview(
      id: id,
      title: title,
      label: label,
      icon: icon,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      onOpenTab: _openChildTab,
      onCloseTab: _closeTabById,
    );
  }

  EngineTab _buildResourcesTab({
    required String id,
    required String title,
    required String label,
    required IconData icon,
    String? contextName,
    SshHost? remoteHost,
    RemoteShellService? shellService,
  }) {
    return _tabFactory.resources(
      id: id,
      title: title,
      label: label,
      icon: icon,
      contextName: contextName,
      remoteHost: remoteHost,
      shellService: shellService,
      onOpenTab: _openChildTab,
      onCloseTab: _closeTabById,
    );
  }

  void _closeTabById(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index == -1) return;
    _closeTab(index);
  }

  TabState? _tabStateFromBody(
    String id,
    Widget body,
    TabState? workspaceState,
  ) {
    return _workspaceController.tabStateFromBody(
      id,
      body,
      workspaceState: workspaceState,
    );
  }

  TabState? _resolvedStateForTab(EngineTab tab) {
    TabState? workspaceState;
    if (tab.workspaceState is TabState) {
      workspaceState = tab.workspaceState as TabState;
    }
    return _tabStates[tab.id] ??
        workspaceState ??
        _tabStateFromBody(tab.id, tab.body, workspaceState);
  }

  TabState _copyStateWithTitle(TabState state, String title) {
    return state.copyWith(title: title, label: state.label ?? title);
  }

  void _registerTabState(TabState? state) {
    if (state == null) return;
    _tabStates[state.id] = state;
  }

  DockerWorkspaceState _currentWorkspaceState() {
    return _workspaceController.currentWorkspaceState(
      tabs: _tabs,
      selectedIndex: _selectedIndex,
      explicitStates: _tabStates,
    );
  }

  Future<void> _persistWorkspace() async {
    final workspace = _currentWorkspaceState();
    await _workspaceController.workspacePersistence.persist(workspace);
  }

  void _updateExplorerPath(String tabId, String path) {
    final existing = _tabStates[tabId];
    final kind = existing?.kind ?? DockerTabKind.containerExplorer.name;
    _tabStates[tabId] = (existing ?? TabState(id: tabId, kind: kind)).copyWith(
      path: path,
    );
    unawaited(_persistWorkspace());
  }

  void _handleSettingsChanged() {
    if (!mounted) return;
    unawaited(_restoreWorkspace());
    _workspaceController.workspacePersistence.persistIfPending(
      _persistWorkspace,
    );
  }

  void _handleTabsChanged() {
    final currentTabs = _tabController.tabs;
    final currentIds = currentTabs.map((tab) => tab.id).toSet();
    final removed = _tabSnapshot.where((tab) => !currentIds.contains(tab.id));
    for (final tab in removed) {
      _tabStates.remove(tab.id);
      _tabRegistry.remove(tab);
    }
    final previousIds = _tabSnapshot.map((tab) => tab.id).toSet();
    for (final tab in currentTabs) {
      if (!previousIds.contains(tab.id)) {
        _registerTabState(
          tab.workspaceState is TabState
              ? tab.workspaceState as TabState
              : _tabStateFromBody(tab.id, tab.body, null),
        );
      }
      _tabRegistry.widgetFor(tab, () => tab.body);
    }
    _tabSnapshot = currentTabs.toList();
    setState(() {});
    unawaited(_persistWorkspace());
  }

  Future<void> _restoreWorkspace() async {
    DockerWorkspaceState? workspace;
    List<SshHost> hosts = const [];
    try {
      hosts = await widget.hostsFuture;
      workspace = widget.settingsController.settings.dockerWorkspace;
    } catch (_) {
      workspace = widget.settingsController.settings.dockerWorkspace;
    }
    if (!mounted) return;

    if (workspace == null || workspace.tabs.isEmpty) {
      setState(() {
        final picker = _enginePickerTab();
        _tabStates
          ..clear()
          ..addAll({
            picker.id: TabState(id: picker.id, kind: DockerTabKind.picker.name),
          });
        _tabRegistry.reset([picker]);
        _tabController.replaceAll([picker]);
      });
      return;
    }
    if (!_workspaceController.workspacePersistence.shouldRestore(workspace)) {
      return;
    }
    final restored = _workspaceController.buildTabsFromState(
      workspace: workspace,
      hosts: hosts,
      buildTab: (state) => _tabFromState(state, hosts),
    );
    final newTabs = restored.tabs;
    final newStates = restored.states;

    if (newTabs.isEmpty) {
      final picker = _enginePickerTab();
      newTabs.add(picker);
      newStates[picker.id] = TabState(
        id: picker.id,
        kind: DockerTabKind.picker.name,
      );
    }

    final restoredWorkspace = workspace;
    final selected = restoredWorkspace.selectedIndex.clamp(
      0,
      newTabs.length - 1,
    );

    _tabStates
      ..clear()
      ..addAll(newStates);
    _tabRegistry.reset(newTabs);
    _tabController.replaceAll(newTabs, selectedIndex: selected);
    _tabSnapshot = _tabController.tabs.toList();
    _workspaceController.workspacePersistence.markRestored(restoredWorkspace);
    unawaited(_loadCachedReady());
  }

  EngineTab? _tabFromState(TabState state, List<SshHost> hosts) {
    final icons = context.appTheme.icons;
    return _workspaceController.tabFromState(
      state: state,
      hosts: hosts,
      builders: TabBuilders(
        buildPlaceholder: ({required id}) => _enginePickerTab(id: id),
        buildPicker: ({required id}) => _enginePickerTab(id: id),
        buildOverview: _buildOverviewTab,
        buildResources: _buildResourcesTab,
        buildCommand: _tabFactory.commandTerminal,
        buildComposeLogs: _tabFactory.composeLogs,
        buildExplorer: _tabFactory.explorer,
        buildEditor: _tabFactory.containerEditor,
        cloudIcon: icons.cloud,
        cloudOutlineIcon: icons.cloudOutline,
        commandIcon: NerdIcon.terminal.data,
        composeIcon: NerdIcon.terminal.data,
        explorerIcon: icons.folderOpen,
        editorIcon: icons.edit,
        shellForHost: _shellServiceForHost,
        containerShell: _containerShell,
        dockerContextNameFor: _dockerContextNameFor,
        closeTab: _closeTabById,
        onOpenTab: _openChildTab,
        onExplorerPathChanged: _updateExplorerPath,
      ),
    );
  }

  String _ensureUniqueId(String base) {
    var candidate = base;
    var counter = 1;
    final existing = _tabs.map((t) => t.id).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-${counter++}';
    }
    return candidate;
  }

  RemoteShellService? _containerShell(
    SshHost? host,
    String? containerId, {
    String? contextName,
  }) {
    final id = containerId ?? '';
    if (host == null || host.name == 'local') {
      return LocalDockerContainerShellService(
        containerId: id,
        contextName: contextName,
      );
    }
    return DockerContainerShellService(
      host: host,
      containerId: id,
      baseShell: _shellServiceForHost(host),
    );
  }

  String _dockerContextNameFor(SshHost host, String? contextName) {
    final trimmed = contextName?.trim();
    if (trimmed?.isNotEmpty == true) {
      return trimmed!;
    }
    return '${host.name}-docker';
  }
}

enum _DashboardTarget { overview, resources }
