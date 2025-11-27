import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../../models/kubernetes_workspace_state.dart';
import '../../../models/ssh_host.dart';
import '../../../services/kubernetes/kubeconfig_service.dart';
import '../../../services/kubernetes/kubectl_service.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../../widgets/lists/section_list.dart';
import '../../widgets/lists/section_list_item.dart';
import '../shared/tabs/file_explorer/external_app_launcher.dart';
import '../shared/tabs/tab_chip.dart';
import 'widgets/kubernetes_resources.dart';

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

  final KubeconfigService _kubeconfig = const KubeconfigService();
  final KubectlService _kubectl = const KubectlService();
  final List<_KubeTab> _tabs = [];
  final Map<String, Widget> _tabBodies = {};
  int _selectedIndex = 0;
  Future<List<KubeconfigContext>>? _contextsFuture;
  List<KubeconfigContext> _cachedContexts = const [];
  late final VoidCallback _settingsListener;
  bool _pendingWorkspaceSave = false;
  String? _restoredSignature;
  String? _lastPersistedSignature;
  String? _selectedContextKey;

  @override
  void initState() {
    super.initState();
    _contextsFuture = _loadContexts();
    final placeholder = _createPlaceholderTab();
    _tabs.add(placeholder);
    _tabBodies[placeholder.id] = placeholder.body;
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _restoreWorkspace();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    _disposeTabControllers(_tabs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.appTheme;
    final selectedIndex = _tabs.isEmpty
        ? 0
        : _selectedIndex.clamp(0, _tabs.length - 1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        children: [
          Material(
            color: appTheme.section.toolbarBackground,
            child: Row(
              children: [
                if (widget.leading != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      height: 36,
                      child: Center(child: widget.leading),
                    ),
                  ),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: appTheme.spacing.inset(
                        horizontal: 1,
                        vertical: 0,
                      ),
                      buildDefaultDragHandles: false,
                      onReorder: _handleTabReorder,
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final tab = _tabs[index];
                        return ValueListenableBuilder<List<TabChipOption>>(
                          key: ValueKey(tab.id),
                          valueListenable: tab.options,
                          builder: (context, options, _) {
                            return TabChip(
                              host: tab.host,
                              title: tab.title,
                              label: tab.label,
                              icon: tab.icon,
                              selected: index == selectedIndex,
                              onSelect: () {
                                setState(() => _selectedIndex = index);
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
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New tab',
                  icon: Icon(NerdIcon.add.data),
                  onPressed: _startEmptyTab,
                ),
              ],
            ),
          ),
          Padding(
            padding: appTheme.spacing.inset(horizontal: 2, vertical: 0),
            child: Divider(height: 1, color: appTheme.section.divider),
          ),
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: _tabs
                  .map(
                    (tab) => KeyedSubtree(
                      key: ValueKey('k8s-body-${tab.id}'),
                      child: _tabBodies[tab.id] ?? const SizedBox.shrink(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<KubeconfigContext>> _loadContexts() async {
    final contexts = await _kubeconfig.listContexts(_resolveConfigPaths());
    _cachedContexts = contexts;
    _refreshTabContexts(contexts);
    return contexts;
  }

  List<String> _resolveConfigPaths() {
    final settings = widget.settingsController.settings;
    if (settings.kubernetesConfigPaths.isNotEmpty) {
      return settings.kubernetesConfigPaths;
    }
    final env = Platform.environment['KUBECONFIG']?.trim();
    if (env != null && env.isNotEmpty) {
      final separator = Platform.isWindows ? ';' : ':';
      return env
          .split(separator)
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return [path.join(home, '.kube', 'config')];
    }
    return const [];
  }

  void _handleSettingsChanged() {
    if (!mounted) {
      return;
    }
    _refreshContexts();
    if (_pendingWorkspaceSave && widget.settingsController.isLoaded) {
      _persistWorkspace();
    }
  }

  void _refreshContexts() {
    setState(() {
      _contextsFuture = _loadContexts();
      for (var i = 0; i < _tabs.length; i++) {
        final tab = _tabs[i];
        if (tab.context == null) {
          final updated = tab.copyWith(body: _buildContextSelection());
          _tabs[i] = updated;
          _tabBodies[updated.id] = updated.body;
        }
      }
    });
  }

  Future<void> _restoreWorkspace() async {
    final workspace = widget.settingsController.settings.kubernetesWorkspace;
    if (workspace == null || workspace.tabs.isEmpty) {
      return;
    }
    final signature = workspace.signature;
    if (_restoredSignature == signature) {
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
    setState(() {
      _disposeTabControllers(_tabs);
      _tabs
        ..clear()
        ..addAll(restoredTabs);
      _tabBodies
        ..clear()
        ..addEntries(restoredTabs.map((tab) => MapEntry(tab.id, tab.body)));
      _selectedIndex = workspace.selectedIndex.clamp(0, _tabs.length - 1);
      _restoredSignature = signature;
      _lastPersistedSignature = signature;
    });
  }

  List<_KubeTab> _buildTabsFromState(
    KubernetesWorkspaceState workspace,
    List<KubeconfigContext> contexts,
  ) {
    final restored = <_KubeTab>[];
    for (final tabState in workspace.tabs) {
      if (_isPlaceholderState(tabState)) {
        restored.add(_createPlaceholderTab(id: tabState.id));
        continue;
      }
      final context = _findContext(
        contexts,
        tabState.contextName,
        tabState.configPath,
      );
      if (context == null) {
        continue;
      }
      restored.add(
        _createContextTab(
          id: tabState.id,
          context: context,
          customName: tabState.customName,
          kind: tabState.kind,
        ),
      );
    }
    if (restored.isEmpty) {
      final placeholder = _createPlaceholderTab();
      restored.add(placeholder);
    }
    return restored;
  }

  bool _isPlaceholderState(KubernetesTabState state) {
    return state.contextName == _placeholderName &&
        state.configPath == _placeholderConfig;
  }

  KubernetesWorkspaceState _currentWorkspaceState() {
    final tabs = _tabs.map((tab) {
      final context = tab.context;
      if (context == null) {
        return KubernetesTabState(
          id: tab.id,
          contextName: _placeholderName,
          configPath: _placeholderConfig,
          customName: tab.customName,
          kind: tab.kind,
        );
      }
      return KubernetesTabState(
        id: tab.id,
        contextName: context.name,
        configPath: context.configPath,
        customName: tab.customName,
        kind: tab.kind,
      );
    }).toList();
    final clampedIndex = _tabs.isEmpty
        ? 0
        : _selectedIndex.clamp(0, _tabs.length - 1);
    return KubernetesWorkspaceState(tabs: tabs, selectedIndex: clampedIndex);
  }

  void _persistWorkspace() {
    if (!widget.settingsController.isLoaded) {
      _pendingWorkspaceSave = true;
      return;
    }
    final workspace = _currentWorkspaceState();
    final signature = workspace.signature;
    if (_lastPersistedSignature == signature) {
      return;
    }
    _pendingWorkspaceSave = false;
    _lastPersistedSignature = signature;
    _restoredSignature = signature;
    unawaited(
      widget.settingsController.update(
        (current) => current.copyWith(kubernetesWorkspace: workspace),
      ),
    );
  }

  void _refreshTabContexts(List<KubeconfigContext> contexts) {
    bool changed = false;
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      final context = tab.context;
      if (context == null) {
        continue;
      }
      final fresh = _findContext(contexts, context.name, context.configPath);
      if (fresh != null && !_contextEquals(context, fresh)) {
        final updatedBody = tab.kind == KubernetesTabKind.resources
            ? _buildResources(fresh, tab.options)
            : _buildContextDetails(fresh);
        _tabs[i] = tab.copyWith(context: fresh, body: updatedBody);
        _syncTabOptions(_tabs[i]);
        _tabBodies[tab.id] = _tabs[i].body;
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  void _syncTabOptions(_KubeTab tab) {
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
    if (tab.options is CompositeTabOptionsController) {
      (tab.options as CompositeTabOptionsController).updateBase(options);
    } else {
      tab.options.update(options);
    }
  }

  bool _contextEquals(KubeconfigContext a, KubeconfigContext b) {
    return a.name == b.name &&
        a.cluster == b.cluster &&
        a.user == b.user &&
        a.namespace == b.namespace &&
        a.server == b.server &&
        a.configPath == b.configPath &&
        a.isCurrent == b.isCurrent;
  }

  KubeconfigContext? _findContext(
    List<KubeconfigContext> contexts,
    String name,
    String configPath,
  ) {
    for (final context in contexts) {
      if (context.name == name && context.configPath == configPath) {
        return context;
      }
    }
    return null;
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  _KubeTab _createPlaceholderTab({String? id}) {
    final tab = _createTab(
      id: id ?? 'k8s-placeholder-${_uniqueId()}',
      context: null,
      kind: KubernetesTabKind.details,
      closable: false,
      canDrag: false,
      body: _buildContextSelection(),
    );
    _syncTabOptions(tab);
    return tab;
  }

  _KubeTab _createContextTab({
    required KubeconfigContext context,
    String? id,
    String? customName,
    KubernetesTabKind kind = KubernetesTabKind.details,
  }) {
    final optionsController = kind == KubernetesTabKind.resources
        ? CompositeTabOptionsController()
        : TabOptionsController();
    final tab = _createTab(
      id: id ?? 'k8s-${_uniqueId()}',
      context: context,
      customName: customName,
      closable: true,
      canDrag: true,
      kind: kind,
      body: kind == KubernetesTabKind.resources
          ? _buildResources(context, optionsController)
          : _buildContextDetails(context),
      options: optionsController,
    );
    _syncTabOptions(tab);
    return tab;
  }

  _KubeTab _createTab({
    required String id,
    required KubeconfigContext? context,
    String? customName,
    required KubernetesTabKind kind,
    required bool closable,
    required bool canDrag,
    required Widget body,
    TabOptionsController? options,
  }) {
    return _KubeTab(
      id: id,
      context: context,
      kind: kind,
      customName: customName,
      closable: closable,
      canDrag: canDrag,
      body: body,
      options: options,
    );
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
        final grouped = _groupByConfigPath(contexts);
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

  Map<String, List<KubeconfigContext>> _groupByConfigPath(
    List<KubeconfigContext> contexts,
  ) {
    final grouped = <String, List<KubeconfigContext>>{};
    for (final context in contexts) {
      grouped.putIfAbsent(context.configPath, () => []).add(context);
    }
    return grouped;
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
    return SectionListItem(
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
      onTap: () {
        setState(() {
          _selectedContextKey = _contextKey(context);
        });
      },
      onDoubleTap: () => _openContextTab(context),
      onLongPress: () => _showContextMenu(context),
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
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(
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
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(
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
    if (existingIndex != -1) {
      setState(() => _selectedIndex = existingIndex);
      _persistWorkspace();
      return;
    }
    final tab = _createContextTab(
      context: context,
      id: replaceTabId ?? 'k8s-${_uniqueId()}',
      kind: kind,
    );
    if (replaceTabId != null) {
      _replaceTab(replaceTabId, tab);
      _persistWorkspace();
      return;
    }
    setState(() {
      if (_replacePlaceholderWithSelected(tab)) {
        return;
      }
      _tabs.add(tab);
      _tabBodies[tab.id] = tab.body;
      _selectedIndex = _tabs.length - 1;
    });
    _persistWorkspace();
  }

  void _replaceTab(String tabId, _KubeTab tab) {
    final index = _tabs.indexWhere((existing) => existing.id == tabId);
    if (index == -1) {
      return;
    }
    final old = _tabs[index];
    if (old.id != tab.id) {
      _tabBodies.remove(old.id);
    }
    old.options.dispose();
    _tabs[index] = tab;
    _tabBodies[tab.id] = tab.body;
    setState(() {
      _selectedIndex = index;
    });
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
    final updated = tab.copyWith(body: _buildResources(context, tab.options));
    _tabs[index] = updated;
    _tabBodies[tab.id] = updated.body;
    setState(() {});
  }

  bool _replacePlaceholderWithSelected(_KubeTab tab) {
    if (_tabs.isEmpty) {
      return false;
    }
    final index = _selectedIndex.clamp(0, _tabs.length - 1);
    final current = _tabs[index];
    if (current.context != null) {
      return false;
    }
    current.options.dispose();
    _tabs[index] = tab;
    _tabBodies
      ..remove(current.id)
      ..[tab.id] = tab.body;
    return true;
  }

  void _startEmptyTab() {
    setState(() {
      final placeholder = _createPlaceholderTab();
      _tabs.add(placeholder);
      _tabBodies[placeholder.id] = placeholder.body;
      _selectedIndex = _tabs.length - 1;
    });
    _persistWorkspace();
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      if (_tabs.length == 1) {
        final oldTab = _tabs[0];
        oldTab.options.dispose();
        final placeholder = _createPlaceholderTab();
        _tabs[0] = placeholder;
        _tabBodies
          ..clear()
          ..[placeholder.id] = placeholder.body;
        _selectedIndex = 0;
      } else {
        final removed = _tabs.removeAt(index);
        removed.options.dispose();
        _tabBodies.remove(removed.id);
        if (_selectedIndex >= _tabs.length) {
          _selectedIndex = _tabs.length - 1;
        } else if (_selectedIndex > index) {
          _selectedIndex -= 1;
        }
      }
    });
    _persistWorkspace();
  }

  void _handleTabReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final moved = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, moved);
      if (_selectedIndex == oldIndex) {
        _selectedIndex = newIndex;
      } else if (_selectedIndex >= oldIndex && _selectedIndex < newIndex) {
        _selectedIndex -= 1;
      } else if (_selectedIndex <= oldIndex && _selectedIndex > newIndex) {
        _selectedIndex += 1;
      }
    });
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
    setState(() {
      _tabs[index] = tab.copyWith(
        customName: trimmed.isEmpty ? null : trimmed,
        setCustomName: true,
      );
    });
    _persistWorkspace();
  }

  void _disposeControllerAfterFrame(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void _disposeTabControllers(Iterable<_KubeTab> tabs) {
    for (final tab in tabs) {
      tab.options.dispose();
    }
  }
}

class _KubeTab {
  _KubeTab({
    required this.id,
    required this.context,
    required this.kind,
    required this.closable,
    required this.canDrag,
    required this.body,
    this.customName,
    TabOptionsController? options,
  }) : options = options ?? TabOptionsController();

  final String id;
  final KubeconfigContext? context;
  final KubernetesTabKind kind;
  final bool closable;
  final bool canDrag;
  final Widget body;
  final String? customName;
  final TabOptionsController options;

  String get title {
    if (customName != null && customName!.trim().isNotEmpty) {
      return customName!.trim();
    }
    if (context != null) {
      return context!.name;
    }
    return 'Kubernetes';
  }

  String get label => title;

  IconData get icon {
    if (kind == KubernetesTabKind.resources) {
      return NerdIcon.database.data;
    }
    return NerdIcon.kubernetes.data;
  }

  bool get canRename => context != null;

  SshHost get host => SshHost(
    name: label,
    hostname: context?.server ?? '',
    port: 0,
    available: true,
  );

  _KubeTab copyWith({
    KubeconfigContext? context,
    String? customName,
    bool setCustomName = false,
    Widget? body,
  }) {
    return _KubeTab(
      id: id,
      context: context ?? this.context,
      kind: kind,
      closable: closable,
      canDrag: canDrag,
      body: body ?? this.body,
      customName: setCustomName ? customName : this.customName,
      options: options,
    );
  }
}
