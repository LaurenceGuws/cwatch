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
import '../../theme/nerd_fonts.dart';
import '../shared/engine_tab.dart';
import '../shared/engine_workspace.dart';
import 'widgets/docker_dashboard.dart';
import 'widgets/docker_engine_picker.dart';

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
  final List<EngineTab> _tabs = [];
  int _selectedIndex = 0;

  Future<List<DockerContext>>? _contextsFuture;
  Future<List<RemoteDockerStatus>>? _remoteStatusFuture;
  bool _remoteScanRequested = false;
  List<RemoteDockerStatus> _cachedReady = const [];

  @override
  void initState() {
    super.initState();
    _contextsFuture = _docker.listContexts();
    _tabs.add(_enginePickerTab());
    _loadCachedReady();
  }

  EngineTab _enginePickerTab({String? id}) {
    final tabId = id ?? _uniqueId();
    return EngineTab(
      id: tabId,
      title: 'Docker Engines',
      label: 'Docker Engines',
      icon: NerdIcon.docker.data,
      canDrag: false,
      isPicker: true,
      body: EnginePicker(
        tabId: tabId,
        contextsFuture: _contextsFuture,
        cachedReady: _cachedReady,
        remoteStatusFuture: _remoteStatusFuture,
        remoteScanRequested: _remoteScanRequested,
        onRefreshContexts: _refreshContexts,
        onScanRemotes: _scanRemotes,
        onOpenContext: (contextName) =>
            _openContextDashboard(tabId, contextName),
        onOpenHost: (host) => _openHostDashboard(tabId, host),
      ),
    );
  }

  String _uniqueId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _refreshContexts() {
    setState(() {
      _contextsFuture = _docker.listContexts();
      _tabs[0] = _enginePickerTab(id: _tabs.first.id);
    });
  }

  void _scanRemotes() {
    setState(() {
      _remoteScanRequested = true;
      _remoteStatusFuture = _loadRemoteStatuses();
      _tabs[0] = _enginePickerTab(id: _tabs.first.id);
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
        onSelect: (index) => setState(() => _selectedIndex = index),
        onClose: (index) {
          setState(() {
            _tabs.removeAt(index);
            if (_selectedIndex >= _tabs.length) {
              _selectedIndex = _tabs.length - 1;
            } else if (_selectedIndex > index) {
              _selectedIndex -= 1;
            }
          });
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
        },
        onAddTab: _addEnginePickerTab,
      ),
    );
  }

  void _addEnginePickerTab() {
    setState(() {
      _tabs.add(_enginePickerTab());
      _selectedIndex = _tabs.length - 1;
    });
  }

  void _openContextDashboard(String tabId, String contextName) {
    _replacePickerWithDashboard(
      tabId: tabId,
      title: contextName,
      id: 'ctx-$contextName',
      icon: Icons.cloud,
      body: DockerDashboard(
        docker: _docker,
        contextName: contextName,
        onOpenTab: _openChildTab,
      ),
    );
  }

  void _openHostDashboard(String tabId, SshHost host) {
    final shell = _shellServiceForHost(host);
    _replacePickerWithDashboard(
      tabId: tabId,
      title: host.name,
      id: 'host-${host.name}',
      icon: Icons.cloud_outlined,
      body: DockerDashboard(
        docker: _docker,
        remoteHost: host,
        shellService: shell,
        onOpenTab: _openChildTab,
      ),
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
    _tabs[pickerIndex] = EngineTab(
      id: uniqueId,
      title: title,
      label: title,
      icon: icon,
      body: body,
      canDrag: true,
      isPicker: false,
    );
    setState(() => _selectedIndex = pickerIndex);
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
    final uniqueTab = tab.copyWith(id: _ensureUniqueId(tab.id));
    setState(() {
      _tabs.add(uniqueTab);
      _selectedIndex = _tabs.length - 1;
    });
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
}
