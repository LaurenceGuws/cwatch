import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/view/core/tabs/workspace_tab_chip_builder.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'widgets/kubernetes_dashboard_view.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'kubernetes_tab_builder.dart';
import 'kubernetes_context_list_state.dart';
import 'kubernetes_context_selection_surface.dart';
import 'kubernetes_runtime.dart';
import 'kubernetes_workspace_shell.dart';
import 'kubernetes_workspace_controller.dart';

class KubernetesContextList extends StatefulWidget {
  const KubernetesContextList({
    super.key,
    required this.moduleId,
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    this.leading,
  });

  final String moduleId;
  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final Widget? leading;

  @override
  State<KubernetesContextList> createState() => _KubernetesContextListState();
}

class _KubernetesContextListState extends State<KubernetesContextList> {
  late final KubernetesRuntime _runtime;
  late final KubernetesTabBuilder _tabBuilder;
  late final KubernetesWorkspaceShell _workspaceShell;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;

  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;

  final ValueNotifier<List<TabChipOption>> _emptyOptions =
      ValueNotifier<List<TabChipOption>>(const []);
  final KubernetesContextListState _listState = KubernetesContextListState();
  static const Widget _bootstrapPlaceholderBody = SizedBox.shrink();

  KubernetesContextController get _contextController =>
      _runtime.contextController;
  KubernetesWorkspaceController get _workspaceController =>
      _runtime.workspaceController;
  SettingsController get _settingsController => _runtime.settingsController;

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedIndex => _workspaceController.selectedIndex;

  KubernetesTabData? _tabData(WorkspaceTab tab) {
    final state = tab.workspaceState;
    return state is KubernetesTabData ? state : null;
  }

  KubeconfigContext? _tabContext(WorkspaceTab tab) => _tabData(tab)?.context;

  bool _isPlaceholder(WorkspaceTab tab) {
    final state = _tabData(tab)?.persistedState;
    return state?.kind == 'placeholder';
  }

  @override
  void initState() {
    super.initState();
    _tabBuilder = const KubernetesTabBuilder(
      placeholderName: '__k8s_placeholder__',
      placeholderConfig: '__k8s_placeholder__',
    );

    _runtime = KubernetesRuntime.create(
      context: context,
      appSettingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsFuture: widget.hostsFuture,
      tabBuilder: _tabBuilder,
      baseTabBuilder: _createBootstrapPlaceholderTab,
    );

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'k8s-tab',
    );

    _tabsListener = () {
      if (!mounted) return;
      setState(() {});
    };
    _workspaceController.addListener(_tabsListener);

    _workspaceShell = KubernetesWorkspaceShell(
      moduleId: widget.moduleId,
      loadContexts: _loadContexts,
      setContextsFuture: _listState.setContextsFuture,
      tabs: () => _tabs,
      selectedIndex: () => _selectedIndex,
      selectTab: _workspaceController.select,
      closeTab: _closeTab,
      replaceTab: _replaceTab,
      addTab: _workspaceController.addTab,
      createPlaceholderTab: _createPlaceholderTab,
      createContextTab: _createContextTab,
      isPlaceholder: _isPlaceholder,
      persistedWorkspaceSignature: () =>
          _workspaceController.workspacePersistence.read()?.signature,
      currentWorkspaceSignature: _workspaceController.currentWorkspaceSignature,
      restoreWorkspace: _restoreWorkspace,
      persistIfPending: () async {
        _workspaceController.workspacePersistence.persistIfPending(
          () => _workspaceController.persistState(),
        );
      },
      persistState: _workspaceController.persistState,
      runWithoutPersist: _workspaceController.runWithoutPersist,
    );
    _workspaceShell.initializeWorkspaceChrome();

    _settingsListener = () {
      if (!mounted) return;
      unawaited(_workspaceShell.handleSettingsChanged());
    };
    widget.settingsController.addListener(_settingsListener);

