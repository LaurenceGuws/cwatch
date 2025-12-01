import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';

import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_image.dart';
import 'package:cwatch/models/docker_network.dart';
import 'package:cwatch/models/docker_volume.dart';
import 'package:cwatch/models/docker_workspace_state.dart';
import 'package:cwatch/models/explorer_context.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/modules/docker/services/docker_engine_service.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import '../engine_tab.dart';
import '../docker_tab_factory.dart';
import 'docker_command_terminal.dart';
import '../../services/docker_container_shell_service.dart';
import 'docker_lists.dart';
import 'docker_shared.dart';
import 'section_card.dart';

typedef OpenTab = void Function(EngineTab tab);

class DockerOverview extends StatefulWidget {
  const DockerOverview({
    super.key,
    required this.docker,
    this.contextName,
    this.remoteHost,
    this.shellService,
    required this.trashManager,
    required this.keyService,
    required this.settingsController,
    this.onOpenTab,
    this.onCloseTab,
    this.optionsController,
    required this.tabFactory,
  });

  final DockerClientService docker;
  final String? contextName;
  final SshHost? remoteHost;
  final RemoteShellService? shellService;
  final ExplorerTrashManager trashManager;
  final BuiltInSshKeyService keyService;
  final AppSettingsController settingsController;
  final OpenTab? onOpenTab;
  final void Function(String tabId)? onCloseTab;
  final TabOptionsController? optionsController;
  final DockerTabFactory tabFactory;

  @override
  State<DockerOverview> createState() => _DockerOverviewState();
}

class _DockerOverviewState extends State<DockerOverview> {
  late final DockerEngineService _engineService;
  Future<EngineSnapshot>? _snapshot;
  final Set<String> _selectedContainerIds = {};
  final Set<String> _selectedImageKeys = {};
  final Set<String> _selectedNetworkKeys = {};
  final Set<String> _selectedVolumeKeys = {};
  int? _focusedContainerIndex;
  int? _containerAnchorIndex;
  final FocusNode _containerFocus = FocusNode(debugLabel: 'docker-containers');
  final Map<String, String> _containerActionInProgress = {};
  bool _containersHydrated = false;
  List<DockerContainer> _cachedContainers = const [];
  AppIcons get _icons => context.appTheme.icons;
  AppDockerTokens get _dockerTheme => context.appTheme.docker;
  bool _tabOptionsRegistered = false;

  @override
  void initState() {
    super.initState();
    _engineService = DockerEngineService(docker: widget.docker);
    _snapshot = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerTabOptions();
  }

  void _registerTabOptions() {
    if (_tabOptionsRegistered || widget.optionsController == null) {
      return;
    }
    _tabOptionsRegistered = true;
    final icons = _icons;
    final scheme = Theme.of(context).colorScheme;
    final options = [
      TabChipOption(label: 'Reload', icon: icons.refresh, onSelected: _refresh),
      TabChipOption(
        label: 'System prune',
        icon: Icons.cleaning_services_outlined,
        color: scheme.error,
        onSelected: () => _runPrune(includeVolumes: false),
      ),
      TabChipOption(
        label: 'Prune incl. volumes',
        icon: Icons.delete_sweep_outlined,
        color: scheme.error,
        onSelected: () => _runPrune(includeVolumes: true),
      ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.optionsController?.update(options);
    });
  }

  @override
  void dispose() {
    _containerFocus.dispose();
    super.dispose();
  }

  Future<EngineSnapshot> _load() async {
    return _engineService.fetch(
      contextName: widget.contextName,
      remoteHost: widget.remoteHost,
      shell: widget.shellService,
    );
  }

