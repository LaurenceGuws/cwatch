import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/port_forwarding/port_forward_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/workspace_root_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/view/core/tabs/workspace_tab_chip_builder.dart';
import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'widgets/docker_engine_picker.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'docker_tab_builder.dart';
import 'docker_workspace_controller.dart';
import 'docker_workspace_tab_restorer.dart';
import 'package:cwatch/view/features/settings/settings/docker_settings_controls.dart';
import 'package:cwatch/controller/adapters/docker_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/di/bindings/docker_client_service_binding.dart';
import 'package:cwatch/controller/di/bindings/docker_shell_callbacks_binding.dart';
import 'package:cwatch/controller/di/bindings/docker_view_binding.dart';
import 'docker_local_state_controller.dart';
import 'docker_view_runtime.dart';
import 'docker_view_shell.dart';

class DockerView extends StatefulWidget {
  const DockerView({
    super.key,
    required this.moduleId,
    this.leading,
    required this.hostsFuture,
    required this.settingsController,
    required this.keyService,
    required this.shellFactory,
  });

  final String moduleId;
  final Widget? leading;
  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final SshShellFactory shellFactory;

  @override
  State<DockerView> createState() => _DockerViewState();
}

class _DockerViewState extends State<DockerView> {
  final DockerViewBinding _viewBinding = const DockerViewBinding();
  late final DockerViewRuntime _runtime;
  late final DockerClientService _docker;
  late final DockerViewController _viewController;
  late final DistroCacheController _distroCacheController;
  late final DockerShellCallbacks _shellCallbacks;
  late final DockerTabBuilder _tabBuilder;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;
  late final DockerUiAdapter _uiAdapter;
  late final DockerLocalStateController _localStateController;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final VoidCallback _viewControllerListener;
  late final DockerViewShell _viewShell;
  bool _showListSettings = false;

  DockerWorkspaceController get _workspaceController =>
      _runtime.workspaceController;

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedIndex => _workspaceController.selectedIndex;

  void _toggleListSettings() {
    setState(() {
      _showListSettings = !_showListSettings;
    });
    // In new architecture, we might not need to sync overlay options manually
    // if the builder rebuilds them correctly.
  }

  void _replaceTab(String tabId, WorkspaceTab tab) {
    _workspaceController.replaceTab(tabId, tab);
  }

  @override
  void initState() {
    super.initState();
    _distroCacheController = DistroCacheController(
      initialServerCache: widget.settingsController.settings.serverDistroMap,
      initialDockerCache: widget.settingsController.settings.dockerDistroMap,
    );
    _docker = const DockerClientServiceBinding().create();
    _viewController = _viewBinding.createController(docker: _docker);
    _shellCallbacks = const DockerShellCallbacksBinding().create(
      shellFactory: widget.shellFactory,
    );
    final trashManager = ExplorerTrashManager();
    final portForwardService = PortForwardService()
      ..setAuthCoordinator(widget.shellFactory.authCoordinator);
    _tabBuilder = DockerTabBuilder(
      docker: _docker,
      settingsController: widget.settingsController,
      distroCacheController: _distroCacheController,
      trashManager: trashManager,
      keyService: widget.keyService,
      portForwardService: portForwardService,
      hostsFuture: widget.hostsFuture,
    );
    final workspaceController = DockerWorkspaceController(
      settingsController: widget.settingsController,
      workspaceRootController: WorkspaceRootController(
        settingsController: widget.settingsController,
      ),
      baseTabBuilder: _enginePickerTab,
    );
    _localStateController = DockerLocalStateController(
      settingsController: widget.settingsController,
      workspaceController: workspaceController,
      viewController: _viewController,
      shellFactory: widget.shellFactory,
      hostsFuture: widget.hostsFuture,
      requestRefresh: () {
        if (mounted) {
          setState(() {});
        }
      },
      refreshPickerTabs: _refreshPickerTabs,
    );
    _runtime = _viewBinding.createRuntime(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      shellFactory: widget.shellFactory,
      hostsFuture: widget.hostsFuture,
      docker: _docker,
      viewController: _viewController,
      distroCacheController: _distroCacheController,
      trashManager: trashManager,
      portForwardService: portForwardService,
      shellCallbacks: _shellCallbacks,
      tabBuilder: _tabBuilder,
      workspaceController: workspaceController,
    );
    _viewControllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _viewController.addListener(_viewControllerListener);
    _uiAdapter = DockerUiAdapter(context: context);

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'engine-tab',
    );
    _viewShell = DockerViewShell(
      moduleId: widget.moduleId,
      runtime: _runtime,
      viewController: _viewController,
      tabs: () => _tabs,
      selectedIndex: () => _selectedIndex,
      buildPickerTab: _enginePickerTab,
      replaceTab: _replaceTab,
      addPickerTab: _addEnginePickerTab,
      closeTab: (index) => _workspaceController.closeTab(index),
      renameTab: _renameTab,
    );
    unawaited(_viewShell.initialize());

