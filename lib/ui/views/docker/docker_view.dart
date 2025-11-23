import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/docker_container.dart';
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
  Future<List<_RemoteDockerStatus>>? _remoteStatusFuture;
  bool _remoteScanRequested = false;
  List<_RemoteDockerStatus> _cachedReady = const [];

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
      body: _EnginePicker(
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
      body: _DashboardView(docker: _docker, contextName: contextName),
    );
  }

  void _openHostDashboard(String tabId, SshHost host) {
    final shell = _shellServiceForHost(host);
    _replacePickerWithDashboard(
      tabId: tabId,
      title: host.name,
      id: 'host-${host.name}',
      icon: Icons.cloud_outlined,
      body: _DashboardView(
        docker: _docker,
        remoteHost: host,
        shellService: shell,
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
    _tabs[pickerIndex] = EngineTab(
      id: id,
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
              (host) => _RemoteDockerStatus(
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

  Future<List<_RemoteDockerStatus>> _loadRemoteStatuses() async {
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
    final statuses = results.whereType<_RemoteDockerStatus>().toList();
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

  Future<_RemoteDockerStatus> _probeHost(SshHost host) async {
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
        return _RemoteDockerStatus(
          host: host,
          available: true,
          detail: 'Ready',
        );
      }
      if (trimmed.contains('__NO_DOCKER__')) {
        return _RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker not installed',
        );
      }
      if (trimmed.contains('__DOCKER_ERROR__')) {
        return _RemoteDockerStatus(
          host: host,
          available: false,
          detail: 'Docker command failed',
        );
      }
      return _RemoteDockerStatus(
        host: host,
        available: false,
        detail: trimmed.isEmpty
            ? 'Unknown response'
            : trimmed.split('\n').first,
      );
    } catch (error) {
      return _RemoteDockerStatus(
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

}

class _EnginePicker extends StatelessWidget {
  const _EnginePicker({
    required this.tabId,
    required this.contextsFuture,
    required this.cachedReady,
    required this.remoteStatusFuture,
    required this.remoteScanRequested,
    required this.onRefreshContexts,
    required this.onScanRemotes,
    required this.onOpenContext,
    required this.onOpenHost,
  });

  final String tabId;
  final Future<List<DockerContext>>? contextsFuture;
  final List<_RemoteDockerStatus> cachedReady;
  final Future<List<_RemoteDockerStatus>>? remoteStatusFuture;
  final bool remoteScanRequested;
  final VoidCallback onRefreshContexts;
  final VoidCallback onScanRemotes;
  final void Function(String contextName) onOpenContext;
  final void Function(SshHost host) onOpenHost;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        FutureBuilder<List<DockerContext>>(
          future: contextsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _ErrorCard(
                message: snapshot.error.toString(),
                onRetry: onRefreshContexts,
              );
            }
            final contexts = snapshot.data ?? const <DockerContext>[];
            if (contexts.isEmpty) {
              return _EmptyState(onRefresh: onRefreshContexts);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: Text(
                    'Local contexts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: contexts
                      .map(
                        (ctx) => _EngineButton(
                          label: ctx.name,
                          selected: false,
                          onDoubleTap: () => onOpenContext(ctx.name),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _RemoteSection(
          remoteStatusFuture: remoteStatusFuture,
          scanRequested: remoteScanRequested,
          cachedReady: cachedReady,
          onScan: onScanRemotes,
          onOpenHost: onOpenHost,
        ),
      ],
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView({
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  Future<List<DockerContainer>>? _containers;

  @override
  void initState() {
    super.initState();
    _containers = _load();
  }

  Future<List<DockerContainer>> _load() {
    if (widget.remoteHost != null && widget.shellService != null) {
      return _loadRemote(widget.shellService!, widget.remoteHost!);
    }
    return widget.docker.listContainers(
      context: widget.contextName,
      dockerHost: null,
    );
  }

  Future<List<DockerContainer>> _loadRemote(
    RemoteShellService shell,
    SshHost host,
  ) async {
    final output = await shell.runCommand(
      host,
      "docker ps -a --format '{{json .}}'",
      timeout: const Duration(seconds: 8),
    );
    return _parseContainers(output);
  }

  List<DockerContainer> _parseContainers(String output) {
    final items = <DockerContainer>[];
    for (final line in const LineSplitter().convert(output)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          items.add(DockerContainer(
            id: (decoded['ID'] as String?)?.trim() ?? '',
            name: (decoded['Names'] as String?)?.trim() ?? '',
            image: (decoded['Image'] as String?)?.trim() ?? '',
            state: (decoded['State'] as String?)?.trim() ?? '',
            status: (decoded['Status'] as String?)?.trim() ?? '',
            ports: (decoded['Ports'] as String?)?.trim() ?? '',
            command: (decoded['Command'] as String?)?.trim(),
            createdAt: (decoded['RunningFor'] as String?)?.trim(),
          ));
        }
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  void _refresh() {
    setState(() {
      _containers = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.contextName ?? widget.remoteHost?.name ?? 'Dashboard';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<DockerContainer>>(
              future: _containers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorCard(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final containers = snapshot.data ?? const <DockerContainer>[];
                if (containers.isEmpty) {
                  return const Center(child: Text('No containers found.'));
                }
                final running = containers.where((c) => c.isRunning).length;
                final stopped = containers.length - running;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatCard(
                          label: 'Total',
                          value: containers.length.toString(),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Running',
                          value: running.toString(),
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _StatCard(
                          label: 'Stopped',
                          value: stopped.toString(),
                          color: Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: containers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final container = containers[index];
                          final color = container.isRunning
                              ? Colors.green
                              : Colors.orange;
                          final statusLabel = container.isRunning
                              ? 'Running'
                              : 'Stopped (${container.status})';
                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.dns, color: color),
                              title: Text(
                                container.name.isNotEmpty
                                    ? container.name
                                    : container.id,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Image: ${container.image}'),
                                  Text(statusLabel),
                                  if (container.ports.isNotEmpty)
                                    Text('Ports: ${container.ports}'),
                                ],
                              ),
                              trailing: Text(
                                container.state,
                                style: TextStyle(color: color),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineButton extends StatelessWidget {
  const _EngineButton({
    required this.label,
    required this.selected,
    required this.onDoubleTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.1)
        : scheme.surfaceContainerHighest;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onDoubleTap: onDoubleTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? scheme.primary : null,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteDockerStatus {
  const _RemoteDockerStatus({
    required this.host,
    required this.available,
    required this.detail,
  });

  final SshHost host;
  final bool available;
  final String detail;
}

class _RemoteSection extends StatelessWidget {
  const _RemoteSection({
    required this.remoteStatusFuture,
    required this.scanRequested,
    required this.cachedReady,
    required this.onScan,
    required this.onOpenHost,
  });

  final Future<List<_RemoteDockerStatus>>? remoteStatusFuture;
  final bool scanRequested;
  final List<_RemoteDockerStatus> cachedReady;
  final VoidCallback onScan;
  final ValueChanged<SshHost> onOpenHost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text('Servers', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.search),
                label: const Text('Scan'),
              ),
            ],
          ),
        ),
        if (!scanRequested)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: cachedReady.isEmpty
                ? const Text(
                    'Scan to check which servers have Docker available.',
                  )
                : _RemoteHostList(hosts: cachedReady, onOpenHost: onOpenHost),
          )
        else
          FutureBuilder<List<_RemoteDockerStatus>>(
            future: remoteStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return _ErrorCard(
                  message: snapshot.error.toString(),
                  onRetry: onScan,
                );
              }
              final statuses = snapshot.data ?? const <_RemoteDockerStatus>[];
              final available = statuses.where((s) => s.available).toList();
              if (available.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text('No Docker-ready remote hosts found.'),
                );
              }
              return _RemoteHostList(hosts: available, onOpenHost: onOpenHost);
            },
          ),
      ],
    );
  }
}

class _RemoteHostList extends StatelessWidget {
  const _RemoteHostList({required this.hosts, required this.onOpenHost});

  final List<_RemoteDockerStatus> hosts;
  final ValueChanged<SshHost> onOpenHost;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hosts
          .map(
            (status) => _EngineButton(
              label: status.host.name,
              selected: false,
              subtitle: status.detail,
              onDoubleTap: () => onOpenHost(status.host),
            ),
          )
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 64),
          const SizedBox(height: 12),
          const Text('No Docker contexts found.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
