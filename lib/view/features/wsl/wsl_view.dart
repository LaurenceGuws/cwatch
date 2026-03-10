import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/tabs/tab_bar_visibility.dart';
import 'package:cwatch/view/core/tabs/tab_view_registry.dart';
import 'package:cwatch/view/core/tabs/tabbed_workspace_shell.dart';
import 'package:cwatch/view/core/widgets/keep_alive.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/features/wsl/models/wsl_tab_data.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/wsl/services/wsl_distribution.dart';
import 'package:cwatch/model/features/wsl/services/wsl_service_interface.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/views/shared/tabs/tab_chip.dart';

import 'package:cwatch/controller/adapters/wsl_ui_adapter.dart';
import 'package:cwatch/controller/di/bindings/wsl_terminal_session_binding.dart';
import 'package:cwatch/controller/di/bindings/wsl_workspace_controller_binding.dart';

import 'package:cwatch/controller/controllers/wsl_workspace_controller.dart';
import 'package:cwatch/view/features/wsl/wsl_tab_builder.dart';

class WslView extends StatefulWidget {
  const WslView({
    super.key,
    required this.moduleId,
    this.leading,
    required this.settingsController,
    required this.service,
  });

  final String moduleId;
  final Widget? leading;
  final AppSettingsController settingsController;
  final WslService service;

  @override
  State<WslView> createState() => _WslViewState();
}

class _WslViewState extends State<WslView> {
  final WslWorkspaceControllerBinding _workspaceBinding =
      const WslWorkspaceControllerBinding();
  final WslTerminalSessionBinding _terminalSessionBinding =
      const WslTerminalSessionBinding();
  late final WslTabBuilder _tabBuilder;
  late final WslWorkspaceController _workspaceController;
  late final WslUiAdapter _uiAdapter;
  late final TabViewRegistry<WorkspaceTab> _tabRegistry;
  late final TabNavigationHandle _tabNavigator;
  late final VoidCallback _settingsListener;
  late final VoidCallback _tabsListener;

  late Future<List<WslDistribution>> _distrosFuture;

  List<WorkspaceTab> get _tabs => _workspaceController.tabs;
  int get _selectedIndex => _workspaceController.selectedIndex;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _uiAdapter = WslUiAdapter(context: context);
    _distrosFuture = _loadDistributions();

    _tabBuilder = WslTabBuilder(settingsController: widget.settingsController);

    _workspaceController = _workspaceBinding.create(
      settingsController: widget.settingsController,
      baseTabBuilder: () => _distroPickerTab(),
    );

    _tabRegistry = TabViewRegistry<WorkspaceTab>(
      tabId: (tab) => tab.id,
      keepAliveBuilder: (child, key) =>
          KeepAliveWrapper(key: key, child: child),
      viewKeyPrefix: 'wsl-tab',
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
    _workspaceController.dispose();
    widget.settingsController.removeListener(_settingsListener);
    TabNavigationRegistry.instance.unregister(widget.moduleId, _tabNavigator);
    super.dispose();
  }

  Future<List<WslDistribution>> _loadDistributions() {
    if (!_isWindows) {
      return Future.value(const []);
    }
    return widget.service.listDistributions();
  }

  void _refreshDistros() {
    setState(() {
      _distrosFuture = _loadDistributions();
    });
  }

  WorkspaceTab _distroPickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    return _tabBuilder.picker(id: tabId, body: _buildPickerBody(tabId));
  }

  Widget _buildPickerBody(String tabId) {
    if (!_isWindows) {
      return _InfoCard(
        title: 'Unavailable on this platform',
        message: 'WSL is only available on Windows.',
        icon: Icons.info_outline,
      );
    }

    return FutureBuilder<List<WslDistribution>>(
      future: _distrosFuture,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _InfoCard(
            title: 'Failed to load WSL',
            message: snapshot.error.toString(),
            icon: Icons.error_outline,
            action: TextButton(
              onPressed: _refreshDistros,
              child: const Text('Retry'),
            ),
          );
        }
        final distros = snapshot.data ?? const [];
        if (distros.isEmpty) {
          return _InfoCard(
            title: 'No distributions found',
            message:
                'Install a distribution with "wsl --install" or the '
                'Microsoft Store, then refresh.',
            icon: Icons.laptop_mac,
            action: TextButton(
              onPressed: _refreshDistros,
              child: const Text('Refresh'),
            ),
          );
        }
        return Scaffold(
          body: ListView.separated(
            padding: EdgeInsets.all(context.appTheme.spacing.lg),
            itemCount: distros.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final distro = distros[index];
              return ListTile(
                leading: Icon(
                  distro.isDefault ? Icons.star : Icons.lan,
                  color: distro.isDefault
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(distro.name),
                subtitle: Text(
                  'State: ${distro.state} | Version: ${distro.version}',
                ),
                onTap: () => _openTerminal(tabId, distro.name),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _refreshDistros,
            tooltip: 'Refresh',
            child: const Icon(Icons.refresh),
          ),
        );
      },
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _openTerminal(String tabId, String distroName) {
    final newId = 'wsl-$distroName-${_uniqueId()}';
    final sessionController = _terminalSessionBinding.create(
      distroName: distroName,
    );
    final tab = _tabBuilder.terminal(
      id: newId,
      title: distroName,
      label: distroName,
      icon: NerdIcon.penguin.data,
      distroName: distroName,
      sessionController: sessionController,
      onExit: () => _closeTabById(newId),
    );
    _workspaceController.replaceTab(tabId, tab);
  }

  void _closeTabById(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index != -1) _workspaceController.closeTab(index);
  }

  void _handleSettingsChanged() {
    if (!mounted) return;
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
    if (!mounted) return;

    await _workspaceController.restore(
      buildPickerTab: _tabBuilder.picker,
      buildTerminalTab: _tabBuilder.terminal,
      pickerBodyBuilder: _buildPickerBody,
      callbacks: WslTabBuilders(
        terminalIcon: NerdIcon.penguin.data,
        sessionControllerForDistro: (distro) =>
            _terminalSessionBinding.create(distroName: distro),
        closeTab: _closeTabById,
      ),
    );
  }

  void _addPickerTab() {
    _workspaceController.addTab(_distroPickerTab());
  }

  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    final newName = await _uiAdapter.showRenameDialog(initialName: tab.title);
    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == tab.title) return;

    final updated = tab.copyWith(title: trimmed, label: trimmed);
    if (tab.workspaceState is WslTabData) {
      final data = tab.workspaceState as WslTabData;
      final newState = data.persistedState.copyWith(
        title: trimmed,
        label: trimmed,
      );
      final newTabWithState = updated.copyWith(
        workspaceState: WslTabData(kind: data.kind, persistedState: newState),
      );
      _workspaceController.replaceTab(tab.id, newTabWithState);
    } else {
      _workspaceController.replaceTab(tab.id, updated);
    }
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
                onAddTab: _addPickerTab,
                buildChip: (context, index, tab) {
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
                    onRename: tab.canRename ? () => _renameTab(index) : null,
                    dragIndex: tab.canDrag ? index : null,
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
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.appTheme.spacing;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: theme.colorScheme.primary),
                    SizedBox(width: spacing.md),
                    Text(title, style: theme.textTheme.titleMedium),
                  ],
                ),
                SizedBox(height: spacing.md),
                Text(message, style: theme.textTheme.bodyMedium),
                if (action != null) ...[SizedBox(height: spacing.lg), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