    _tabsListener = () {
      setState(() {});
    };
    _workspaceController.addListener(_tabsListener);

    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void dispose() {
    _workspaceController.removeListener(_tabsListener);
    _viewController.removeListener(_viewControllerListener);
    widget.settingsController.removeListener(_settingsListener);
    _localStateController.dispose();
    _viewShell.dispose();
    _runtime.dispose();
    super.dispose();
  }

  WorkspaceTab _enginePickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    return _tabBuilder.picker(
      id: tabId,
      body: Builder(
        builder: (_) => _buildPickerBody(tabId),
      ),
    );
  }

  Widget _buildPickerBody(String tabId) {
    return Stack(
      children: [
        EnginePicker(
          tabId: tabId,
          contextsFuture: _viewController.contextsFuture,
          contextsStatusFuture: _localStateController.ensureLocalContextsStatusFuture(),
          cachedReady: _localStateController.cachedReady,
          cachedReadyNotifier: _localStateController.cachedReadyNotifier,
          remoteStatusFuture: _localStateController.remoteStatusFuture,
          remoteScanRequested: _localStateController.remoteScanRequested,
          onRefreshContexts: _refreshContexts,
          onScanRemotes: _scanRemotes,
          onOpenContext: (contextName, anchor) =>
              _openContextDashboard(tabId, contextName, anchor),
          onOpenHost: (host, anchor) => _openHostDashboard(tabId, host, anchor),
          settingsController: widget.settingsController,
          distroCacheController: _distroCacheController,
          dockerService: _docker,
          shellFactory: widget.shellFactory,
        ),
        if (_showListSettings)
          FloatingSettingsWindow(
            title: 'Docker List Settings',
            onClose: _toggleListSettings,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Scan for remote engines'),
                  leading: const Icon(Icons.radar),
                  onTap: () {
                    _scanRemotes();
                    _toggleListSettings();
                  },
                ),
                const Divider(),
                DockerSettingsControls(
                  logsTail:
                      widget.settingsController.settings.dockerPreferences.logsTail,
                  onLogsTailChanged: (value) => widget.settingsController
                      .update(
                        (s) => s.copyWith(
                          dockerPreferences: s.dockerPreferences.copyWith(
                            logsTail: value,
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _refreshContexts() {
    _localStateController.refreshContexts();
    _viewShell.refreshContexts();
  }

  void _scanRemotes() {
    if (_localStateController.scanningRemotes) return;
    final token = _localStateController.beginRemoteScan();
    unawaited(
      _uiAdapter.showRemoteScanDialog(
        onCancel: () {
          _localStateController.cancelRemoteScan(token);
        },
        hostsListenable: _localStateController.scanHostsNotifier,
        statusesListenable: _localStateController.scanStatusesNotifier,
        scanningListenable: _localStateController.scanningNotifier,
        onComplete: () async {
          if (!mounted) return;
          await _localStateController.completeRemoteScan(token);
        },
      ),
    );
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
              child: TabbedWorkspaceShell<WorkspaceTab>(
                controller: _workspaceController,
                registry: _tabRegistry,
                tabBarHeight: 36,
                showTabBar: TabBarVisibilityController.instance,
                enableWindowDrag: !widget
                    .settingsController
                    .settings
                    .shellPreferences.useSystemDecorations,
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
                onReorder: _workspaceController.reorder,
                onAddTab: _viewShell.addEnginePickerTab,
                buildChip: (context, index, tab) {
                  final data = tab.workspaceState as DockerTabData?;
                  final isPicker =
                      tab.isPicker || data?.kind == DockerTabKind.picker;
                  final canDrag = tab.canDrag && !isPicker;
                  final canRename = tab.canRename && !isPicker;
                  final closeWarning = _isCommandWorkspace(data)
                      ? const TabCloseWarning(
                          title: 'Disconnect session?',
                          message:
                              'Closing this tab will end the running shell/command.',
                          confirmLabel: 'Close tab',
                        )
                      : null;
                  return WorkspaceTabChipBuilder(
                    tab: tab,
                    selected: index == _selectedIndex,
                    host: SshHost(
                      name: tab.label,
                      hostname: '',
                      port: 0,
                      available: true,
                    ),
                    onSelect: () => _workspaceController.select(index),
                    onClose: () => _workspaceController.closeTab(index),
                    onRename: () => _renameTab(index),
                    index: index,
                    canRename: canRename,
                    canDrag: canDrag,
                    closeWarning: closeWarning,
                    extraOptions: [
                      if (isPicker)
                        TabChipOption(
                          label: _showListSettings
                              ? 'Hide list settings'
                              : 'List settings',
                          icon: Icons.settings,
                          onSelected: _toggleListSettings,
                        ),
                    ],
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
    _workspaceController.addTab(_enginePickerTab());
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

    // Update title
    final updated = tab.copyWith(title: trimmed, label: trimmed);
    // Update persisted state title
    if (tab.workspaceState is DockerTabData) {
      final data = tab.workspaceState as DockerTabData;
      final newState = data.persistedState.copyWith(
        title: trimmed,
        label: trimmed,
      );
      // We need to update the tab with new workspace state
      // WorkspaceTab is immutable, so we create a new one
      // But DockerTabData is immutable too.
      // So we need to reconstruct the hierarchy.
      // Actually, replacing the tab in controller is enough.
      final newTabWithState = updated.copyWith(
        workspaceState: DockerTabData(
          kind: data.kind,
          persistedState: newState,
        ),
      );
      _workspaceController.replaceTab(tab.id, newTabWithState);
    } else {
      _workspaceController.replaceTab(tab.id, updated);
    }
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
        ? _tabBuilder.resources(
            id: newId,
            title: contextName,
            label: contextName,
            icon: icons.cloud,
            contextName: contextName,
            onOpenTab: _openChildTab,
            onCloseTab: _closeTabById,
          )
        : _tabBuilder.overview(
            id: newId,
            title: contextName,
            label: contextName,
            icon: icons.cloud,
            contextName: contextName,
            onOpenTab: _openChildTab,
            onCloseTab: _closeTabById,
          );
    _replaceTab(tabId, newTab);
  }

  Future<void> _openHostDashboard(
    String tabId,
    SshHost host,
    Offset? anchor,
  ) async {
    final shell = _shellCallbacks.shellForHost(host);
    final icons = context.appTheme.icons;
    final choice = await _pickDashboardTarget(
      host.name,
      icons.cloudOutline,
      anchor,
    );
    if (choice == null || !mounted) return;
    final newId = 'host-${host.name}-${DateTime.now().microsecondsSinceEpoch}';
    final newTab = choice == _DashboardTarget.resources
        ? _tabBuilder.resources(
            id: newId,
            title: host.name,
            label: host.name,
            icon: icons.cloudOutline,
            remoteHost: host,
            shellService: shell,
            onOpenTab: _openChildTab,
            onCloseTab: _closeTabById,
          )
        : _tabBuilder.overview(
            id: newId,
            title: host.name,
            label: host.name,
            icon: icons.cloudOutline,
            remoteHost: host,
            shellService: shell,
            onOpenTab: _openChildTab,
            onCloseTab: _closeTabById,
          );
    _replaceTab(tabId, newTab);
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
    await _localStateController.loadCachedReady();
  }

  bool _isCommandWorkspace(DockerTabData? data) {
    if (data != null) {
      return data.kind == DockerTabKind.command;
    }
    return false;
  }

  void _refreshPickerTabs() {
    final pickerIds = _tabs
        .where((tab) {
          final data = tab.workspaceState as DockerTabData?;
          return data?.kind == DockerTabKind.picker;
        })
        .map((t) => t.id)
        .toList();

    _workspaceController.runWithoutPersist(() {
      for (final id in pickerIds) {
        _replaceTab(id, _enginePickerTab(id: id));
      }
    });

    unawaited(_workspaceController.persistState());
  }

  void _openChildTab(WorkspaceTab tab) {
    // This is called by builder callbacks.
    // The tab is already built. We just need to ensure unique ID if needed?
    // Usually builder creates new ID.
    _workspaceController.addTab(tab);
  }

  void _closeTabById(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index != -1) _workspaceController.closeTab(index);
  }

  void _updateExplorerPath(String tabId, String path) {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index != -1) {
      final tab = _tabs[index];
      final data = tab.workspaceState as DockerTabData?;
      if (data != null) {
        final newState = data.persistedState.copyWith(path: path);
        final newTab = tab.copyWith(
          workspaceState: DockerTabData(
            kind: data.kind,
            persistedState: newState,
          ),
        );
        _workspaceController.replaceTab(tabId, newTab);
      }
    }
  }

  void _handleSettingsChanged() {
    if (!mounted) return;

    // Only restore if the persisted workspace differs from our current tabs.
    // This avoids a restore loop when our own persistence writes trigger the
    // settings listener (especially noticeable when multiple picker tabs exist).
    final persistedSignature =
        _workspaceController.workspacePersistence.read()?.signature;
    if (persistedSignature != null &&
        persistedSignature !=
            _workspaceController.currentWorkspaceSignature()) {
      unawaited(_restoreWorkspace());
    }

    _workspaceController.workspacePersistence.persistIfPending(
      () => _workspaceController.persistState(),
    );
  }

  Future<void> _restoreWorkspace() async {
    List<SshHost> hosts = const [];
    try {
      hosts = await widget.hostsFuture;
    } catch (error, stackTrace) {
      AppLogger().warn('Failed hosts', error: error, stackTrace: stackTrace);
    }
    if (!mounted) return;

    await _workspaceController.restore(
      builder: _tabBuilder,
      hosts: hosts,
      pickerBuilder: _buildPickerBody,
      callbacks: TabBuilders(
        cloudIcon: context.appTheme.icons.cloud,
        cloudOutlineIcon: context.appTheme.icons.cloudOutline,
        commandIcon: NerdIcon.terminal.data,
        composeIcon: NerdIcon.terminal.data,
        explorerIcon: context.appTheme.icons.folderOpen,
        editorIcon: context.appTheme.icons.edit,
        shellForHost: _shellCallbacks.shellForHost,
        containerShell: _shellCallbacks.containerShell,
        dockerContextNameFor: _dockerContextNameFor,
        closeTab: _closeTabById,
        onOpenTab: _openChildTab,
        onExplorerPathChanged: _updateExplorerPath,
      ),
    );

    unawaited(_loadCachedReady());
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
