import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';
import 'package:cwatch/model/features/servers/services/host_distro_key.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_shell_factory.dart';
import 'package:cwatch/controller/controllers/docker_shell_callbacks.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/model/shared/services/host_shell_policy.dart';
import 'package:cwatch/model/services_infra/network/connectivity_probe.dart';
import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/model/models/docker_workspace_state.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'widgets/docker_engine_picker.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'docker_tab_builder.dart';
import 'docker_workspace_controller.dart';
import 'package:cwatch/model/features/docker/models/remote_docker_status.dart';
import 'local_docker_context_status.dart';
import 'package:cwatch/model/models/docker_context.dart';
import 'package:cwatch/view/features/settings/settings/docker_settings_controls.dart';
import 'package:cwatch/controller/adapters/docker_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_view_controller.dart';
import 'package:cwatch/controller/di/bindings/docker_view_binding.dart';
import 'docker_view_runtime.dart';

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
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;
  late final DockerUiAdapter _uiAdapter;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final VoidCallback _viewControllerListener;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;
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
  final ValueNotifier<List<RemoteDockerStatus>> _cachedReadyNotifier =
      ValueNotifier<List<RemoteDockerStatus>>(const []);
  List<RemoteDockerStatus> _cachedReady = const [];
  Future<List<LocalDockerContextStatus>>? _localContextsStatusFuture;
  bool _showListSettings = false;

  DockerClientService get _docker => _runtime.docker;
  DockerViewController get _viewController => _runtime.viewController;
  DistroCacheController get _distroCacheController =>
      _runtime.distroCacheController;
  DockerTabBuilder get _tabBuilder => _runtime.tabBuilder;
  DockerWorkspaceController get _workspaceController =>
      _runtime.workspaceController;
  DockerShellCallbacks get _shellCallbacks => _runtime.shellCallbacks;

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
    _runtime = _viewBinding.createRuntime(
      settingsController: widget.settingsController,
      keyService: widget.keyService,
      shellFactory: widget.shellFactory,
      hostsFuture: widget.hostsFuture,
      baseTabBuilder: _enginePickerTab,
    );
    _viewControllerListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _viewController.addListener(_viewControllerListener);
    _uiAdapter = DockerUiAdapter(context: context);
    _viewController.loadContexts();

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
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
        _workspaceController.select(next);
        return true;
      },
      previous: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final prev = (_selectedIndex - 1 + length) % length;
        _workspaceController.select(prev);
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

    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void dispose() {
    _workspaceController.removeListener(_tabsListener);
    _viewController.removeListener(_viewControllerListener);
    widget.settingsController.removeListener(_settingsListener);
    _runtime.dispose();
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      widget.moduleId,
      _commandPaletteHandle,
    );
    super.dispose();
  }

  WorkspaceTab _enginePickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    return _tabBuilder.picker(id: tabId, body: _buildPickerBody(tabId));
  }

  Widget _buildPickerBody(String tabId) {
    return Stack(
      children: [
        EnginePicker(
          tabId: tabId,
          contextsFuture: _viewController.contextsFuture,
          contextsStatusFuture: _localContextsStatusFuture ??=
              _loadLocalContextsStatus(),
          cachedReady: _cachedReady,
          cachedReadyNotifier: _cachedReadyNotifier,
          remoteStatusFuture: _remoteStatusFuture,
          remoteScanRequested: _remoteScanRequested,
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
                  logsTail: widget.settingsController.settings.dockerLogsTail,
                  onLogsTailChanged: (value) => widget.settingsController
                      .update((s) => s.copyWith(dockerLogsTail: value)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _refreshContexts() {
    _viewController.refreshContexts();
    _localContextsStatusFuture = null; // Reset status future

    final pickerIds = _tabs
        .where(
          (t) =>
              (t.workspaceState as DockerTabData?)?.kind ==
              DockerTabKind.picker,
        )
        .map((t) => t.id)
        .toList();

    _workspaceController.runWithoutPersist(() {
      for (final id in pickerIds) {
        _replaceTab(id, _enginePickerTab(id: id));
      }
    });

    unawaited(_workspaceController.persistState());
  }

  void _scanRemotes() {
    if (_scanningRemotes) return;
    final token = ++_scanToken;
    _scanningRemotes = true;
    _scanningNotifier.value = true;
    _remoteScanRequested = true;
    _scanStatusesNotifier.value = const [];
    _remoteStatusFuture = _loadRemoteStatuses(manual: true, token: token);
    unawaited(
      _uiAdapter.showRemoteScanDialog(
        onCancel: () {
          _cancelledScans.add(token);
          setState(() {
            _scanningRemotes = false;
            _scanningNotifier.value = false;
          });
        },
        hostsListenable: _scanHostsNotifier,
        statusesListenable: _scanStatusesNotifier,
        scanningListenable: _scanningNotifier,
        onComplete: () async {
          await _remoteStatusFuture;
          if (!mounted) return;
          if (!_isScanCancelled(token)) {
            setState(() {
              _scanningRemotes = false;
              _scanningNotifier.value = false;
            });
          }
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
                    .windowUseSystemDecorations,
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
                onAddTab: _addEnginePickerTab,
                buildChip: (context, index, tab) {
                  final optionsController = tab.optionsController;
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
                        _workspaceController.select(index);
                      },
                      onClose: () => _workspaceController.closeTab(index),
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
                    builder: (context, options, _) {
                      final updatedOptions = [
                        ...options,
                        if (isPicker)
                          TabChipOption(
                            label: _showListSettings
                                ? 'Hide list settings'
                                : 'List settings',
                            icon: Icons.settings,
                            onSelected: _toggleListSettings,
                          ),
                      ];
                      return buildTab(updatedOptions);
                    },
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
          onSelected: () => _workspaceController.closeTab(_selectedIndex),
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
    final cached = await _workspaceController.loadCachedReady(
      widget.hostsFuture,
    );
    if (!mounted) return;
    setState(() {
      _cachedReady = cached;
      _cachedReadyNotifier.value = cached;
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
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH hosts for docker status scan',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to load SSH hosts: $error');
    }
    if (!mounted || hosts.isEmpty) {
      return const [];
    }
    final disabledKeys = widget.settingsController.settings.disabledServerHosts
        .toSet();
    final disabledPaths = widget
        .settingsController
        .settings
        .disabledSshConfigPaths
        .toSet();
    final enabledHosts = hosts
        .where((host) => _isHostEnabled(host, disabledKeys, disabledPaths))
        .toList();
    if (enabledHosts.isEmpty) {
      if (mounted) {
        setState(() {
          _scanHostsNotifier.value = const [];
          _scanStatusesNotifier.value = const [];
        });
      }
      return const [];
    }
    setState(() {
      _scanHostsNotifier.value = enabledHosts;
    });
    void updateScanStatuses(List<RemoteDockerStatus> statuses) {
      if (!mounted || !manual) return;
      setState(() {
        _scanStatusesNotifier.value = statuses;
      });
    }

    final statuses = await _workspaceController.discoverRemoteStatuses(
      hostsFuture: Future.value(enabledHosts),
      probeHost: _probeHost,
      disabledHosts: disabledKeys,
      disabledPaths: disabledPaths,
      manual: manual,
      isCancelled: () => _isScanCancelled(token),
      onProgress: updateScanStatuses,
    );
    final ready = statuses.where((s) => s.available).toList();
    if (manual && !_isScanCancelled(token)) {
      if (mounted) {
        setState(() {
          _scanStatusesNotifier.value = statuses;
          _cachedReady = ready;
          _cachedReadyNotifier.value = ready;
        });
        _refreshPickerTabs();
      }
    }
    return statuses;
  }

  bool _isScanCancelled(int token) => _cancelledScans.contains(token);

  bool _isHostEnabled(
    SshHost host,
    Set<String> disabledKeys,
    Set<String> disabledPaths,
  ) {
    if (!host.available) {
      return false;
    }
    if (isNoShellHost(host)) {
      return false;
    }
    final normalized = disabledKeys.map((key) => key.toLowerCase()).toSet();
    if (normalized.contains(host.hostname.toLowerCase())) {
      return false;
    }
    if (normalized.any((key) => disabledKeyMatchesHost(key, host))) {
      return false;
    }
    final source = host.source;
    if (source != null && disabledPaths.contains(source)) {
      return false;
    }
    return true;
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

  Future<bool> _isHostReachable(SshHost host) {
    const probe = ConnectivityProbe();
    return probe.canConnect(
      host: host.hostname,
      port: host.port,
      timeout: const Duration(seconds: 1),
      hostContext: host,
    );
  }

  Future<LocalDockerContextStatus> _probeLocalContext(
    DockerContext context,
  ) async {
    try {
      // Run docker ps with --context to check if the context is ready
      final result = await Process.run(
        'docker',
        ['--context', context.name, 'ps'],
        runInShell: true,
      ).timeout(const Duration(seconds: 3));
      
      if (result.exitCode == 0) {
        return LocalDockerContextStatus(
          context: context,
          available: true,
          detail: 'Ready',
        );
      } else {
        final errorMsg = (result.stderr as String?)?.trim() ?? 
            'docker ps failed with exit code ${result.exitCode}';
        return LocalDockerContextStatus(
          context: context,
          available: false,
          detail: errorMsg.length > 100
              ? '${errorMsg.substring(0, 100)}...'
              : errorMsg,
        );
      }
    } catch (error) {
      final errorMsg = error.toString();
      return LocalDockerContextStatus(
        context: context,
        available: false,
        detail: errorMsg.length > 100
            ? '${errorMsg.substring(0, 100)}...'
            : errorMsg,
      );
    }
  }

  Future<List<LocalDockerContextStatus>> _loadLocalContextsStatus() async {
    final contexts = await _viewController.loadContexts();
    if (contexts.isEmpty) {
      return const [];
    }
    // Probe all contexts in parallel
    final statuses = await Future.wait(
      contexts.map((ctx) => _probeLocalContext(ctx)),
    );
    return statuses;
  }

  Future<RemoteDockerStatus> _probeHost(SshHost host) async {
    if (isNoShellHost(host)) {
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: 'Shell access disabled',
        lastScanDate: DateTime.now(),
      );
    }
    final reachable = await _isHostReachable(host);
    if (!reachable) {
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: 'Host unreachable',
        lastScanDate: DateTime.now(),
      );
    }
    final shell = widget.shellFactory.forHost(
      host,
      connectTimeout: const Duration(seconds: 3),
    );
    // Use bash --login to source profile (ensures Docker env vars are set)
    // Simple check: just run docker -v to see if Docker is accessible
    const probeCommand = "bash --login -c 'docker -v'";
    try {
      final output = await shell.runCommand(
        host,
        probeCommand,
        timeout: const Duration(seconds: 3),
      );
      final trimmed = output.trim();
      
      final now = DateTime.now();
      // If docker -v succeeds, Docker is available
      // Output should be like "Docker version 29.1.3, build f52814d"
      if (trimmed.toLowerCase().contains('docker version')) {
        return RemoteDockerStatus(
          host: host,
          available: true,
          detail: 'Ready',
          lastScanDate: now,
        );
      }
      
      // If we got output but it doesn't look like docker version, treat as error
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: trimmed.isEmpty ? 'Docker not accessible' : trimmed.split('\n').first,
        lastScanDate: now,
      );
    } catch (error, stack) {
      AppLogger().warn(
        'Docker probe failed for ${host.name}: $error',
        tag: 'Docker',
        stackTrace: stack,
      );
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: error.toString(),
        lastScanDate: DateTime.now(),
      );
    }
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
