import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'package:cwatch/core/models/tab_state.dart';
import 'package:cwatch/core/tabs/tab_host.dart';
import 'package:cwatch/models/kubernetes_workspace_state.dart';
import 'package:cwatch/services/kubernetes/kubectl_service.dart';
import 'package:cwatch/services/kubernetes/kubeconfig_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/lists/selectable_list_item.dart';
import 'package:cwatch/shared/widgets/lists/section_list.dart';
import 'package:cwatch/shared/views/shared/tabs/file_explorer/external_app_launcher.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';
import 'package:cwatch/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/core/tabs/tab_view_registry.dart';
import 'package:cwatch/core/widgets/keep_alive.dart';
import 'widgets/kubernetes_resources.dart';
import 'kubernetes_tab.dart';
import 'kubernetes_tab_factory.dart';
import 'kubernetes_workspace_controller.dart';
import 'kubernetes_context_controller.dart';

class KubernetesContextList extends StatefulWidget {
  const KubernetesContextList({
    super.key,
    required this.settingsController,
    this.leading,
  });

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
  String? _selectedContextKey;

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
      keepAliveBuilder: (child, key) => KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'k8s-tab',
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
    _disposeTabControllers(_tabs);
    _emptyOptions.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          Expanded(
            child: Material(
              color: appTheme.section.toolbarBackground,
              child: TabbedWorkspaceShell<KubernetesTab>(
                controller: _tabController,
                registry: _tabRegistry,
                tabBarHeight: 36,
                leading: widget.leading != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                          _selectedContextKey = _tabContextKey(tab);
                          _persistWorkspace();
                        },
                        onClose: () => _closeTab(index),
                        onRename: tab.canRename
                            ? () => _renameTab(index)
                            : null,
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
      _contextController.resolveConfigPaths(
        widget.settingsController.settings,
      ),
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
    _workspaceController.workspacePersistence.persistIfPending(_persistWorkspace);
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
    } catch (_) {
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
    final selectedTab = _tabs.isEmpty
        ? null
        : _tabs[_tabController.selectedIndex.clamp(0, _tabs.length - 1)];
    _selectedContextKey = selectedTab != null
        ? _tabContextKey(selectedTab)
        : null;
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
        final spacing = context.appTheme.spacing;
        final refreshButton = Padding(
          padding: EdgeInsets.only(
            left: spacing.base * 2,
            right: spacing.base * 2,
            bottom: spacing.base,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _refreshContexts,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reload contexts'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.base * 1.5,
                  vertical: spacing.sm,
                ),
              ),
            ),
          ),
        );

        if (configPaths.length == 1) {
          final onlyPath = configPaths.first;
          final contextsForPath = grouped[onlyPath]!;
          return Column(
            children: [
              refreshButton,
              Expanded(
                child: SectionList(
                  title: path.basename(onlyPath),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Open kubeconfig',
                    onPressed: () =>
                        ExternalAppLauncher.openConfigFile(onlyPath, context),
                  ),
                  children: contextsForPath
                      .map((ctx) => _buildContextTile(ctx))
                      .toList(),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            refreshButton,
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: configPaths.length,
                itemBuilder: (context, index) {
                  final configPath = configPaths[index];
                  final contextsForPath = grouped[configPath]!;
                  return Padding(
                    padding: EdgeInsets.only(bottom: spacing.base * 1.5),
                    child: SectionList(
                      title: path.basename(configPath),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Open kubeconfig',
                        onPressed: () => ExternalAppLauncher.openConfigFile(
                          configPath,
                          context,
                        ),
                      ),
                      children: contextsForPath
                          .map((ctx) => _buildContextTile(ctx))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContextTile(KubeconfigContext context) {
    final selected = _selectedContextKey == _contextKey(context);
    final scheme = Theme.of(this.context).colorScheme;
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (context.isCurrent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Current',
              style: Theme.of(this.context).textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
    Offset? lastPointer;
    return SelectableListItem(
      selected: selected,
      title: context.name,
      subtitle: _contextSubtitle(context),
      leading: Icon(
        NerdIcon.kubernetes.data,
        size: 20,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      badge: badge,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, size: 18),
        tooltip: 'Context options',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
        onPressed: () => _showContextMenu(context),
      ),
      onTapDown: (details) => lastPointer = details.globalPosition,
      onDoubleTapDown: (details) => lastPointer = details.globalPosition,
      onTap: () {
        setState(() {
          _selectedContextKey = _contextKey(context);
        });
      },
      onDoubleTap: () => _openContextTab(context),
      onLongPress: () => _showContextMenu(context, lastPointer),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
    );
  }

  String _contextSubtitle(KubeconfigContext context) {
    final parts = <String>[];
    if (context.cluster != null) {
      parts.add('Cluster: ${context.cluster}');
    }
    if (context.namespace != null) {
      parts.add('Namespace: ${context.namespace}');
    }
    if (context.user != null) {
      parts.add('User: ${context.user}');
    }
    if (context.server != null) {
      parts.add(context.server!);
    }
    return parts.join(' • ');
  }

  String _contextKey(KubeconfigContext context) =>
      '${context.name}|${context.configPath}';

  String _tabContextKey(KubernetesTab tab) {
    final context = tab.context;
    if (context == null) return '';
    return _contextKey(context);
  }

  void _showContextMenu(
    KubeconfigContext context, [
    Offset? tapPosition,
  ]) async {
    final overlay = Overlay.of(this.context).context.findRenderObject();
    if (overlay is! RenderBox) {
      return;
    }
    final base = overlay.localToGlobal(Offset.zero);
    final anchor = tapPosition ?? base + const Offset(200, 200);
    final position = RelativeRect.fromLTRB(
      anchor.dx - base.dx,
      anchor.dy - base.dy,
      anchor.dx - base.dx,
      anchor.dy - base.dy,
    );
    final choice = await showMenu<String>(
      context: this.context,
      position: position,
      items: _contextActions(context, Theme.of(this.context).colorScheme),
    );
    _handleContextAction(choice, context);
  }

  List<PopupMenuEntry<String>> _contextActions(
    KubeconfigContext context,
    ColorScheme scheme,
  ) {
    return [
      PopupMenuItem(
        value: 'open',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(NerdIcon.kubernetes.data, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Open context'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'resources',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(NerdIcon.database.data, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Open resources'),
          ],
        ),
      ),
      PopupMenuItem(
        enabled: context.server != null,
        value: 'copy-server',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Copy server URL'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'open-config',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('Open kubeconfig'),
          ],
        ),
      ),
    ];
  }

  void _handleContextAction(String? choice, KubeconfigContext context) {
    switch (choice) {
      case 'open':
        _openContextTab(context);
        break;
      case 'resources':
        _openContextTab(context, kind: KubernetesTabKind.resources);
        break;
      case 'copy-server':
        if (context.server != null) {
          Clipboard.setData(ClipboardData(text: context.server!));
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('Server endpoint copied')),
          );
        }
        break;
      case 'open-config':
        ExternalAppLauncher.openConfigFile(context.configPath, this.context);
        break;
      default:
        break;
    }
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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
        builder: (dialogContext) => AlertDialog(
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
