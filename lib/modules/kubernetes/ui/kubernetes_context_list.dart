import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/core/navigation/command_palette_registry.dart';
import 'package:cwatch/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';
import 'package:cwatch/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/core/widgets/keep_alive.dart';
import 'package:cwatch/core/workspace/workspace_tab.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/kubernetes/kubectl_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';
import 'package:cwatch/shared/views/shared/tabs/settings/floating_settings_window.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/modules/settings/ui/settings/kubernetes_settings_controls.dart';

import 'kubernetes_context_controller.dart';
import 'kubernetes_tab_builder.dart';
import 'kubernetes_workspace_controller.dart';
import 'widgets/kubernetes_resources.dart';

class KubernetesContextList extends StatefulWidget {
  const KubernetesContextList({
    super.key,
    required this.moduleId,
    required this.settingsController,
    this.leading,
  });

  final String moduleId;
  final AppSettingsController settingsController;
  final Widget? leading;

  @override
  State<KubernetesContextList> createState() => _KubernetesContextListState();
}

class _KubernetesContextListState extends State<KubernetesContextList> {
  static const String _placeholderName = '__k8s_placeholder__';
  static const String _placeholderConfig = '__k8s_placeholder__';

  final KubernetesContextController _contextController =
      KubernetesContextController();
  final KubectlService _kubectl = const KubectlService();

  late final KubernetesTabBuilder _tabBuilder;
  late final KubernetesWorkspaceController _workspaceController;
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
  bool _showListSettings = false;

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedIndex => _workspaceController.selectedIndex;

  KubernetesTabData? _tabData(WorkspaceTab tab) {
    final state = tab.workspaceState;
    return state is KubernetesTabData ? state : null;
  }

  KubeconfigContext? _tabContext(WorkspaceTab tab) => _tabData(tab)?.context;

  KubernetesTabKind _tabKind(WorkspaceTab tab) =>
      _tabData(tab)?.kind ?? KubernetesTabKind.details;

  bool _isPlaceholder(WorkspaceTab tab) {
    final state = _tabData(tab)?.persistedState;
    return state?.kind == 'placeholder';
  }

