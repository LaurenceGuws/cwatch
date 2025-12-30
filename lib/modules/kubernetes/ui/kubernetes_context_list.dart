import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/services/kubernetes/kubectl_service.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/data_table/structured_data_table.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'package:cwatch/shared/widgets/distro_leading_slot.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';
import 'package:cwatch/core/widgets/keep_alive.dart';
import 'package:cwatch/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/core/navigation/command_palette_registry.dart';
import 'package:cwatch/core/tabs/tab_bar_visibility.dart';
import 'widgets/kubernetes_resources.dart';
import 'kubernetes_tab.dart';
import 'kubernetes_tab_factory.dart';
import 'kubernetes_workspace_controller.dart';
import 'kubernetes_context_controller.dart';

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
  late final TabHostController<KubernetesTab> _tabController;
  late final TabViewRegistry<KubernetesTab> _tabRegistry;
  late final KubernetesWorkspaceController _workspaceController;
  late final KubernetesTabFactory _tabFactory;
  final ValueNotifier<List<TabChipOption>> _emptyOptions =
      ValueNotifier<List<TabChipOption>>(const []);
  Future<List<KubeconfigContext>>? _contextsFuture;
  List<KubeconfigContext> _cachedContexts = const [];
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;
  late final TabNavigationHandle _tabNavigator;
  late final CommandPaletteHandle _commandPaletteHandle;
  final Map<String, bool> _collapsedByConfigPath = {};

  List<KubernetesTab> get _tabs => _tabController.tabs;

  @override
  void initState() {
    super.initState();
    _contextsFuture = _loadContexts();
    _workspaceController = KubernetesWorkspaceController(
      settingsController: widget.settingsController,
      placeholderName: _placeholderName,
      placeholderConfig: _placeholderConfig,
    );
    _tabFactory = KubernetesTabFactory(
      placeholderName: _placeholderName,
      placeholderConfig: _placeholderConfig,
      buildPlaceholder: _buildContextSelection,
      buildDetails: _buildContextDetails,
      buildResources: _buildResources,
      detailsIcon: NerdIcon.kubernetes.data,
      resourcesIcon: NerdIcon.database.data,
    );
    _tabController = TabHostController<KubernetesTab>(
      baseTabBuilder: _createPlaceholderTab,
      tabId: (tab) => tab.id,
    );
    _tabRegistry = TabViewRegistry<KubernetesTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'k8s-tab',
    );
    _tabNavigator = TabNavigationHandle(
      next: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final next = (_tabController.selectedIndex + 1) % length;
        _tabController.select(next);
        return true;
      },
      previous: () {
        final length = _tabs.length;
        if (length <= 1) return false;
        final prev = (_tabController.selectedIndex - 1 + length) % length;
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
    _settingsListener = _handleSettingsChanged;
    _tabsListener = _handleTabsChanged;
    widget.settingsController.addListener(_settingsListener);
    final placeholder = _createPlaceholderTab();
    _tabRegistry.widgetFor(placeholder, () => placeholder.body);
    _tabController.addListener(_tabsListener);
    _restoreWorkspace();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    _tabController.removeListener(_tabsListener);
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    CommandPaletteRegistry.instance.unregister(
      widget.moduleId,
      _commandPaletteHandle,
    );
    _disposeTabControllers(_tabs);
    _emptyOptions.dispose();
    _tabController.dispose();
    super.dispose();
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
              child: TabbedWorkspaceShell<KubernetesTab>(
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
                    valueListenable: tab.optionsController ?? _emptyOptions,
                    builder: (context, options, _) {
                      return TabChip(
                        host: tab.host,
                        title: tab.title,
                        label: tab.label,
                        icon: tab.icon,
                        selected: index == _tabController.selectedIndex,
                        onSelect: () {
                          _tabController.select(index);
                          _persistWorkspace();
                        },
                        onClose: () => _closeTab(index),
                        onRename: tab.canRename ? () => _renameTab(index) : null,
                        options: options,
                        closable: tab.closable,
                        dragIndex: tab.canDrag ? index : null,
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
      ),
    );
  }

  Future<List<KubeconfigContext>> _loadContexts() async {
    final contexts = await _contextController.loadContexts(
      _contextController.resolveConfigPaths(widget.settingsController.settings),
    );
    _cachedContexts = contexts;
    _refreshTabContexts(contexts);
    return contexts;
  }

  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    _refreshContexts();
    _workspaceController.workspacePersistence.persistIfPending(
      _persistWorkspace,
    );
  }

  void _handleTabsChanged() {
    _tabRegistry.reset(_tabs);
    setState(() {});
    unawaited(_persistWorkspace());
  }

  void _refreshContexts() {
    _contextsFuture = _loadContexts();
    final updatedTabs = <KubernetesTab>[];
    for (final tab in _tabs) {
      if (tab.context == null) {
        final updated = tab.copyWith(body: _buildContextSelection());
        updatedTabs.add(updated);
        _tabRegistry.remove(tab);
        _tabRegistry.widgetFor(updated, () => updated.body);
      } else {
        updatedTabs.add(tab);
      }
    }
    _tabRegistry.reset(updatedTabs);
    _tabController.replaceAll(
      updatedTabs,
      selectedIndex: _tabController.selectedIndex,
    );
  }

  Future<void> _restoreWorkspace() async {
    final workspace = widget.settingsController.settings.kubernetesWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) {
      return;
    }
    if (!_workspaceController.workspacePersistence.shouldRestore(workspace)) {
      return;
    }
    List<KubeconfigContext> contexts;
    try {
      contexts = await (_contextsFuture ?? _loadContexts());
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to restore Kubernetes contexts',
        tag: 'Kubernetes',
        error: error,
        stackTrace: stackTrace,
      );
      contexts = const [];
    }
    if (!mounted) {
      return;
    }
    final restoredTabs = _buildTabsFromState(workspace, contexts);
    if (restoredTabs.isEmpty) {
      return;
    }
    _workspaceController.workspacePersistence.markRestored(workspace);
    _disposeTabControllers(_tabs);
    _tabRegistry.reset(restoredTabs);
    _tabController.replaceAll(
      restoredTabs,
      selectedIndex: workspace.selectedIndex,
    );
  }

  List<KubernetesTab> _buildTabsFromState(
    KubernetesWorkspaceState workspace,
    List<KubeconfigContext> contexts,
  ) {
    final restored = _workspaceController.buildTabsFromState(
      workspace: workspace,
      contexts: contexts,
      buildTab: (state) => _tabFromState(state, contexts),
    );
    if (restored.isEmpty) {
      restored.add(_createPlaceholderTab());
    }
    return restored;
  }

  KubernetesWorkspaceState _currentWorkspaceState() {
    return _workspaceController.currentWorkspaceState(
      _tabs,
      _tabController.selectedIndex,
    );
  }

  Future<void> _persistWorkspace() async {
    final workspace = _currentWorkspaceState();
    await _workspaceController.workspacePersistence.persist(workspace);
  }

  void _refreshTabContexts(List<KubeconfigContext> contexts) {
    bool changed = false;
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      final context = tab.context;
      if (context == null) {
        continue;
      }
      final fresh = _contextController.findContext(
        contexts,
        context.name,
        context.configPath,
      );
      if (fresh != null && !_contextController.contextEquals(context, fresh)) {
        final updatedBody = tab.kind == KubernetesTabKind.resources
            ? _buildResources(fresh, tab.optionsController!)
            : _buildContextDetails(fresh);
        final updated = tab.copyWith(context: fresh, body: updatedBody);
        _tabs[i] = updated;
        _syncTabOptions(updated);
        _tabRegistry.remove(tab);
        _tabRegistry.widgetFor(updated, () => updated.body);
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  void _syncTabOptions(KubernetesTab tab) {
    final options = <TabChipOption>[];
    final context = tab.context;
    if (context != null) {
      if (tab.kind == KubernetesTabKind.details) {
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
      } else if (tab.kind == KubernetesTabKind.resources) {
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

  KubernetesTab? _tabFromState(
    TabState state,
    List<KubeconfigContext> contexts,
  ) {
    return _workspaceController.tabFromState(
      state: state,
      contexts: contexts,
      factory: _tabFactory,
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  KubernetesTab _createPlaceholderTab({String? id}) {
    final tab = _tabFactory.placeholder(id: id);
    _syncTabOptions(tab);
    return tab;
  }

  KubernetesTab _createContextTab({
    required KubeconfigContext context,
    String? id,
    String? customName,
    KubernetesTabKind kind = KubernetesTabKind.details,
    TabOptionsController? optionsController,
  }) {
    final tab = _tabFactory.contextTab(
      id: id ?? 'k8s-${_uniqueId()}',
      context: context,
      customName: customName,
      kind: kind,
      optionsController: optionsController,
    );
    _syncTabOptions(tab);
    return tab;
  }

  Widget _buildContextSelection() {
    return FutureBuilder<List<KubeconfigContext>>(
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
            final contextsForPath = grouped[configPath]!;
            final collapsed = _isConfigCollapsed(configPath);
            final sectionColor = _sectionBackgroundForIndex(context, index);
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: SectionList(
                title: path.basename(configPath),
                backgroundColor: sectionColor,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        collapsed ? Icons.expand_more : Icons.expand_less,
                        size: 18,
                      ),
                      tooltip: collapsed ? 'Expand' : 'Collapse',
                      onPressed: () => _toggleConfigCollapsed(configPath),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Section options',
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onSelected: (value) {
                        if (value == 'reloadContexts') {
                          _refreshContexts();
                        } else if (value == 'openConfig') {
                          ExternalAppLauncher.openConfigFile(
                            configPath,
                            context,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'reloadContexts',
                          child: Text('Reload contexts'),
                        ),
                        PopupMenuItem<String>(
                          value: 'openConfig',
                          child: Text('Open kubeconfig'),
                        ),
                      ],
                    ),
                  ],
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
                          onRowDoubleTap: _openContextTab,
                          rowContextMenuBuilder: _buildContextMenuActions,
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isConfigCollapsed(String configPath) {
    return _collapsedByConfigPath[configPath] ?? false;
  }

  void _toggleConfigCollapsed(String configPath) {
    setState(() {
      _collapsedByConfigPath[configPath] =
          !(_collapsedByConfigPath[configPath] ?? false);
    });
  }

  Color _sectionBackgroundForIndex(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    final base = context.appTheme.section.surface.background;
    final overlay = scheme.surfaceTint.withValues(alpha: 0.08);
    final alternate = Color.alphaBlend(overlay, base);
    return index.isEven ? base : alternate;
  }

  String _valueOrDash(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }
    return value;
  }

  List<StructuredDataColumn<KubeconfigContext>> _contextColumns(
    BuildContext context,
  ) {
    return [
      StructuredDataColumn<KubeconfigContext>(
        label: 'Context',
        autoFitText: (kubeContext) => kubeContext.name,
        cellBuilder: _buildContextCell,
      ),
      StructuredDataColumn<KubeconfigContext>(
        label: 'Cluster',
        autoFitText: (kubeContext) => _valueOrDash(kubeContext.cluster),
        cellBuilder: (context, kubeContext) =>
            Text(_valueOrDash(kubeContext.cluster)),
      ),
      StructuredDataColumn<KubeconfigContext>(
        label: 'Namespace',
        autoFitText: (kubeContext) => _valueOrDash(kubeContext.namespace),
        cellBuilder: (context, kubeContext) =>
            Text(_valueOrDash(kubeContext.namespace)),
      ),
      StructuredDataColumn<KubeconfigContext>(
        label: 'User',
        autoFitText: (kubeContext) => _valueOrDash(kubeContext.user),
        cellBuilder: (context, kubeContext) =>
            Text(_valueOrDash(kubeContext.user)),
      ),
      StructuredDataColumn<KubeconfigContext>(
        label: 'Endpoint',
        autoFitText: (kubeContext) => _valueOrDash(kubeContext.server),
        cellBuilder: (context, kubeContext) =>
            Text(_valueOrDash(kubeContext.server)),
      ),
    ];
  }

  Widget _buildContextCell(
    BuildContext context,
    KubeconfigContext kubeContext,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = _leadingIconSize(context);
    final statusColor = kubeContext.isCurrent
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final statusDotScale = 10 / iconSize;
    return Row(
      children: [
        DistroLeadingSlot(
          iconData: NerdIcon.kubernetes.data,
          iconSize: iconSize,
          iconColor: statusColor,
          statusColor: statusColor,
          statusDotScale: statusDotScale,
        ),
        SizedBox(width: context.appTheme.spacing.md),
        Expanded(
          child: Text(
            kubeContext.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  List<StructuredDataChip> _contextMetadata(KubeconfigContext kubeContext) {
    if (!kubeContext.isCurrent) {
      return const [];
    }
    return const [
      StructuredDataChip(label: 'Current', icon: Icons.check_circle),
    ];
  }

  List<StructuredDataMenuAction<KubeconfigContext>> _buildContextMenuActions(
    KubeconfigContext kubeContext,
    List<KubeconfigContext> selected,
    Offset? anchor,
  ) {
    return [
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open context',
        icon: NerdIcon.kubernetes.data,
        onSelected: (_, primary) => _openContextTab(primary),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open resources',
        icon: NerdIcon.database.data,
        onSelected: (_, primary) =>
            _openContextTab(primary, kind: KubernetesTabKind.resources),
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Copy server URL',
        icon: Icons.copy,
        enabled: kubeContext.server != null,
        onSelected: (_, primary) {
          final server = primary.server;
          if (server == null) {
            return;
          }
          Clipboard.setData(ClipboardData(text: server));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server endpoint copied')),
          );
        },
      ),
      StructuredDataMenuAction<KubeconfigContext>(
        label: 'Open kubeconfig',
        icon: Icons.edit,
        onSelected: (_, primary) =>
            ExternalAppLauncher.openConfigFile(primary.configPath, context),
      ),
    ];
  }

  double _leadingIconSize(BuildContext context) {
    final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
    return titleSize * 1.9;
  }

  Widget _buildResources(
    KubeconfigContext context,
    TabOptionsController optionsController,
  ) {
    return KubernetesResources(
      contextName: context.name,
      configPath: context.configPath,
      kubectl: _kubectl,
      optionsController: optionsController,
    );
  }

  Widget _buildContextDetails(KubeconfigContext kubeContext) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * 2,
        vertical: spacing.base * 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(NerdIcon.kubernetes.data, color: scheme.primary),
              SizedBox(width: spacing.base),
              Expanded(
                child: Text(
                  kubeContext.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (kubeContext.isCurrent)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.base * 2.5,
                    vertical: spacing.base * 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'Current',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.base * 1.5),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base * 1.5,
                vertical: spacing.base * 1.5,
              ),
              child: Column(
                children: [
                  _detailRow('Cluster', kubeContext.cluster ?? '—'),
                  _detailRow('Namespace', kubeContext.namespace ?? '—'),
                  _detailRow('User', kubeContext.user ?? '—'),
                  _detailRow('Server', kubeContext.server ?? '—'),
                  _detailRow('Config path', kubeContext.configPath),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.base * 1.5),
          Wrap(
            spacing: spacing.base,
            runSpacing: spacing.base * 0.5,
            children: [
              FilledButton.icon(
                onPressed: () => ExternalAppLauncher.openConfigFile(
                  kubeContext.configPath,
                  context,
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Open kubeconfig'),
              ),
              if (kubeContext.server != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kubeContext.server!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server endpoint copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy server'),
                ),
              OutlinedButton.icon(
                onPressed: _refreshContexts,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload contexts'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.appTheme.spacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _openContextTab(
    KubeconfigContext context, {
    KubernetesTabKind kind = KubernetesTabKind.details,
    String? replaceTabId,
  }) {
    final existingIndex = _tabs.indexWhere(
      (tab) =>
          tab.kind == kind &&
          tab.context?.name == context.name &&
          tab.context?.configPath == context.configPath,
    );
    final tab = _createContextTab(
      context: context,
      id: replaceTabId ?? 'k8s-${_uniqueId()}',
      kind: kind,
    );
    if (existingIndex != -1) {
      _tabController.select(existingIndex);
      _persistWorkspace();
      return;
    }
    if (replaceTabId != null) {
      _replaceTab(replaceTabId, tab);
      _persistWorkspace();
      return;
    }
    if (_replacePlaceholderWithSelected(tab)) {
      _persistWorkspace();
      return;
    }
    _tabRegistry.widgetFor(tab, () => tab.body);
    _tabController.addTab(tab);
    _persistWorkspace();
  }

  void _replaceTab(String tabId, KubernetesTab tab) {
    final index = _tabs.indexWhere((existing) => existing.id == tabId);
    if (index == -1) {
      return;
    }
    final old = _tabs[index];
    old.optionsController?.dispose();
    _tabRegistry.remove(old);
    _tabRegistry.widgetFor(tab, () => tab.body);
    _tabController.replaceTab(old.id, tab);
    _tabController.select(index);
  }

  void _reloadResourceTab(String tabId) {
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index == -1) {
      return;
    }
    final tab = _tabs[index];
    final context = tab.context;
    if (context == null || tab.kind != KubernetesTabKind.resources) {
      return;
    }
    final controller = tab.optionsController;
    if (controller == null) return;
    final updated = tab.copyWith(body: _buildResources(context, controller));
    _tabs[index] = updated;
    _tabRegistry.remove(tab);
    _tabRegistry.widgetFor(updated, () => updated.body);
    setState(() {});
  }

  bool _replacePlaceholderWithSelected(KubernetesTab tab) {
    if (_tabs.isEmpty) {
      return false;
    }
    final index = _tabController.selectedIndex.clamp(0, _tabs.length - 1);
    final current = _tabs[index];
    if (current.context != null) {
      return false;
    }
    current.optionsController?.dispose();
    _tabRegistry.remove(current);
    _tabRegistry.widgetFor(tab, () => tab.body);
    _tabController.replaceTab(current.id, tab);
    _tabController.select(index);
    return true;
  }

  void _startEmptyTab() {
    final placeholder = _createPlaceholderTab();
    _tabRegistry.widgetFor(placeholder, () => placeholder.body);
    _tabController.addTab(placeholder);
    _persistWorkspace();
  }

  List<CommandPaletteEntry> _buildCommandPaletteEntries() {
    final entries = <CommandPaletteEntry>[];
    if (_tabs.isNotEmpty) {
      final tab = _tabs[_tabController.selectedIndex];
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
          onSelected: () => _renameTab(_tabController.selectedIndex),
        ),
      );
      entries.add(
        CommandPaletteEntry(
          id: '${widget.moduleId}:closeTab',
          label: 'Close tab',
          category: 'Tabs',
          onSelected: () => _closeTab(_tabController.selectedIndex),
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

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    if (_tabs.length == 1) {
      final oldTab = _tabs[0];
      oldTab.optionsController?.dispose();
      final placeholder = _createPlaceholderTab(id: oldTab.id);
      _tabRegistry
        ..clear()
        ..widgetFor(placeholder, () => placeholder.body);
      _tabController.replaceTab(oldTab.id, placeholder);
      _tabController.select(0);
    } else {
      final removed = _tabs[index];
      removed.optionsController?.dispose();
      _tabRegistry.remove(removed);
      _tabController.closeTab(index, baseReplacement: _createPlaceholderTab());
      final base = _tabController.tabs.first;
      _tabRegistry.widgetFor(base, () => base.body);
    }
    _persistWorkspace();
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    _tabController.reorder(oldIndex, newIndex);
    _persistWorkspace();
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
        builder: (dialogContext) => DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: AlertDialog(
            title: const Text('Rename tab'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tab name'),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      _disposeControllerAfterFrame(controller);
    }
    if (newName == null) {
      return;
    }
    final trimmed = newName.trim();
    final updated = tab.copyWith(
      customName: trimmed.isEmpty ? null : trimmed,
      setCustomName: true,
    );
    _tabRegistry.remove(tab);
    _tabRegistry.widgetFor(updated, () => updated.body);
    _tabController.replaceTab(tab.id, updated);
    _persistWorkspace();
  }

  void _disposeControllerAfterFrame(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void _disposeTabControllers(Iterable<KubernetesTab> tabs) {
    for (final tab in tabs) {
      tab.optionsController?.dispose();
    }
  }
}