  void _refresh() {
    setState(() {
      _containersHydrated = false;
      _snapshot = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dockerTheme = _dockerTheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<EngineSnapshot>(
              future: _snapshot,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorCard(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: Text('No data.'));
                }
                if (!_containersHydrated) {
                  _cachedContainers = data.containers;
                  _containersHydrated = true;
                }
                final containers = _cachedContainers;
                final images = data.images;
                final networks = data.networks;
                final volumes = data.volumes;
                final running = containers.where((c) => c.isRunning).length;
                final stopped = containers.length - running;
                final total = containers.length;
                final statsCards = [
                  StatCard(
                    label: 'Containers',
                    value: total.toString(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  StatCard(
                    label: 'Running',
                    value: running.toString(),
                    color: dockerTheme.running,
                  ),
                  StatCard(
                    label: 'Stopped',
                    value: stopped.toString(),
                    color: dockerTheme.stopped,
                  ),
                  StatCard(
                    label: 'Images',
                    value: images.length.toString(),
                    color: dockerTheme.images,
                  ),
                  StatCard(
                    label: 'Networks',
                    value: networks.length.toString(),
                    color: dockerTheme.networks,
                  ),
                  StatCard(
                    label: 'Volumes',
                    value: volumes.length.toString(),
                    color: dockerTheme.volumes,
                  ),
                ];

                if (containers.isEmpty &&
                    images.isEmpty &&
                    networks.isEmpty &&
                    volumes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No containers, images, networks, or volumes found.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: statsCards),
                    const SizedBox(height: 12),
                    Focus(
                      focusNode: _containerFocus,
                      onKeyEvent: _handleContainerKey,
                      child: SectionCard(
                        title: 'Containers',
                        child: ContainerPeek(
                          containers: containers,
                          onTapDown: _handleContainerTapDown,
                          selectedIds: _selectedContainerIds,
                          busyIds: _containerActionInProgress.keys.toSet(),
                          actionLabels: _containerActionInProgress,
                          onComposeAction: _handleComposeAction,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Images',
                      child: ImagePeek(
                        images: images,
                        onTapDown: _handleImageTapDown,
                        selectedIds: _selectedImageKeys,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Networks',
                      child: NetworkList(
                        networks: networks,
                        onTapDown: _handleNetworkTapDown,
                        selectedIds: _selectedNetworkKeys,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Volumes',
                      child: VolumeList(
                        volumes: volumes,
                        onTapDown: _handleVolumeTapDown,
                        selectedIds: _selectedVolumeKeys,
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

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.primary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: resolved),
          const SizedBox(width: 8),
          Text(label, style: color != null ? TextStyle(color: color) : null),
        ],
      ),
    );
  }

  void _openContainerMenu(DockerContainer container, TapDownDetails details) {
    final scheme = Theme.of(context).colorScheme;
    final extraActions = <PopupMenuEntry<String>>[
      _menuItem('logs', 'Tail logs', Icons.list_alt_outlined),
      _menuItem('shell', 'Open shell tab', NerdIcon.terminal.data),
      _menuItem('copyExec', 'Copy exec command', _icons.copy),
      _menuItem('explore', 'Open explorer', _icons.folderOpen),
      _menuItem('start', 'Start', Icons.play_arrow_rounded),
      _menuItem('stop', 'Stop', Icons.stop_rounded),
      _menuItem('restart', 'Restart', _icons.refresh),
      const PopupMenuDivider(),
      _menuItem('remove', 'Remove', Icons.delete_outline, color: scheme.error),
    ];
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: container.name.isNotEmpty ? container.name : container.id,
      details: {
        'Image': container.image,
        'Status': container.status,
        'Ports': container.ports,
      },
      copyValue: container.id,
      copyLabel: 'Container ID',
      extraActions: extraActions,
      onAction: (action) async {
        if (action == 'logs') {
          await _openLogsTab(container);
        } else if (action == 'shell') {
          await _openExecTerminal(container);
        } else if (action == 'copyExec') {
          await _copyExecCommand(container.id);
        } else if (action == 'explore') {
          await _openContainerExplorer(container);
        } else if (action == 'start') {
          await _runContainerAction(container, 'start');
        } else if (action == 'stop') {
          await _runContainerAction(container, 'stop');
        } else if (action == 'restart') {
          await _runContainerAction(container, 'restart');
        } else if (action == 'remove') {
          await _runContainerAction(container, 'remove');
        }
      },
    );
  }

  Future<void> _handleComposeAction(String project, String action) async {
    switch (action) {
      case 'logs':
        await _openComposeLogsTab(project);
        break;
      case 'restart':
        await _runComposeCommand(project, 'restart');
        break;
      case 'up':
        await _runComposeCommand(project, 'up');
        break;
      case 'down':
        await _runComposeCommand(project, 'down');
        break;
    }
  }

  Future<void> _runComposeCommand(String project, String action) async {
    _markProjectBusy(project, action);
    final args = <String>[];
    switch (action) {
      case 'up':
        args.addAll(['up', '-d']);
        break;
      case 'down':
        args.add('down');
        break;
      case 'restart':
        args.add('restart');
        break;
      default:
        return;
    }
    if (widget.remoteHost != null && widget.shellService != null) {
      final cmd = '${_composeBaseCommand(project)} ${args.join(' ')}';
      await widget.shellService!.runCommand(
        widget.remoteHost!,
        cmd,
        timeout: const Duration(seconds: 20),
      );
    } else {
      await widget.docker.processRunner(
        'bash',
        ['-lc', '${_composeBaseCommand(project)} ${args.join(' ')}'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compose $action executed for $project.')),
    );
    await _syncProjectContainers(project);
    if (mounted) {
      setState(() {
        for (final id in _projectContainerIds(project)) {
          _containerActionInProgress.remove(id);
        }
      });
    }
  }

  void _markProjectBusy(String project, String action) {
    setState(() {
      for (final c in _cachedContainers) {
        if (c.composeProject == project) {
          _containerActionInProgress[c.id] = 'compose $action';
        }
      }
    });
  }

  void _openImageMenu(DockerImage image, TapDownDetails details) {
    final ref = [
      image.repository.isNotEmpty ? image.repository : '<none>',
      image.tag.isNotEmpty ? image.tag : '<none>',
    ].join(':');
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: ref,
      details: {'ID': image.id, 'Size': image.size},
      copyValue: image.id,
      copyLabel: 'Image ID',
    );
  }

  void _openNetworkMenu(DockerNetwork network, TapDownDetails details) {
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: network.name,
      details: {'Driver': network.driver, 'Scope': network.scope},
      copyValue: network.id,
      copyLabel: 'Network ID',
    );
  }

  void _openVolumeMenu(DockerVolume volume, TapDownDetails details) {
    _showItemMenu(
      globalPosition: details.globalPosition,
      title: volume.name,
      details: {
        'Driver': volume.driver,
        'Mountpoint': volume.mountpoint ?? '—',
        'Scope': volume.scope ?? '—',
      },
      copyValue: volume.name,
      copyLabel: 'Volume name',
    );
  }

  Future<void> _showItemMenu({
    required Offset globalPosition,
    required String title,
    required Map<String, String> details,
    required String copyValue,
    required String copyLabel,
    List<PopupMenuEntry<String>> extraActions = const [],
    Future<void> Function(String action)? onAction,
  }) async {
    if (!mounted) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        _menuItem('copy', 'Copy $copyLabel', _icons.copy),
        _menuItem('details', 'Details', Icons.info_outline),
        ...extraActions,
      ],
    );

    if (selected == 'copy') {
      await _copyToClipboard(copyValue, copyLabel);
    } else if (selected == 'details') {
      await _showDetailsDialog(title: title, details: details);
    } else if (selected != null && onAction != null) {
      await onAction(selected);
    }
  }

  Future<void> _showDetailsDialog({
    required String title,
    required Map<String, String> details,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: Text(entry.value)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard.')));
  }

  Future<void> _openLogsTab(DockerContainer container) async {
    final name = container.name.isNotEmpty ? container.name : container.id;
    final baseCommand = _logsBaseCommand(container.id);
    final tailCommand = _autoCloseCommand(_followLogsCommand(container.id));

    if (widget.onOpenTab != null) {
      final tabId =
          'logs-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
      final tab = widget.tabFactory.commandTerminal(
        id: tabId,
        title: 'Logs • $name',
        label: 'Logs: $name',
        command: tailCommand,
        icon: NerdIcon.terminal.data,
        host: widget.remoteHost,
        shellService: widget.shellService,
        kind: DockerTabKind.containerLogs,
        containerId: container.id,
        containerName: name,
        contextName: widget.contextName,
        onExit: () => widget.onCloseTab?.call(tabId),
      );
      widget.onOpenTab!(tab);
      return;
    }

    // Fallback to simple dialog if tabs cannot be opened.
    await _showLogsDialog(container, baseCommand);
  }

  Future<void> _openComposeLogsTab(String project) async {
    final base = _composeBaseCommand(project);
    final services = _composeServices(project);
    if (widget.onOpenTab != null) {
      final tabId = 'clogs-$project-${DateTime.now().microsecondsSinceEpoch}';
      final tab = widget.tabFactory.composeLogs(
        id: tabId,
        title: 'Compose logs: $project',
        label: 'Compose logs: $project',
        icon: NerdIcon.terminal.data,
        composeBase: base,
        project: project,
        services: services,
        host: widget.remoteHost,
        shellService: widget.shellService,
        onExit: () => widget.onCloseTab?.call(tabId),
      );
      widget.onOpenTab!(tab);
      return;
    }
    await _showLogsDialog(
      DockerContainer(
        id: project,
        name: 'Compose $project',
        image: '',
        state: '',
        status: '',
        ports: '',
      ),
      '$base logs --tail 200',
    );
  }

  String _logsBaseCommand(String containerId) {
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    return 'docker ${contextFlag}logs $containerId';
  }

  String _composeBaseCommand(String project) {
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    return 'docker ${contextFlag}compose -p "$project"';
  }

  String _followLogsCommand(String containerId) {
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    // Reattach after restarts; only the first attach pulls the last 200 lines.
    return '''
bash -lc '
trap "exit 130" INT
tail_arg="--tail 200"
since=""
while true; do
  docker ${contextFlag}logs --follow \$tail_arg \$since "$containerId"
  exit_code=\$?
  if [ \$exit_code -eq 130 ]; then
    exit 130
  fi
  tail_arg="--tail 0"
  since="--since=\$(date -Iseconds)"
  echo "[logs] stream ended; waiting to reattach..."
  sleep 1
done'
''';
  }

  String _autoCloseCommand(String command) {
    final trimmed = command.trimRight();
    if (trimmed.endsWith('exit') || trimmed.endsWith('exit;')) {
      return command;
    }
    return '$trimmed; exit';
  }

  Future<void> _showLogsDialog(
    DockerContainer container,
    String command,
  ) async {
    if (!mounted) return;
    try {
      final logs = await _loadLogsSnapshot(command);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Logs: ${container.name.isNotEmpty ? container.name : container.id}',
            ),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: SelectableText(
                  logs.isNotEmpty ? logs : 'No logs available.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed to load logs'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<String> _loadLogsSnapshot(String command) async {
    if (widget.remoteHost != null && widget.shellService != null) {
      return widget.shellService!.runCommand(
        widget.remoteHost!,
        '$command --tail 200',
        timeout: const Duration(seconds: 8),
      );
    }

    final result = await widget.docker.processRunner(
      'bash',
      ['-lc', '$command --tail 200'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String?)?.trim();
      throw Exception(
        stderr?.isNotEmpty == true
            ? stderr
            : 'docker logs failed with exit code ${result.exitCode}',
      );
    }
    return (result.stdout as String?) ?? '';
  }

  Future<void> _copyExecCommand(String containerId) async {
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    final command =
        'docker ${contextFlag}exec -it $containerId /bin/sh # change to /bin/bash if needed';
    await _copyToClipboard(command, 'Exec command');
  }

  Future<void> _openExecTerminal(DockerContainer container) async {
    if (widget.remoteHost == null || widget.shellService == null) {
      final name = container.name.isNotEmpty ? container.name : container.id;
      final contextFlag =
          widget.contextName != null && widget.contextName!.isNotEmpty
          ? '--context ${widget.contextName!} '
          : '';
      final command = _autoCloseCommand(
        'docker ${contextFlag}exec -it ${container.id} /bin/sh',
      );
      if (widget.onOpenTab != null) {
        final tabId =
            'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
        final tab = EngineTab(
          id: tabId,
          title: 'Shell: $name',
          label: 'Shell: $name',
          icon: NerdIcon.terminal.data,
          body: DockerCommandTerminal(
            host: null,
            shellService: null,
            command: command,
            title: 'Exec shell • $name',
            onExit: () => widget.onCloseTab?.call(tabId),
          ),
          canDrag: true,
        );
        widget.onOpenTab!(tab);
      } else {
        await _copyExecCommand(container.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No remote host available. Exec command copied.'),
          ),
        );
      }
      return;
    }
    final name = container.name.isNotEmpty ? container.name : container.id;
    // Keep the container shell session alive; user will exit manually.
    final contextFlag =
        widget.contextName != null && widget.contextName!.isNotEmpty
        ? '--context ${widget.contextName!} '
        : '';
    final command = _autoCloseCommand(
      'docker ${contextFlag}exec -it ${container.id} /bin/sh',
    );
    if (widget.onOpenTab != null) {
      final tabId =
          'exec-${container.id}-${DateTime.now().microsecondsSinceEpoch}';
      final tab = EngineTab(
        id: tabId,
        title: 'Shell: $name',
        label: 'Shell: $name',
        icon: NerdIcon.terminal.data,
        body: DockerCommandTerminal(
          host: widget.remoteHost!,
          shellService: widget.shellService!,
          command: command,
          title: 'Exec shell • $name',
          onExit: () => widget.onCloseTab?.call(tabId),
        ),
        canDrag: true,
        workspaceState: DockerTabState(
          id: 'exec-${container.id}',
          kind: DockerTabKind.containerShell,
          hostName: widget.remoteHost!.name,
          containerId: container.id,
          containerName: name,
          command: command,
          title: 'Exec shell • $name',
        ),
      );
      widget.onOpenTab!(tab);
    } else {
      await _copyExecCommand(container.id);
    }
  }

  Future<void> _openContainerExplorer(DockerContainer container) async {
    if (widget.onOpenTab == null) return;
    final isRemote = widget.remoteHost != null && widget.shellService != null;
    final shell = isRemote
        ? DockerContainerShellService(
            host: widget.remoteHost!,
            containerId: container.id,
            baseShell: widget.shellService!,
          )
        : LocalDockerContainerShellService(
            containerId: container.id,
            contextName: widget.contextName,
          );
    final host =
        widget.remoteHost ??
        const SshHost(
          name: 'local',
          hostname: 'localhost',
          port: 22,
          available: true,
          user: null,
          identityFiles: <String>[],
          source: 'local',
        );
    final explorerContext = ExplorerContext.dockerContainer(
      host: host,
      containerId: container.id,
      containerName: container.name,
      dockerContextName: _dockerContextName(host),
    );
    final tab = widget.tabFactory.explorer(
      id: 'explore-${container.id}-${DateTime.now().microsecondsSinceEpoch}',
      title:
          'Explore ${container.name.isNotEmpty ? container.name : container.id}',
      label: 'Explorer',
      icon: _icons.folderOpen,
      host: host,
      shellService: shell,
      explorerContext: explorerContext,
      containerId: container.id,
      containerName: container.name,
      dockerContextName: _dockerContextName(host),
      onOpenTab: widget.onOpenTab!,
    );
    widget.onOpenTab!(tab);
  }

  String _dockerContextName(SshHost host) {
    final trimmedContext = widget.contextName?.trim();
    if (trimmedContext?.isNotEmpty == true) {
      return trimmedContext!;
    }
    return '${host.name}-docker';
  }

  void _handleContainerTapDown(
    DockerContainer container,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
  }) {
    final key = container.id;
    _updateSelection(
      _selectedContainerIds,
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
      index: flatIndex,
      total: _currentContainers.length,
    );
    if (flatIndex != null) {
      _focusedContainerIndex = flatIndex;
      _containerAnchorIndex ??= flatIndex;
    }
    if (secondary) {
      _openContainerMenu(container, details);
    }
  }

  void _handleImageTapDown(
    DockerImage image,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
  }) {
    final key = _imageKey(image);
    _updateSelection(
      _selectedImageKeys,
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
    );
    if (secondary) {
      _openImageMenu(image, details);
    }
  }

  void _handleNetworkTapDown(
    DockerNetwork network,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
  }) {
    final key = network.id.isNotEmpty ? network.id : network.name;
    _updateSelection(
      _selectedNetworkKeys,
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
    );
    if (secondary) {
      _openNetworkMenu(network, details);
    }
  }

  void _handleVolumeTapDown(
    DockerVolume volume,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
  }) {
    final key = volume.name;
    _updateSelection(
      _selectedVolumeKeys,
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
    );
    if (secondary) {
      _openVolumeMenu(volume, details);
    }
  }

  void _updateSelection(
    Set<String> set,
    String key, {
    required bool isTouch,
    int? index,
    int? total,
  }) {
    final hardware = HardwareKeyboard.instance;
    final multi = hardware.isControlPressed || hardware.isMetaPressed;
    final additiveTouch = isTouch && set.isNotEmpty;
    final additive = multi || additiveTouch;
    setState(() {
      if (additive) {
        if (set.contains(key)) {
          set.remove(key);
        } else {
          set.add(key);
        }
      } else if (hardware.isShiftPressed &&
          index != null &&
          total != null &&
          total > 0 &&
          _containerAnchorIndex != null) {
        set.clear();
        final anchor = _containerAnchorIndex!.clamp(0, total - 1);
        final target = index.clamp(0, total - 1);
        final start = anchor < target ? anchor : target;
        final end = anchor > target ? anchor : target;
        for (var i = start; i <= end; i++) {
          set.add(_currentContainers[i].id);
        }
      } else {
        set
          ..clear()
          ..add(key);
        if (index != null) {
          _containerAnchorIndex = index;
        }
      }
    });
  }

  String _imageKey(DockerImage image) {
    final repo = image.repository.isNotEmpty ? image.repository : '<none>';
    final tag = image.tag.isNotEmpty ? image.tag : '<none>';
    return '$repo:$tag:${image.id}';
  }

  Future<void> _runContainerAction(
    DockerContainer container,
    String action,
  ) async {
    final Duration timeout = action == 'restart'
        ? const Duration(seconds: 30)
        : const Duration(seconds: 15);
    setState(() {
      _containerActionInProgress[container.id] = action;
    });
    try {
      if (widget.remoteHost != null && widget.shellService != null) {
        final cmd = 'docker $action ${container.id}';
        await widget.shellService!.runCommand(
          widget.remoteHost!,
          cmd,
          timeout: timeout,
        );
      } else {
        switch (action) {
          case 'start':
            await widget.docker.startContainer(
              id: container.id,
              context: widget.contextName,
              timeout: timeout,
            );
            break;
          case 'stop':
            await widget.docker.stopContainer(
              id: container.id,
              context: widget.contextName,
              timeout: timeout,
            );
            break;
          case 'restart':
            await widget.docker.restartContainer(
              id: container.id,
              context: widget.contextName,
              timeout: timeout,
            );
            break;
          case 'remove':
            await widget.docker.removeContainer(
              id: container.id,
              context: widget.contextName,
              timeout: timeout,
            );
            break;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Container ${action}ed successfully.')),
      );
      switch (action) {
        case 'restart':
          await _updateContainerAfterRestart(container);
          break;
        case 'start':
          await _updateContainerAfterStart(container);
          break;
        case 'stop':
          _markContainerStopped(container.id);
          break;
        default:
          _refresh();
          break;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to $action: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _containerActionInProgress.remove(container.id);
        });
      }
    }
  }