  @override
  void initState() {
    super.initState();

    _tabBuilder = const KubernetesTabBuilder(
      placeholderName: _placeholderName,
      placeholderConfig: _placeholderConfig,
    );

    _workspaceController = KubernetesWorkspaceController(
      settingsController: widget.settingsController,
      baseTabBuilder: () => _createPlaceholderTab(),
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

    _commandPaletteHandle = CommandPaletteHandle(loader: () => const []);
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
    _workspaceController.dispose();
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

    final persisted = widget.settingsController.settings.kubernetesWorkspace;
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
        _workspaceController.replaceTab(id, _createPlaceholderTab(id: id));
      }
    });

    unawaited(_workspaceController.persistState());
  }

  Future<void> _restoreWorkspace() async {
    final workspace = widget.settingsController.settings.kubernetesWorkspace;
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
      resourcesBuilder: (context, options) => _buildResources(context, options),
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
    required KubernetesTabKind kind,
    String? id,
    String? customName,
    TabOptionsController? optionsController,
  }) {
    final tabId = id ?? 'k8s-${_uniqueId()}';
    late final WorkspaceTab tab;
    if (kind == KubernetesTabKind.resources) {
      final controller = optionsController ?? CompositeTabOptionsController();
      tab = _tabBuilder.resources(
        id: tabId,
        context: context,
        customName: customName,
        optionsController: controller,
        body: _buildResources(context, controller),
      );
    } else {
      tab = _tabBuilder.details(
        id: tabId,
        context: context,
        customName: customName,
        body: _buildContextDetails(context),
      );
    }
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
      final kind = _tabKind(tab);
      if (kind == KubernetesTabKind.details) {
        options.add(
          TabChipOption(
            label: 'Open resources',
            icon: NerdIcon.database.data,
            onSelected: () => _openContextTab(
              context,
              kind: KubernetesTabKind.resources,
              replaceTabId: tab.id,
            ),
          ),
        );
        options.add(
          TabChipOption(
            label: 'Refresh contexts',
            icon: NerdIcon.refresh.data,
            onSelected: _refreshContexts,
          ),
        );
      } else {
        options.add(
          TabChipOption(
            label: 'Open details',
            icon: NerdIcon.kubernetes.data,
            onSelected: () => _openContextTab(
              context,
              kind: KubernetesTabKind.details,
              replaceTabId: tab.id,
            ),
          ),
        );
        options.add(
          TabChipOption(
            label: 'Refresh metrics',
            icon: NerdIcon.refresh.data,
            onSelected: () => _reloadResourceTab(tab.id),
          ),
        );
      }
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

  void _openContextTab(
    KubeconfigContext context, {
    KubernetesTabKind kind = KubernetesTabKind.details,
    String? replaceTabId,
  }) {
    final replacementId =
        replaceTabId ??
        (_selectedIndex >= 0 &&
                _selectedIndex < _tabs.length &&
                _isPlaceholder(_tabs[_selectedIndex])
            ? _tabs[_selectedIndex].id
            : null);

    final tab = _createContextTab(
      context: context,
      kind: kind,
      id: replacementId,
      customName: null,
    );

    if (replacementId != null) {
      _workspaceController.replaceTab(replacementId, tab);
      return;
    }

    _workspaceController.addOrReplaceCurrent(
      tab,
      shouldReplace: (current) => _isPlaceholder(current),
    );
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

  Future<void> _reloadResourceTab(String tabId) async {
    final index = _tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = _tabs[index];
    final context = _tabContext(tab);
    if (context == null) return;

    final controller = tab.optionsController;
    if (controller is CompositeTabOptionsController) {
      final refreshed = _tabBuilder.resources(
        id: tab.id,
        context: context,
        customName: _tabData(tab)?.customName,
        optionsController: controller,
        body: _buildResources(context, controller),
      );
      _syncTabOptions(refreshed);
      _workspaceController.replaceTab(tab.id, refreshed);
    }
  }

  Widget _buildResources(
    KubeconfigContext context,
    TabOptionsController options,
  ) {
    return KubernetesResources(
      contextName: context.name,
      configPath: context.configPath,
      kubectl: _kubectl,
      optionsController: options,
    );
  }

  Widget _buildContextDetails(KubeconfigContext context) {
    final spacing = this.context.appTheme.spacing;
    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.name,
            style: Theme.of(this.context).textTheme.titleLarge,
          ),
          SizedBox(height: spacing.md),
          Text('Cluster: ${context.cluster}'),
          if (context.namespace != null)
            Text('Namespace: ${context.namespace}'),
          if (context.server != null) Text('Server: ${context.server}'),
          SizedBox(height: spacing.lg),
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _openContextTab(context, kind: KubernetesTabKind.resources),
                icon: Icon(NerdIcon.database.data),
                label: const Text('Open resources'),
              ),
              OutlinedButton.icon(
                onPressed: () => ExternalAppLauncher.openConfigFile(
                  context.configPath,
                  this.context,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open kubeconfig'),
              ),
            ],
          ),
        ],
      ),
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
                          columns: _contextColumns(context, replaceTabId),
                          rowHeight: 64,
                          shrinkToContent: true,
                          useZebraStripes: false,
                          surfaceBackgroundColor: sectionColor,
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
                settings: widget.settingsController.settings,
                settingsController: widget.settingsController,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<StructuredDataColumn<KubeconfigContext>> _contextColumns(
    BuildContext context,
    String replaceTabId,
  ) {
    return [
      StructuredDataColumn<KubeconfigContext>(
        label: 'Context',
        flex: 3,
        autoFitText: (ctx) => ctx.name,
        cellBuilder: (context, ctx) {
          return ListTile(
            dense: true,
            title: Text(ctx.name),
            subtitle: Text(path.basename(ctx.configPath)),
            onTap: () => _openContextTab(
              ctx,
              kind: KubernetesTabKind.details,
              replaceTabId: replaceTabId,
            ),
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
                    .windowUseSystemDecorations,
                leading: widget.leading,
                onReorder: _handleTabReorder,
                onAddTab: _startEmptyTab,
                buildChip: (context, index, tab) {
                  final data = _tabData(tab);
                  final optionsController = tab.optionsController;

                  Widget buildTab(List<TabChipOption> options) {
                    return TabChip(
                      host: SshHost(
                        name: tab.label,
                        hostname: data?.context?.server ?? '',
                        port: 0,
                        available: true,
                      ),
                      title: tab.title,
                      label: tab.label,
                      icon: tab.icon,
                      selected: index == _selectedIndex,
                      onSelect: () => _workspaceController.select(index),
                      onClose: () => _closeTab(index),
                      onRename: tab.canRename ? () => _renameTab(index) : null,
                      dragIndex: tab.canDrag ? index : null,
                      options: options,
                      closable: true,
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
                      return buildTab(options);
                    },
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