    _replaceBootstrapPlaceholder();
    _listState.setContextsFuture(_workspaceShell.initializeContexts());
    unawaited(_restoreWorkspace());
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    _workspaceController.removeListener(_tabsListener);
    _workspaceShell.dispose();
    _runtime.dispose();
    _emptyOptions.dispose();
    super.dispose();
  }

  Future<List<KubeconfigContext>> _loadContexts() async {
    return _listState.loadContexts(
      _contextController,
      widget.settingsController,
    );
  }

  Future<void> _restoreWorkspace() async {
    final workspace = _workspaceController.workspacePersistence.read();
    if (workspace == null || workspace.tabs.isEmpty) return;

    List<KubeconfigContext> contexts;
    try {
      contexts = await (_listState.contextsFuture ?? _loadContexts());
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to restore Kubernetes contexts',
        tag: 'Kubernetes',
        error: error,
        stackTrace: stackTrace,
      );
      contexts = const [];
    }

    if (!mounted) return;

    await _workspaceController.restore(
      builder: _tabBuilder,
      contexts: contexts,
      placeholderBuilder: (tabId) =>
          _buildContextSelection(replaceTabId: tabId),
      detailsBuilder: _buildContextDetails,
    );
  }

  WorkspaceTab _createPlaceholderTab({String? id}) {
    final tabId = id ?? _uniqueId();
    final tab = _tabBuilder.placeholder(
      id: tabId,
      body: _buildContextSelection(replaceTabId: tabId),
    );
    _syncTabOptions(tab);
    return tab;
  }

  WorkspaceTab _createBootstrapPlaceholderTab() {
    return _tabBuilder.placeholder(
      id: _uniqueId(),
      body: _bootstrapPlaceholderBody,
    );
  }

  void _replaceBootstrapPlaceholder() {
    final tabs = _tabs;
    if (tabs.isEmpty) {
      return;
    }
    final baseTab = tabs.first;
    if (!_isPlaceholder(baseTab) || baseTab.body != _bootstrapPlaceholderBody) {
      return;
    }
    final replacement = _createPlaceholderTab(id: baseTab.id);
    _workspaceController.runWithoutPersist(() {
      _workspaceController.replaceBaseTab(replacement);
    });
  }

  WorkspaceTab _createContextTab({
    required KubeconfigContext context,
    String? id,
    String? customName,
  }) {
    final tabId = id ?? 'k8s-${_uniqueId()}';
    final tab = _tabBuilder.details(
      id: tabId,
      context: context,
      customName: customName,
      body: _buildContextDetails(context),
    );
    _syncTabOptions(tab);
    return tab;
  }

  void _syncTabOptions(WorkspaceTab tab) {
    final options = <TabChipOption>[];

    final context = _tabContext(tab);
    if (context == null) {
      options.add(
        TabChipOption(
          label: 'Refresh contexts',
          icon: NerdIcon.refresh.data,
          onSelected: () => _workspaceShell.refreshContexts(),
        ),
      );
      options.add(
        TabChipOption(
          label: _listState.showListSettings ? 'Hide list settings' : 'List settings',
          icon: Icons.settings,
          onSelected: _toggleListSettings,
        ),
      );
    } else {
      options.add(
        TabChipOption(
          label: 'Back to context list',
          icon: Icons.list,
          onSelected: () =>
              _replaceTab(tab.id, _createPlaceholderTab(id: tab.id)),
        ),
      );
      options.add(
        TabChipOption(
          label: 'Copy context name',
          icon: NerdIcon.copy.data,
          onSelected: () => unawaited(_copyText(context.name)),
        ),
      );
    }

    final controller = tab.optionsController;
    if (controller is CompositeTabOptionsController) {
      controller.updateBase(options);
    } else if (controller != null) {
      controller.update(options);
    }
  }

  void _toggleListSettings() {
    setState(() {
      _listState.toggleListSettings();
    });

    for (final tab in _tabs.where(_isPlaceholder)) {
      _syncTabOptions(tab);
      _tabRegistry.remove(tab);
      _tabRegistry.widgetFor(tab, () => tab.body);
    }
  }

  void _replaceTab(String tabId, WorkspaceTab tab) {
    final index = _tabs.indexWhere((candidate) => candidate.id == tabId);
    if (index != -1) {
      _tabRegistry.remove(_tabs[index]);
    }
    _workspaceController.replaceTab(tabId, tab);
  }

  void _closeTab(int index) {
    _workspaceController.closeTab(index);
  }

  void _renameTab(int index) {
    // Keep existing rename dialog behavior out-of-scope for the abstraction refactor.
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    _workspaceController.reorder(oldIndex, newIndex);
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Widget _buildContextDetails(KubeconfigContext context) {
    return KubernetesDashboardView(
      context: context,
      settingsController: widget.settingsController,
    );
  }

  Widget _buildContextSelection({required String replaceTabId}) {
    return KubernetesContextSelectionSurface(
      listState: _listState,
      contextController: _contextController,
      workspaceShell: _workspaceShell,
      settingsController: _settingsController,
      replaceTabId: replaceTabId,
      onStateChanged: () {
        if (!mounted) return;
        setState(() {});
      },
      onToggleSettings: _toggleListSettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final spacing = appTheme.spacing;

    return Padding(
      padding: spacing.inset(horizontal: 1.5, vertical: 1),
      child: Column(
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
                    .shellPreferences.useSystemDecorations,
                leading: widget.leading,
                onReorder: _handleTabReorder,
                onAddTab: _workspaceShell.startEmptyTab,
                buildChip: (context, index, tab) {
                  final data = _tabData(tab);
                  return WorkspaceTabChipBuilder(
                    tab: tab,
                    selected: index == _selectedIndex,
                    host: SshHost(
                      name: tab.label,
                      hostname: data?.context?.server ?? '',
                      port: 0,
                      available: true,
                    ),
                    onSelect: () => _workspaceController.select(index),
                    onClose: () => _closeTab(index),
                    onRename: () => _renameTab(index),
                    index: index,
                  );
                },
                buildBody: (tab) => tab.body,
              ),
            ),
          ),
          Padding(
            padding: spacing.inset(horizontal: 2, vertical: 0),
            child: Divider(height: 1, color: appTheme.section.divider),
          ),
        ],
      ),
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();
}
