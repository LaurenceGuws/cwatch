import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/docker_context.dart';
import '../../../models/ssh_client_backend.dart';
import '../../../models/ssh_host.dart';
import '../../../services/docker/docker_client_service.dart';
import '../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../services/ssh/remote_command_logging.dart';
import '../../../services/ssh/remote_shell_service.dart';
import '../../../services/settings/app_settings_controller.dart';
import '../../../services/filesystem/explorer_trash_manager.dart';
import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../../../models/docker_workspace_state.dart';
import '../shared/engine_tab.dart';
import '../shared/engine_workspace.dart';
import '../../widgets/action_picker.dart';
import 'widgets/docker_dashboard.dart';
import 'widgets/docker_engine_picker.dart';
import 'widgets/docker_resources_dashboard.dart';
import 'widgets/docker_command_terminal.dart';
import '../shared/tabs/file_explorer_tab.dart';
import '../shared/tabs/remote_file_editor_tab.dart';

class DockerView extends StatefulWidget {
  const DockerView({
    super.key,
    this.leading,
    required this.hostsFuture,
    required this.settingsController,
    required this.builtInVault,
    required this.commandLog,
  });

  final Widget? leading;
  final Future<List<SshHost>> hostsFuture;
  final AppSettingsController settingsController;
  final BuiltInSshVault builtInVault;
  final RemoteCommandLogController commandLog;

  @override
  State<DockerView> createState() => _DockerViewState();
}

class _DockerViewState extends State<DockerView> {
  final DockerClientService _docker = const DockerClientService();
  final ExplorerTrashManager _trashManager = ExplorerTrashManager();
  final List<EngineTab> _tabs = [];
  int _selectedIndex = 0;
  final Map<String, DockerTabState> _tabStates = {};
  String? _lastPersistedSignature;
  bool _pendingWorkspaceSave = false;
  late final VoidCallback _settingsListener;

  Future<List<DockerContext>>? _contextsFuture;
  Future<List<RemoteDockerStatus>>? _remoteStatusFuture;
  bool _remoteScanRequested = false;
  List<RemoteDockerStatus> _cachedReady = const [];

  @override
  void initState() {
    super.initState();
    _contextsFuture = _docker.listContexts();
    final picker = _enginePickerTab();
    _tabs.add(picker);
    _registerTabState(picker.workspaceState as DockerTabState);
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    _loadCachedReady();
    _restoreWorkspace();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    super.dispose();
  }

  EngineTab _enginePickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    final tab = EngineTab(
      id: tabId,
      title: 'Docker Engines',
      label: 'Docker Engines',
      icon: NerdIcon.docker.data,
      canDrag: false,
      isPicker: true,
      workspaceState: DockerTabState(id: tabId, kind: DockerTabKind.picker),
      body: EnginePicker(
        tabId: tabId,
        contextsFuture: _contextsFuture,
        cachedReady: _cachedReady,
        remoteStatusFuture: _remoteStatusFuture,
        remoteScanRequested: _remoteScanRequested,
        onRefreshContexts: _refreshContexts,
        onScanRemotes: _scanRemotes,
        onOpenContext: (contextName, anchor) =>
            _openContextDashboard(tabId, contextName, anchor),
        onOpenHost: (host, anchor) => _openHostDashboard(tabId, host, anchor),
      ),
    );
    _tabStates[tab.id] = DockerTabState(id: tab.id, kind: DockerTabKind.picker);
    return tab;
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _refreshContexts() {
    setState(() {
      _contextsFuture = _docker.listContexts();
      final picker = _enginePickerTab(id: _tabs.first.id);
      _tabs[0] = picker;
      _registerTabState(picker.workspaceState as DockerTabState);
      _persistWorkspace();
    });
  }

