import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

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
import 'package:cwatch/view/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table_host.dart';
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/controller/adapters/external_app_launcher.dart';
import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/di/bindings/kubernetes_context_binding.dart';
import 'widgets/kubernetes_dashboard_view.dart';
import 'package:cwatch/view/features/settings/settings/kubernetes_settings_controls.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'kubernetes_tab_builder.dart';
import 'kubernetes_context_list_state.dart';
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
  final KubernetesContextBinding _contextBinding =
      const KubernetesContextBinding();
  late final KubernetesRuntime _runtime;
  late final KubernetesTabBuilder _tabBuilder;
  late final KubernetesWorkspaceShell _workspaceShell;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;

  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;

  final ValueNotifier<List<TabChipOption>> _emptyOptions =
      ValueNotifier<List<TabChipOption>>(const []);
  final KubernetesContextListState _listState = KubernetesContextListState();

  KubernetesContextController get _contextController =>
      _runtime.contextController;
  KubernetesWorkspaceController get _workspaceController =>
      _runtime.workspaceController;
  SettingsController get _settingsController => _runtime.settingsController;
  KubernetesUiAdapter get _uiAdapter => _runtime.uiAdapter;

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedIndex => _workspaceController.selectedIndex;

  KubernetesTabData? _tabData(WorkspaceTab tab) {
    final state = tab.workspaceState;
    return state is KubernetesTabData ? state : null;
  }

  KubeconfigContext? _tabContext(WorkspaceTab tab) => _tabData(tab)?.context;

  String _contextSelectionKey(KubeconfigContext ctx) =>
      '${ctx.configPath}|${ctx.name}';

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

    _runtime = _contextBinding.createRuntime(
      context: context,
      appSettingsController: widget.settingsController,
      keyService: widget.keyService,
      hostsFuture: widget.hostsFuture,
      tabBuilder: _tabBuilder,
      baseTabBuilder: _createPlaceholderTab,
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
          onSelected: _workspaceShell.refreshContexts,
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
    _uiAdapter.showSnackBar('Copied to clipboard');
  }

  List<StructuredDataChip> _contextMetadata(KubeconfigContext ctx) {
    final chips = <StructuredDataChip>[];
    if (ctx.isCurrent) {
      chips.add(const StructuredDataChip(label: 'Current', icon: Icons.check));
    }
    final namespace = ctx.namespace?.trim();
    if (namespace != null && namespace.isNotEmpty) {
      chips.add(StructuredDataChip(label: 'ns: $namespace'));
    }
    return chips;
  }

  List<StructuredDataMenuAction<KubeconfigContext>> _buildContextMenuActions(
    KubeconfigContext ctx,
    List<KubeconfigContext> selected,
    Offset? anchor,
  ) {
    // Use the selectedRows parameter from StructuredDataTable
    final selection = selected.isNotEmpty ? selected : [ctx];
    final singleSelection = selection.length == 1;

    return [
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open details',
        icon: NerdIcon.kubernetes.data,
        onSelected: (_, primary) => _workspaceShell.openContextTab(primary),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Copy context name',
        icon: NerdIcon.copy.data,
        onSelected: (_, primary) => unawaited(_copyText(primary.name)),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open kubeconfig',
        icon: Icons.open_in_new,
        enabled: singleSelection,
        onSelected: (_, primary) =>
            ExternalAppLauncher.openConfigFile(primary.configPath, context),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open details in new tabs',
        icon: NerdIcon.kubernetes.data,
        enabled: selection.length > 1,
        onSelected: (_, _) {
          for (final target in selection) {
            _workspaceController.addTab(_createContextTab(context: target));
          }
        },
      ),
    ];
  }

  Widget _buildContextDetails(KubeconfigContext context) {
    return KubernetesDashboardView(
      context: context,
      settingsController: widget.settingsController,
    );
  }

  Widget _buildContextSelection({required String replaceTabId}) {
    final list = FutureBuilder<List<KubeconfigContext>>(
      future: _listState.contextsFuture,
      builder: (context, snapshot) {
        final spacing = context.appTheme.spacing;
        if (snapshot.connectionState == ConnectionState.waiting &&
            _listState.cachedContexts.isEmpty) {
          return const StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'Loading kubeconfig contexts',
            message: 'Loading contexts...',
            loading: true,
            padding: EdgeInsets.zero,
          );
        }
        if (snapshot.hasError) {
          return StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'Kubeconfig discovery failed',
            message: 'Failed to load Kubernetes contexts: ${snapshot.error}',
            icon: Icons.error_outline,
            actionLabel: 'Retry',
            onAction: _workspaceShell.refreshContexts,
            padding: EdgeInsets.zero,
          );
        }

        final contexts = _listState.resolveContexts(snapshot);
        if (contexts.isEmpty) {
          return StructuredDataTableFeedback(
            title: 'Contexts',
            subtitle: 'No kubeconfig contexts available',
            message: 'No Kubernetes contexts found.',
            icon: Icons.hub_outlined,
            actionLabel: 'Reload',
            onAction: _workspaceShell.refreshContexts,
            padding: EdgeInsets.zero,
          );
        }

        final grouped = _listState.groupByConfigPath(_contextController, contexts);
        final configPaths = grouped.keys.toList()..sort();
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: spacing.base),
          itemCount: configPaths.length,
          itemBuilder: (context, index) {
            final configPath = configPaths[index];
            final contextsForPath =
                grouped[configPath] ?? const <KubeconfigContext>[];
            final collapsed = _listState.isCollapsed(configPath);
            final sectionColor = _sectionBackgroundForIndex(context, index);
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: SectionList(
                title: path.basename(configPath),
                backgroundColor: sectionColor,
                trailing: IconButton(
                  icon: Icon(
                    collapsed ? Icons.expand_more : Icons.expand_less,
                    size: 18,
                  ),
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                  onPressed: () {
                    setState(() {
                      _listState.toggleCollapsed(configPath);
                    });
                  },
                ),
                children: collapsed
                    ? const []
                    : [
                        StructuredDataTableHost(
                          title: 'Contexts',
                          subtitle: '${contextsForPath.length} contexts in this kubeconfig',
                          child: StructuredDataTable<KubeconfigContext>(
                            rows: contextsForPath,
                            columns: _contextColumns(context),
                            rowHeight: 64,
                            shrinkToContent: true,
                            useZebraStripes: false,
                            surfaceBackgroundColor: sectionColor,
                            primaryDoubleClickOpensContextMenu: false,
                            metadataBuilder: _contextMetadata,
                            onRowDoubleTap: (ctx) =>
                                _workspaceShell.openContextTab(
                                  ctx,
                                  replaceTabId: replaceTabId,
                                ),
                            rowContextMenuBuilder: _buildContextMenuActions,
                            onSelectionChanged: (selectedRows) {
                              setState(() {
                                _listState.updateSelectedRows(
                                  contextsForPath,
                                  selectedRows,
                                  _contextSelectionKey,
                                );
                              });
                            },
                          ),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );

    if (!_listState.showListSettings) {
      return list;
    }

    return Stack(
      children: [
        list,
        FloatingSettingsWindow(
          title: 'Kubernetes List Settings',
          onClose: _toggleListSettings,
          child: Column(
            children: [
              ListTile(
                title: const Text('Collapse all sections'),
                onTap: () {
                  setState(() {
                    _listState.collapseAll();
                  });
                },
                trailing: const Icon(Icons.expand_less),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                title: const Text('Expand all sections'),
                onTap: () {
                  setState(() {
                    _listState.expandAll();
                  });
                },
                trailing: const Icon(Icons.expand_more),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              KubernetesSettingsControls(
                settings: _settingsController.settings,
                settingsController: _settingsController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<StructuredDataColumn<KubeconfigContext>> _contextColumns(
    BuildContext context,
  ) {
    final spacing = context.appTheme.spacing;
    return [
      StructuredDataColumn<KubeconfigContext>(
        label: 'Context',
        flex: 3,
        autoFitText: (ctx) => ctx.name,
        cellBuilder: (context, ctx) {
          return Row(
            children: [
              Icon(
                NerdIcon.kubernetes.data,
                size: 18,
                color: Theme.of(context).iconTheme.color,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ctx.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      path.basename(ctx.configPath),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final theme = context.appTheme;
    return index.isEven
        ? theme.section.surface.background
        : theme.section.toolbarBackground;
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