  Future<void> _runPrune({required bool includeVolumes}) async {
    try {
      if (widget.remoteHost != null && widget.shellService != null) {
        final cmd = includeVolumes
            ? 'docker system prune -f --volumes'
            : 'docker system prune -f';
        await widget.shellService!.runCommand(
          widget.remoteHost!,
          cmd,
          timeout: const Duration(seconds: 20),
        );
      } else {
        await widget.docker.systemPrune(
          context: widget.contextName,
          includeVolumes: includeVolumes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prune completed.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Prune failed: $error')));
    }
  }

  KeyEventResult _handleContainerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_currentContainers.isEmpty) return KeyEventResult.ignored;

    final hardware = HardwareKeyboard.instance;
    final multi = hardware.isControlPressed || hardware.isMetaPressed;
    final maxIndex = _currentContainers.length - 1;
    var current = _focusedContainerIndex ?? 0;

    void apply(int target) {
      target = target.clamp(0, maxIndex);
      final key = _currentContainers[target].id;
      _updateSelection(
        _selectedContainerIds,
        key,
        isTouch: false,
        index: target,
        total: _currentContainers.length,
      );
      setState(() {
        _focusedContainerIndex = target;
        _containerAnchorIndex ??= target;
      });
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        apply((current + 1).clamp(0, maxIndex));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        apply((current - 1).clamp(0, maxIndex));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        apply(0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        apply(maxIndex);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyA:
        if (multi) {
          setState(() {
            _selectedContainerIds
              ..clear()
              ..addAll(_currentContainers.map((c) => c.id));
            _focusedContainerIndex = maxIndex;
            _containerAnchorIndex = 0;
          });
          return KeyEventResult.handled;
        }
        break;
      default:
        break;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _updateContainerAfterRestart(DockerContainer container) async {
    final startedAt = await _loadStartTime(container);
    setState(() {
      _cachedContainers = _cachedContainers.map((c) {
        if (c.id != container.id) return c;
        return DockerContainer(
          id: c.id,
          name: c.name,
          image: c.image,
          state: 'running',
          status: 'running',
          ports: c.ports,
          command: c.command,
          createdAt: c.createdAt,
          composeProject: c.composeProject,
          composeService: c.composeService,
          startedAt: startedAt ?? DateTime.now().toUtc(),
        );
      }).toList();
    });
  }

  Future<void> _updateContainerAfterStart(DockerContainer container) async {
    final startedAt = await _loadStartTime(container);
    setState(() {
      _cachedContainers = _cachedContainers.map((c) {
        if (c.id != container.id) return c;
        return DockerContainer(
          id: c.id,
          name: c.name,
          image: c.image,
          state: 'running',
          status: 'running',
          ports: c.ports,
          command: c.command,
          createdAt: c.createdAt,
          composeProject: c.composeProject,
          composeService: c.composeService,
          startedAt: startedAt ?? DateTime.now().toUtc(),
        );
      }).toList();
    });
  }

  void _markContainerStopped(String containerId) {
    setState(() {
      _cachedContainers = _cachedContainers.map((c) {
        if (c.id != containerId) return c;
        return DockerContainer(
          id: c.id,
          name: c.name,
          image: c.image,
          state: 'exited',
          status: 'stopped',
          ports: c.ports,
          command: c.command,
          createdAt: c.createdAt,
          composeProject: c.composeProject,
          composeService: c.composeService,
          startedAt: null,
        );
      }).toList();
    });
  }

  Future<DateTime?> _loadStartTime(DockerContainer container) async {
    try {
      if (widget.remoteHost != null && widget.shellService != null) {
        final output = await widget.shellService!.runCommand(
          widget.remoteHost!,
          "docker inspect -f '{{.State.StartedAt}}' ${container.id}",
          timeout: const Duration(seconds: 8),
        );
        final raw = output.trim().replaceAll('"', '');
        return DateTime.tryParse(raw);
      }
      return await widget.docker.inspectContainerStartTime(
        id: container.id,
        context: widget.contextName,
      );
    } catch (_) {
      return null;
    }
  }

  List<DockerContainer> get _currentContainers => _cachedContainers;

  Set<String> _projectContainerIds(String project) {
    return _cachedContainers
        .where((c) => c.composeProject == project)
        .map((c) => c.id)
        .toSet();
  }

  Future<void> _syncProjectContainers(String project) async {
    try {
      final allContainers = await _engineService.fetchContainers(
        contextName: widget.contextName,
        remoteHost: widget.remoteHost,
        shell: widget.shellService,
      );
      final updatedProject = allContainers
          .where((c) => c.composeProject == project)
          .toList();
      setState(() {
        final others = _cachedContainers
            .where((c) => c.composeProject != project)
            .toList();
        _cachedContainers = [...others, ...updatedProject];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Compose sync failed: $error')));
    }
  }

  List<String> _composeServices(String project) {
    final services =
        _cachedContainers
            .where(
              (c) => c.composeProject == project && c.composeService != null,
            )
            .map((c) => c.composeService!)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return services;
  }
}