  void _scanRemotes() {
    setState(() {
      _remoteScanRequested = true;
      _remoteStatusFuture = _loadRemoteStatuses();
      final picker = _enginePickerTab(id: _tabs.first.id);
      _tabs[0] = picker;
      _registerTabState(picker.workspaceState as DockerTabState);
      _persistWorkspace();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: EngineWorkspace(
        tabs: _tabs,
        selectedIndex: _selectedIndex,
        leading: widget.leading,
        onSelect: (index) {
          setState(() => _selectedIndex = index);
          _persistWorkspace();
        },
        onClose: (index) {
          setState(() {
            _tabStates.remove(_tabs[index].id);
            _tabs.removeAt(index);
            if (_selectedIndex >= _tabs.length) {
              _selectedIndex = _tabs.length - 1;
            } else if (_selectedIndex > index) {
              _selectedIndex -= 1;
            }
          });
          _persistWorkspace();
        },
        onReorder: (oldIndex, newIndex) {
          if (oldIndex == 0 || newIndex == 0) return;
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final moved = _tabs.removeAt(oldIndex);
            _tabs.insert(newIndex, moved);
            if (_selectedIndex == oldIndex) {
              _selectedIndex = newIndex;
            } else if (_selectedIndex >= oldIndex &&
                _selectedIndex < newIndex) {
              _selectedIndex -= 1;
            } else if (_selectedIndex <= oldIndex &&
                _selectedIndex > newIndex) {
              _selectedIndex += 1;
            }
          });
          _persistWorkspace();
        },
        onAddTab: _addEnginePickerTab,
      ),
    );
  }

  void _addEnginePickerTab() {
    setState(() {
      final picker = _enginePickerTab();
      _tabs.add(picker);
      _registerTabState(picker.workspaceState as DockerTabState);
      _selectedIndex = _tabs.length - 1;
    });
    _persistWorkspace();
  }

  Future<void> _openContextDashboard(
    String tabId,
    String contextName,
    Offset? anchor,
  ) async {
    final icons = context.appTheme.icons;
    final choice = await _pickDashboardTarget(
      contextName,
      icons.cloud,
      anchor,
    );
    if (choice == null || !mounted) return;
    _replacePickerWithDashboard(
      tabId: tabId,
      title: contextName,
      id: 'ctx-$contextName',
      icon: icons.cloud,
      body: choice == _DashboardTarget.resources
          ? DockerResourcesDashboard(
              docker: _docker,
              contextName: contextName,
            )
          : DockerDashboard(
              docker: _docker,
              contextName: contextName,
              trashManager: _trashManager,
              builtInVault: widget.builtInVault,
              settingsController: widget.settingsController,
              onOpenTab: _openChildTab,
              onCloseTab: _closeTabById,
            ),
    );
  }

  Future<void> _openHostDashboard(
    String tabId,
    SshHost host,
    Offset? anchor,
  ) async {
    final shell = _shellServiceForHost(host);
    final icons = context.appTheme.icons;
    final choice = await _pickDashboardTarget(
      host.name,
      icons.cloudOutline,
      anchor,
    );
    if (choice == null || !mounted) return;
    _replacePickerWithDashboard(
      tabId: tabId,
      title: host.name,
      id: 'host-${host.name}',
      icon: icons.cloudOutline,
      body: choice == _DashboardTarget.resources
          ? DockerResourcesDashboard(
              docker: _docker,
              remoteHost: host,
              shellService: shell,
            )
          : DockerDashboard(
              docker: _docker,
              remoteHost: host,
              shellService: shell,
              trashManager: _trashManager,
              builtInVault: widget.builtInVault,
              settingsController: widget.settingsController,
              onOpenTab: _openChildTab,
              onCloseTab: _closeTabById,
            ),
    );
  }

  Future<_DashboardTarget?> _pickDashboardTarget(
    String title,
    IconData icon,
    Offset? anchor,
  ) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? MediaQuery.sizeOf(context);
    final anchorPoint = anchor ?? Offset(size.width / 2, size.height / 2);
    return showMenu<_DashboardTarget>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchorPoint.dx,
        anchorPoint.dy,
        anchorPoint.dx,
        anchorPoint.dy,
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

  void _replacePickerWithDashboard({
    required String tabId,
    required String title,
    required String id,
    required IconData icon,
    required Widget body,
  }) {
    final pickerIndex = _tabs.indexWhere((tab) => tab.id == tabId);
    if (pickerIndex == -1) return;
    final uniqueId = _ensureUniqueId(id);
    _tabStates.remove(_tabs[pickerIndex].id);
    final tab = EngineTab(
      id: uniqueId,
      title: title,
      label: title,
      icon: icon,
      body: body,
      canDrag: true,
      isPicker: false,
      workspaceState: _tabStateFromBody(uniqueId, body),
    );
    if (tab.workspaceState is DockerTabState) {
      _registerTabState(tab.workspaceState as DockerTabState);
    }
    _tabs[pickerIndex] = tab;
    setState(() => _selectedIndex = pickerIndex);
    _persistWorkspace();
  }

  Future<void> _loadCachedReady() async {
    try {
      final hosts = await widget.hostsFuture;
      final readyNames = widget.settingsController.settings.dockerRemoteHosts
          .toSet();
      final readyHosts = hosts.where((h) => readyNames.contains(h.name));
      if (!mounted) return;
      setState(() {
        _cachedReady = readyHosts
            .map(
              (host) => RemoteDockerStatus(
                host: host,
                available: true,
                detail: 'Cached ready',
              ),
            )
            .toList();
        _tabs[0] = _enginePickerTab(id: _tabs.first.id);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<List<RemoteDockerStatus>> _loadRemoteStatuses() async {
    List<SshHost> hosts;
    try {
      hosts = await widget.hostsFuture;
    } catch (error) {
      throw Exception('Failed to load SSH hosts: $error');
    }
    if (!mounted || hosts.isEmpty) {
      return const [];
    }
    final results = await Future.wait(
      hosts.map((host) => _probeHost(host)),
      eagerError: false,
    );
    final statuses = results.whereType<RemoteDockerStatus>().toList();
    final readyNames = statuses
        .where((s) => s.available)
        .map((s) => s.host.name)
        .toList();
    await _persistReadyHosts(readyNames);
    if (mounted) {
      setState(() {
        _cachedReady = statuses.where((s) => s.available).toList();
        _tabs[0] = _enginePickerTab(id: _tabs.first.id);
      });
    }
    return statuses;
  }

  Future<RemoteDockerStatus> _probeHost(SshHost host) async {
    final shell = _shellServiceForHost(host);
    const probeCommand =
        "if command -v docker >/dev/null 2>&1; then docker info >/dev/null 2>&1 && echo '__DOCKER_OK__' || echo '__DOCKER_ERROR__'; else echo '__NO_DOCKER__'; fi";
    try {
      final output = await shell.runCommand(
        host,
        probeCommand,
        timeout: const Duration(seconds: 4),
      );
      final trimmed = output.trim();
      if (trimmed.contains('__DOCKER_OK__')) {
        return RemoteDockerStatus(
          host: host,
          available: true,
          detail: 'Ready',
        );
      }
      if (trimmed.contains('__NO_DOCKER__')) {
        return RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker not installed',
        );
      }
      if (trimmed.contains('__DOCKER_ERROR__')) {
        return RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker command failed',
        );
      }
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: trimmed.isEmpty
            ? 'Unknown response'
            : trimmed.split('\n').first,
      );
    } catch (error) {
      return RemoteDockerStatus(
        host: host,
        available: false,
        detail: error.toString(),
      );
    }
  }

  RemoteShellService _shellServiceForHost(SshHost host) {
    final settings = widget.settingsController.settings;
    final observer = settings.debugMode ? widget.commandLog.add : null;
    if (settings.sshClientBackend == SshClientBackend.builtin) {
      return BuiltInRemoteShellService(
        vault: widget.builtInVault,
        hostKeyBindings: settings.builtinSshHostKeyBindings,
        debugMode: settings.debugMode,
        observer: observer,
        promptUnlock: (keyId, hostName, keyLabel) =>
            _promptUnlockKey(keyId, hostName, keyLabel),
      );
    }
    return ProcessRemoteShellService(
      debugMode: settings.debugMode,
      observer: observer,
    );
  }

  Future<void> _persistReadyHosts(List<String> readyNames) async {
    final current = widget.settingsController.settings.dockerRemoteHosts;
    final next = readyNames.toSet().toList()..sort();
    final currentSorted = [...current]..sort();
    if (listEquals(next, currentSorted)) {
      return;
    }
    await widget.settingsController.update(
      (settings) => settings.copyWith(dockerRemoteHosts: next),
    );
  }

  Future<bool> _promptUnlockKey(
    String keyId,
    String hostName,
    String? keyLabel,
  ) async {
    final needsPassword = await widget.builtInVault.needsPassword(keyId);
    if (!needsPassword) {
      try {
        await widget.builtInVault.unlock(keyId, null);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unlocked key for this session.')),
          );
        }
        return true;
      } catch (_) {
        // fall through to prompt
      }
    }
    if (!mounted) return false;

    final controller = TextEditingController();
    String? errorText;
    bool loading = false;
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> attemptUnlock() async {
              if (loading) return;
              final password = controller.text.trim();
              if (password.isEmpty) {
                setState(() => errorText = 'Password is required');
                return;
              }
              setState(() {
                loading = true;
                errorText = null;
              });
              try {
                await widget.builtInVault.unlock(keyId, password);
                if (!mounted || !dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Key unlocked for this session.'),
                  ),
                );
              } on BuiltInSshKeyDecryptException {
                setState(() {
                  errorText = 'Incorrect password. Please try again.';
                  loading = false;
                });
              } catch (e) {
                setState(() {
                  errorText = 'Failed to unlock: $e';
                  loading = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Unlock ${keyLabel ?? 'key'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Host: $hostName'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    enabled: !loading,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : attemptUnlock,
                  child: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return success == true;
  }

  void _openChildTab(EngineTab tab) {
    final uniqueId = _ensureUniqueId(tab.id);
    final uniqueTab = tab.copyWith(id: uniqueId);
    setState(() {
      _tabs.add(uniqueTab);
      _selectedIndex = _tabs.length - 1;
    });
    final state = tab.workspaceState is DockerTabState
        ? (tab.workspaceState as DockerTabState)
        : _tabStateFromBody(uniqueTab.id, uniqueTab.body);
    if (state != null) {
      _registerTabState(_copyStateWithId(state, uniqueId));
    }
    _persistWorkspace();
  }

  void _closeTabById(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index == -1) return;
    setState(() {
      _tabStates.remove(_tabs[index].id);
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _selectedIndex = 0;
      } else if (_selectedIndex >= _tabs.length) {
        _selectedIndex = _tabs.length - 1;
      } else if (_selectedIndex > index) {
        _selectedIndex -= 1;
      }
    });
    _persistWorkspace();
  }

  DockerTabState? _tabStateFromBody(String id, Widget body) {
    if (body is EnginePicker) {
      return DockerTabState(id: id, kind: DockerTabKind.picker);
    }
    if (body is DockerDashboard) {
      if (body.remoteHost != null) {
        return DockerTabState(
          id: id,
          kind: DockerTabKind.hostOverview,
          hostName: body.remoteHost!.name,
        );
      }
      return DockerTabState(
        id: id,
        kind: DockerTabKind.contextOverview,
        contextName: body.contextName,
      );
    }
    if (body is DockerResourcesDashboard) {
      if (body.remoteHost != null) {
        return DockerTabState(
          id: id,
          kind: DockerTabKind.hostResources,
          hostName: body.remoteHost!.name,
        );
      }
      return DockerTabState(
        id: id,
        kind: DockerTabKind.contextResources,
        contextName: body.contextName,
      );
    }
    if (body is DockerCommandTerminal) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.command,
        hostName: body.host?.name,
        command: body.command,
        title: body.title,
      );
    }
    if (body is ComposeLogsTerminal) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.composeLogs,
        hostName: body.host?.name,
        project: body.project,
        services: body.services,
      );
    }
    if (body is FileExplorerTab) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.containerExplorer,
        hostName: body.host.name,
      );
    }
    if (body is RemoteFileEditorTab) {
      return DockerTabState(
        id: id,
        kind: DockerTabKind.containerEditor,
        hostName: body.host.name,
        path: body.path,
      );
    }
    return null;
  }

  void _registerTabState(DockerTabState? state) {
    if (state == null) return;
    _tabStates[state.id] = state;
  }

  DockerWorkspaceState _currentWorkspaceState() {
    final persisted = <DockerTabState>[];
    var selectedPersistedIndex = 0;
    for (var i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      var state = _tabStates[tab.id];
      if (state == null && tab.workspaceState is DockerTabState) {
        state = tab.workspaceState as DockerTabState;
      }
      if (state != null) {
        if (i == _selectedIndex) {
          selectedPersistedIndex = persisted.length;
        }
        persisted.add(state);
      }
    }
    final clampedSelected = persisted.isEmpty
        ? 0
        : selectedPersistedIndex.clamp(0, persisted.length - 1);
    return DockerWorkspaceState(
      tabs: persisted,
      selectedIndex: clampedSelected,
    );
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
    widget.settingsController.update(
      (current) => current.copyWith(dockerWorkspace: workspace),
    );
  }

  void _handleSettingsChanged() {
    if (_pendingWorkspaceSave && widget.settingsController.isLoaded) {
      _persistWorkspace();
    }
  }

  Future<void> _restoreWorkspace() async {
    DockerWorkspaceState? workspace;
    List<SshHost> hosts = const [];
    try {
      hosts = await widget.hostsFuture;
      workspace = widget.settingsController.settings.dockerWorkspace;
    } catch (_) {
      workspace = widget.settingsController.settings.dockerWorkspace;
    }
    if (!mounted) return;

    if (workspace == null || workspace.tabs.isEmpty) {
      setState(() {
        _tabs
          ..clear()
          ..add(_enginePickerTab());
        _tabStates
          ..clear()
          ..addAll({
            _tabs.first.id:
                DockerTabState(id: _tabs.first.id, kind: DockerTabKind.picker),
          });
        _selectedIndex = 0;
      });
      return;
    }

    final newTabs = <EngineTab>[];
    final newStates = <String, DockerTabState>{};
    final usedIds = <String>{};

    for (final state in workspace.tabs) {
      if (usedIds.contains(state.id)) {
        continue;
      }
      final tab = _tabFromState(state, hosts);
      if (tab == null) continue;
      usedIds.add(tab.id);
      newStates[tab.id] = _copyStateWithId(state, tab.id);
      newTabs.add(tab);
    }

    if (newTabs.isEmpty) {
      final picker = _enginePickerTab();
      newTabs.add(picker);
      newStates[picker.id] =
          DockerTabState(id: picker.id, kind: DockerTabKind.picker);
    }

    final selected =
        workspace.selectedIndex.clamp(0, newTabs.length - 1);

    setState(() {
      _tabs
        ..clear()
        ..addAll(newTabs);
      _tabStates
        ..clear()
        ..addAll(newStates);
      _selectedIndex = selected;
      _lastPersistedSignature = workspace!.signature;
    });
  }

  EngineTab? _tabFromState(
    DockerTabState state,
    List<SshHost> hosts,
  ) {
    final icons = context.appTheme.icons;
    switch (state.kind) {
      case DockerTabKind.picker:
        return _enginePickerTab(id: state.id);
      case DockerTabKind.contextOverview:
        if (state.contextName == null) return null;
        return _contextTab(
          id: state.id,
          contextName: state.contextName!,
          resources: false,
        );
      case DockerTabKind.contextResources:
        if (state.contextName == null) return null;
        return _contextTab(
          id: state.id,
          contextName: state.contextName!,
          resources: true,
        );
      case DockerTabKind.hostOverview:
        if (state.hostName == null) return null;
        final host = hosts.firstWhere(
          (h) => h.name == state.hostName,
          orElse: () => const SshHost(
            name: '',
            hostname: '',
            port: 22,
            available: false,
          ),
        );
        if (!host.available || host.name.isEmpty) return null;
        return _hostTab(
          id: state.id,
          host: host,
          resources: false,
        );
      case DockerTabKind.hostResources:
        if (state.hostName == null) return null;
        final host = hosts.firstWhere(
          (h) => h.name == state.hostName,
          orElse: () => const SshHost(
            name: '',
            hostname: '',
            port: 22,
            available: false,
          ),
        );
        if (!host.available || host.name.isEmpty) return null;
        return _hostTab(
          id: state.id,
          host: host,
          resources: true,
        );
      case DockerTabKind.command:
        if (state.command == null || state.title == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? _shellServiceForHost(host) : null;
        return EngineTab(
          id: state.id,
          title: state.title!,
          label: state.title!,
          icon: NerdIcon.terminal.data,
          canDrag: true,
      body: DockerCommandTerminal(
        host: host,
        shellService: shell,
        command: state.command!,
        title: state.title!,
        onExit: () => _closeTabById(state.id),
      ),
      workspaceState: state,
    );
  case DockerTabKind.containerShell:
  case DockerTabKind.containerLogs:
        if (state.command == null || state.title == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? _shellServiceForHost(host) : null;
        return EngineTab(
          id: state.id,
          title: state.title!,
          label: state.title!,
          icon: NerdIcon.terminal.data,
          canDrag: true,
      body: DockerCommandTerminal(
        host: host,
        shellService: shell,
        command: state.command!,
        title: state.title!,
        onExit: () => _closeTabById(state.id),
      ),
      workspaceState: state,
    );
      case DockerTabKind.composeLogs:
        if (state.project == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = host != null ? _shellServiceForHost(host) : null;
        final composeBase =
            state.command ?? 'docker compose -p "${state.project}"';
        return EngineTab(
          id: state.id,
          title: 'Compose logs: ${state.project}',
          label: 'Compose logs: ${state.project}',
          icon: NerdIcon.terminal.data,
          canDrag: true,
      body: ComposeLogsTerminal(
        composeBase: composeBase,
        project: state.project!,
        services: state.services,
        host: host,
        shellService: shell,
        onExit: () => _closeTabById(state.id),
      ),
      workspaceState: state,
    );
      case DockerTabKind.containerExplorer:
        final host = _hostByName(hosts, state.hostName);
        final shell = _containerShell(host, state.containerId);
        if (shell == null) return null;
        final explorerHost = host ??
            const SshHost(
              name: 'local',
              hostname: 'localhost',
              port: 22,
              available: true,
              user: null,
              identityFiles: <String>[],
              source: 'local',
            );
      return EngineTab(
        id: state.id,
        title: 'Explore ${state.containerName ?? state.containerId ?? explorerHost.name}',
        label: 'Explorer',
        icon: icons.folderOpen,
          canDrag: true,
          body: FileExplorerTab(
            host: explorerHost,
            shellService: shell,
            trashManager: _trashManager,
            builtInVault: widget.builtInVault,
            onOpenTrash: () {},
            onOpenEditorTab: (path, content) async {
              final editorTab = EngineTab(
                id: 'editor-${path.hashCode}-${DateTime.now().microsecondsSinceEpoch}',
                title: 'Edit $path',
                label: path,
                icon: icons.edit,
                canDrag: true,
                workspaceState: DockerTabState(
                  id: 'editor-$path',
                  kind: DockerTabKind.containerEditor,
                  hostName: explorerHost.name,
                  containerId: state.containerId,
                  path: path,
                ),
                body: RemoteFileEditorTab(
                  host: explorerHost,
                  shellService: shell,
                  path: path,
                  initialContent: content,
                  onSave: (value) =>
                      shell.writeFile(explorerHost, path, value),
                  settingsController: widget.settingsController,
                ),
              );
              _openChildTab(editorTab);
            },
            onOpenTerminalTab: null,
          ),
          workspaceState: state,
        );
      case DockerTabKind.containerEditor:
        if (state.path == null || state.containerId == null) return null;
        final host = _hostByName(hosts, state.hostName);
        final shell = _containerShell(host, state.containerId);
        if (shell == null) return null;
        final editorHost = host ??
            const SshHost(
              name: 'local',
              hostname: 'localhost',
              port: 22,
              available: true,
              user: null,
              identityFiles: <String>[],
              source: 'local',
            );
        return EngineTab(
        id: state.id,
        title: 'Edit ${state.path}',
        label: state.path ?? 'Editor',
        icon: icons.edit,
          canDrag: true,
          body: DockerEditorLoader(
            host: editorHost,
            shellService: shell,
            path: state.path!,
            settingsController: widget.settingsController,
          ),
          workspaceState: state,
        );
    }
  }

  EngineTab _contextTab({
    required String id,
    required String contextName,
    required bool resources,
  }) {
    final icons = context.appTheme.icons;
    return EngineTab(
      id: id,
      title: contextName,
      label: contextName,
      icon: icons.cloud,
      canDrag: true,
      workspaceState: DockerTabState(
        id: id,
        kind: resources
            ? DockerTabKind.contextResources
            : DockerTabKind.contextOverview,
        contextName: contextName,
      ),
      body: resources
          ? DockerResourcesDashboard(
              docker: _docker,
              contextName: contextName,
              onCloseTab: _closeTabById,
            )
          : DockerDashboard(
              docker: _docker,
              contextName: contextName,
              trashManager: _trashManager,
              builtInVault: widget.builtInVault,
              settingsController: widget.settingsController,
              onOpenTab: _openChildTab,
              onCloseTab: _closeTabById,
            ),
    );
  }

  EngineTab _hostTab({
    required String id,
    required SshHost host,
    required bool resources,
  }) {
    final shell = _shellServiceForHost(host);
    final icons = context.appTheme.icons;
    return EngineTab(
      id: id,
      title: host.name,
      label: host.name,
      icon: icons.cloudOutline,
      canDrag: true,
      workspaceState: DockerTabState(
        id: id,
        kind: resources
            ? DockerTabKind.hostResources
            : DockerTabKind.hostOverview,
        hostName: host.name,
      ),
      body: resources
          ? DockerResourcesDashboard(
              docker: _docker,
              remoteHost: host,
              shellService: shell,
              onCloseTab: _closeTabById,
            )
          : DockerDashboard(
              docker: _docker,
              remoteHost: host,
              shellService: shell,
              trashManager: _trashManager,
              builtInVault: widget.builtInVault,
              settingsController: widget.settingsController,
              onOpenTab: _openChildTab,
              onCloseTab: _closeTabById,
            ),
    );
  }

  DockerTabState _copyStateWithId(DockerTabState state, String id) {
    return DockerTabState(
      id: id,
      kind: state.kind,
      contextName: state.contextName,
      hostName: state.hostName,
      containerId: state.containerId,
      containerName: state.containerName,
      command: state.command,
      title: state.title,
      path: state.path,
      project: state.project,
      services: state.services,
    );
  }

  String _ensureUniqueId(String base) {
    var candidate = base;
    var counter = 1;
    final existing = _tabs.map((t) => t.id).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-${counter++}';
    }
    return candidate;
  }

  SshHost? _hostByName(List<SshHost> hosts, String? name) {
    if (name == null) return null;
    try {
      return hosts.firstWhere((h) => h.name == name);
    } catch (_) {
      return null;
    }
  }

  RemoteShellService? _containerShell(SshHost? host, String? containerId) {
    final id = containerId ?? '';
    if (host == null || host.name == 'local') {
      return LocalDockerContainerShellService(containerId: id);
    }
    return DockerContainerShellService(
      host: host,
      containerId: id,
      baseShell: _shellServiceForHost(host),
    );
  }
}

enum _DashboardTarget { overview, resources }

class DockerEditorLoader extends StatefulWidget {
  const DockerEditorLoader({
    super.key,
    required this.host,
    required this.shellService,
    required this.path,
    required this.settingsController,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final AppSettingsController settingsController;

  @override
  State<DockerEditorLoader> createState() => _DockerEditorLoaderState();
}

class _DockerEditorLoaderState extends State<DockerEditorLoader> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = widget.shellService.readFile(widget.host, widget.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load file: ${snapshot.error}'));
        }
        final content = snapshot.data ?? '';
        return RemoteFileEditorTab(
          host: widget.host,
          shellService: widget.shellService,
          path: widget.path,
          initialContent: content,
          onSave: (value) =>
              widget.shellService.writeFile(widget.host, widget.path, value),
          settingsController: widget.settingsController,
        );
      },
    );
  }
}
