import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
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
import 'package:cwatch/view/shared/widgets/lists/section_list.dart';
import 'package:cwatch/controller/adapters/external_app_launcher.dart';
import 'package:cwatch/controller/adapters/kubernetes_ui_adapter.dart';
import 'package:cwatch/controller/di/bindings/kubernetes_context_binding.dart';
import 'widgets/kubernetes_dashboard_view.dart';
import 'package:cwatch/view/features/settings/settings/kubernetes_settings_controls.dart';

import 'package:cwatch/controller/controllers/kubernetes_context_controller.dart';
import 'kubernetes_tab_builder.dart';
import 'kubernetes_runtime.dart';
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
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;

  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;

  final ValueNotifier<List<TabChipOption>> _emptyOptions =
      ValueNotifier<List<TabChipOption>>(const []);

  Future<List<KubeconfigContext>>? _contextsFuture;
  List<KubeconfigContext> _cachedContexts = const [];
  final Map<String, bool> _collapsedByConfigPath = {};
  final Set<String> _selectedContextKeys = {};
  bool _showListSettings = false;

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

    _tabNavigator = TabNavigationHandle(
      next: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        _workspaceController.select((_selectedIndex + 1) % length);
        return true;
      },
      previous: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        _workspaceController.select((_selectedIndex - 1 + length) % length);
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

    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);

    _contextsFuture = _loadContexts();
    unawaited(_restoreWorkspace());
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    _workspaceController.removeListener(_tabsListener);
    _runtime.dispose();
    _emptyOptions.dispose();
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      widget.moduleId,
      _commandPaletteHandle,
    );
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (!mounted) return;

    _refreshContexts();

    final persisted = _workspaceController.workspacePersistence.read();
    if (persisted != null &&
        persisted.signature !=
            _workspaceController.currentWorkspaceSignature()) {
      unawaited(_restoreWorkspace());
    }

    _workspaceController.workspacePersistence.persistIfPending(
      () => _workspaceController.persistState(),
    );
  }

  Future<List<KubeconfigContext>> _loadContexts() async {
    final contexts = await _contextController.loadContexts(
      _contextController.resolveConfigPaths(widget.settingsController.settings),
    );
    _cachedContexts = contexts;
    return contexts;
  }

  void _refreshContexts() {
    _contextsFuture = _loadContexts();

    final placeholderIds = _tabs
        .where(_isPlaceholder)
        .map((t) => t.id)
        .toList(growable: false);

    _workspaceController.runWithoutPersist(() {
      for (final id in placeholderIds) {
        _replaceTab(id, _createPlaceholderTab(id: id));
      }
    });

    unawaited(_workspaceController.persistState());
  }

  Future<void> _restoreWorkspace() async {
    final workspace = _workspaceController.workspacePersistence.read();
    if (workspace == null || workspace.tabs.isEmpty) return;

    List<KubeconfigContext> contexts;
    try {
      contexts = await (_contextsFuture ?? _loadContexts());
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
          onSelected: _refreshContexts,
        ),
      );
      options.add(
        TabChipOption(
          label: _showListSettings ? 'Hide list settings' : 'List settings',
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
      _showListSettings = !_showListSettings;
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

  void _openContextTab(KubeconfigContext context, {String? replaceTabId}) {
    final replacementId =
        replaceTabId ??
        (_selectedIndex >= 0 &&
                _selectedIndex < _tabs.length &&
                _isPlaceholder(_tabs[_selectedIndex])
            ? _tabs[_selectedIndex].id
            : null);

    final tab = _createContextTab(
      context: context,
      id: replacementId,
      customName: null,
    );

    if (replacementId != null) {
      _replaceTab(replacementId, tab);
      return;
    }

    if (_selectedIndex >= 0 &&
        _selectedIndex < _tabs.length &&
        _isPlaceholder(_tabs[_selectedIndex])) {
      _replaceTab(_tabs[_selectedIndex].id, tab);
      return;
    }

    _workspaceController.addTab(tab);
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

  void _startEmptyTab() {
    _workspaceController.addTab(_createPlaceholderTab());
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
        onSelected: (_, primary) => _openContextTab(primary),
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
      future: _contextsFuture,
      builder: (context, snapshot) {
        final spacing = context.appTheme.spacing;
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedContexts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load contexts: ${snapshot.error}'),
                SizedBox(height: spacing.lg),
                FilledButton.icon(
                  onPressed: _refreshContexts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final contexts = snapshot.data ?? _cachedContexts;
        if (contexts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No Kubernetes contexts found.'),
                SizedBox(height: spacing.lg),
                FilledButton.icon(
                  onPressed: _refreshContexts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
          );
        }

        final grouped = _contextController.groupByConfigPath(contexts);
        final configPaths = grouped.keys.toList()..sort();
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: spacing.base),
          itemCount: configPaths.length,
          itemBuilder: (context, index) {
            final configPath = configPaths[index];
            final contextsForPath =
                grouped[configPath] ?? const <KubeconfigContext>[];
            final collapsed = _collapsedByConfigPath[configPath] ?? false;
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
                      _collapsedByConfigPath[configPath] = !collapsed;
                    });
                  },
                ),
                children: collapsed
                    ? const []
                    : [
                        StructuredDataTable<KubeconfigContext>(
                          rows: contextsForPath,
                          columns: _contextColumns(context),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
                          primaryDoubleClickOpensContextMenu: false,
                          metadataBuilder: _contextMetadata,
                          onRowDoubleTap: (ctx) =>
                              _openContextTab(ctx, replaceTabId: replaceTabId),
                          rowContextMenuBuilder: _buildContextMenuActions,
                          onSelectionChanged: (selectedRows) {
                            final tableKeys = contextsForPath
                                .map(_contextSelectionKey)
                                .toSet();
                            setState(() {
                              _selectedContextKeys
                                ..removeAll(tableKeys)
                                ..addAll(
                                  selectedRows.map(_contextSelectionKey),
                                );
                            });
                          },
                        ),
                      ],
              ),
            );
          },
        );
      },
    );

    if (!_showListSettings) {
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
                    for (final cfg
                        in _cachedContexts.map((c) => c.configPath).toSet()) {
                      _collapsedByConfigPath[cfg] = true;
                    }
                  });
                },
                trailing: const Icon(Icons.expand_less),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                title: const Text('Expand all sections'),
                onTap: () {
                  setState(() {
                    _collapsedByConfigPath.clear();
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

  List<CommandPaletteEntry> _buildCommandPaletteEntries() {
    final entries = <CommandPaletteEntry>[];

    if (_tabs.isNotEmpty &&
        _selectedIndex >= 0 &&
        _selectedIndex < _tabs.length) {
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
        onSelected: _startEmptyTab,
      ),
    );

    return entries;
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
                onAddTab: _startEmptyTab,
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
