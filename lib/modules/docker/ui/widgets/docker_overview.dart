import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/shared/views/shared/tabs/tab_chip.dart';

import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/models/docker_image.dart';
import 'package:cwatch/models/docker_network.dart';
import 'package:cwatch/models/docker_volume.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/modules/docker/services/docker_client_service.dart';
import 'package:cwatch/modules/docker/services/docker_engine_service.dart';
import 'package:cwatch/services/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/services/ssh/remote_shell_service.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/port_forwarding/port_forward_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import '../engine_tab.dart';
import '../docker_tab_factory.dart';
import 'docker_lists.dart';
import 'docker_shared.dart';
import 'section_card.dart';
import 'docker_overview_controller.dart';
import 'docker_overview_actions.dart';
import 'package:cwatch/modules/docker/services/container_distro_manager.dart';
import 'package:cwatch/modules/docker/services/container_distro_key.dart';

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
    required this.portForwardService,
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
  final PortForwardService portForwardService;

  @override
  State<DockerOverview> createState() => _DockerOverviewState();
}

class _DockerOverviewState extends State<DockerOverview> {
  late DockerOverviewController _controller;
  late final VoidCallback _controllerListener;
  late DockerOverviewActions _actions;
  late DockerOverviewMenus _menus;
  late final ContainerDistroManager _containerDistroManager;
  final FocusNode _containerFocus = FocusNode(debugLabel: 'docker-containers');
  final Map<String, bool> _containerRunning = {};
  AppIcons get _icons => context.appTheme.icons;
  AppDockerTokens get _dockerTheme => context.appTheme.docker;
  bool _tabOptionsRegistered = false;

  @override
  void initState() {
    super.initState();
    _controller = DockerOverviewController(
      docker: widget.docker,
      contextName: widget.contextName,
      remoteHost: widget.remoteHost,
      shellService: widget.shellService,
    );
    _controllerListener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_controllerListener);
    _controller.initialize();
    _actions = DockerOverviewActions(
      controller: _controller,
      docker: widget.docker,
      contextName: widget.contextName,
      remoteHost: widget.remoteHost,
      shellService: widget.shellService,
      tabFactory: widget.tabFactory,
      onOpenTab: widget.onOpenTab,
      onCloseTab: widget.onCloseTab,
      settingsController: widget.settingsController,
      portForwardService: widget.portForwardService,
      keyService: widget.keyService,
    );
    _containerDistroManager = ContainerDistroManager(
      settingsController: widget.settingsController,
      docker: widget.docker,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _menus = DockerOverviewMenus(icons: _icons);
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
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    _containerFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    _controller.refresh();
  }

  void _trackContainerDistro(List<DockerContainer> containers) {
    for (final container in containers) {
      final key = containerDistroCacheKey(container);
      final wasRunning = _containerRunning[key] ?? false;
      _containerRunning[key] = container.isRunning;
      if (!container.isRunning) {
        continue;
      }
      final needsProbe =
          !_containerDistroManager.hasCached(key) || !wasRunning;
      if (needsProbe) {
        unawaited(
          _containerDistroManager.ensureDistroForContainer(
            container,
            force: !wasRunning,
          ),
        );
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
              future: _controller.snapshot,
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
                final containers = _controller.ensureHydrated(data);
                _trackContainerDistro(containers);
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
                          selectedIds: _controller.selectedContainerIds,
                          busyIds: _controller.containerActionInProgress.keys
                              .toSet(),
                          actionLabels: _controller.containerActionInProgress,
                          onComposeAction: _handleComposeAction,
                          onComposeForward: widget.remoteHost != null
                              ? (project) => _actions.forwardComposePorts(
                                    context,
                                    project: project,
                                  )
                              : null,
                          onComposeStopForward: widget.remoteHost != null
                              ? (_) => _actions.stopForwardsForHost(context)
                              : null,
                          settingsController: widget.settingsController,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Images',
                      child: ImagePeek(
                        images: images,
                        onTapDown: _handleImageTapDown,
                        selectedIds: _controller.selectedImageKeys,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Networks',
                      child: NetworkList(
                        networks: networks,
                        onTapDown: _handleNetworkTapDown,
                        selectedIds: _controller.selectedNetworkKeys,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SectionCard(
                      title: 'Volumes',
                      child: VolumeList(
                        volumes: volumes,
                        onTapDown: _handleVolumeTapDown,
                        selectedIds: _controller.selectedVolumeKeys,
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

  void _openContainerMenu(DockerContainer container, TapDownDetails details) {
    final scheme = Theme.of(context).colorScheme;
    final extraActions = <PopupMenuEntry<String>>[
      _menus.menuItem(context, 'logs', 'Tail logs', Icons.list_alt_outlined),
      _menus.menuItem(
        context,
        'shell',
        'Open shell tab',
        NerdIcon.terminal.data,
      ),
      _menus.menuItem(context, 'copyExec', 'Copy exec command', _icons.copy),
      if (widget.remoteHost != null)
        _menus.menuItem(
          context,
          'forward',
          'Port forward…',
          Icons.link_outlined,
        ),
      if (widget.remoteHost != null)
        _menus.menuItem(
          context,
          'stopForward',
          'Stop port forwards',
          Icons.link_off_outlined,
        ),
      _menus.menuItem(context, 'explore', 'Open explorer', _icons.folderOpen),
      _menus.menuItem(context, 'start', 'Start', Icons.play_arrow_rounded),
      _menus.menuItem(context, 'stop', 'Stop', Icons.stop_rounded),
      _menus.menuItem(context, 'restart', 'Restart', _icons.refresh),
      const PopupMenuDivider(),
      _menus.menuItem(
        context,
        'remove',
        'Remove',
        Icons.delete_outline,
        color: scheme.error,
      ),
    ];
    _menus.showItemMenu(
      context: context,
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
        switch (action) {
          case 'logs':
            await _actions.openLogsTab(container, context: context);
            break;
          case 'shell':
            await _actions.openExecTerminal(context, container);
            break;
          case 'copyExec':
            await _actions.copyExecCommand(context, container.id);
            break;
          case 'stopForward':
            await _actions.stopForwardsForHost(context);
            break;
          case 'forward':
            await _actions.forwardContainerPorts(context, container: container);
            break;
          case 'explore':
            await _actions.openContainerExplorer(
              context,
              container,
              dockerContextName: _dockerContextName(
                widget.remoteHost ??
                    const SshHost(
                      name: 'local',
                      hostname: 'localhost',
                      port: 22,
                      available: true,
                      user: null,
                      identityFiles: <String>[],
                      source: 'local',
                    ),
              ),
            );
            break;
          case 'start':
          case 'stop':
          case 'restart':
          case 'remove':
            await _actions.runContainerAction(
              context,
              container: container,
              action: action,
              onRestarted: () => _updateContainerAfterRestart(container),
              onStarted: () => _updateContainerAfterStart(container),
              onStopped: () => _markContainerStopped(container.id),
              onRefresh: _refresh,
              loadStartTime: () => _loadStartTime(container),
            );
            break;
          default:
            break;
        }
      },
    );
  }

  Future<void> _handleComposeAction(String project, String action) async {
    switch (action) {
      case 'logs':
        await _actions.openComposeLogsTab(context, project: project);
        break;
      case 'restart':
        await _actions.runComposeCommand(
          context,
          project: project,
          action: 'restart',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
      case 'up':
        await _actions.runComposeCommand(
          context,
          project: project,
          action: 'up',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
      case 'down':
        await _actions.runComposeCommand(
          context,
          project: project,
          action: 'down',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
    }
  }

  void _openImageMenu(DockerImage image, TapDownDetails details) {
    final ref = [
      image.repository.isNotEmpty ? image.repository : '<none>',
      image.tag.isNotEmpty ? image.tag : '<none>',
    ].join(':');
    _menus.showItemMenu(
      context: context,
      globalPosition: details.globalPosition,
      title: ref,
      details: {'ID': image.id, 'Size': image.size},
      copyValue: image.id,
      copyLabel: 'Image ID',
    );
  }

  void _openNetworkMenu(DockerNetwork network, TapDownDetails details) {
    _menus.showItemMenu(
      context: context,
      globalPosition: details.globalPosition,
      title: network.name,
      details: {'Driver': network.driver, 'Scope': network.scope},
      copyValue: network.id,
      copyLabel: 'Network ID',
    );
  }

  void _openVolumeMenu(DockerVolume volume, TapDownDetails details) {
    _menus.showItemMenu(
      context: context,
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

  Future<void> _updateContainerAfterRestart(DockerContainer container) async {
    final startedAt = await _loadStartTime(container);
    _controller.mapCachedContainers((c) {
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
    });
  }

  Future<void> _updateContainerAfterStart(DockerContainer container) async {
    final startedAt = await _loadStartTime(container);
    _controller.mapCachedContainers((c) {
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
    });
  }

  void _markContainerStopped(String containerId) {
    _controller.mapCachedContainers((c) {
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
    });
  }

  void _handleContainerTapDown(
    DockerContainer container,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
  }) {
    final key = container.id;
    _controller.updateContainerSelection(
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
      index: flatIndex,
    );
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
    _controller.updateSimpleSelection(
      _controller.selectedImageKeys,
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
    _controller.updateSimpleSelection(
      _controller.selectedNetworkKeys,
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
    _controller.updateSimpleSelection(
      _controller.selectedVolumeKeys,
      key,
      isTouch: details.kind == PointerDeviceKind.touch,
    );
    if (secondary) {
      _openVolumeMenu(volume, details);
    }
  }

  KeyEventResult _handleContainerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_currentContainers.isEmpty) return KeyEventResult.ignored;

    final hardware = HardwareKeyboard.instance;
    final multi = hardware.isControlPressed || hardware.isMetaPressed;
    final maxIndex = _currentContainers.length - 1;
    var current = _controller.focusedContainerIndex ?? 0;

    void apply(int target) {
      target = target.clamp(0, maxIndex);
      final key = _currentContainers[target].id;
      _controller.updateContainerSelection(key, isTouch: false, index: target);
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
          _controller.selectAllContainers();
          return KeyEventResult.handled;
        }
        break;
      default:
        break;
    }
    return KeyEventResult.ignored;
  }

  String _dockerContextName(SshHost host) {
    final trimmedContext = widget.contextName?.trim();
    if (trimmedContext?.isNotEmpty == true) {
      return trimmedContext!;
    }
    return '${host.name}-docker';
  }

  String _imageKey(DockerImage image) {
    final repo = image.repository.isNotEmpty ? image.repository : '<none>';
    final tag = image.tag.isNotEmpty ? image.tag : '<none>';
    return '$repo:$tag:${image.id}';
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

  List<DockerContainer> get _currentContainers => _controller.cachedContainers;

  Future<void> _syncProjectContainers(String project) async {
    try {
      final allContainers = await _controller.fetchContainers();
      final updatedProject = allContainers
          .where((c) => c.composeProject == project)
          .toList();
      final others = _controller.cachedContainers
          .where((c) => c.composeProject != project)
          .toList();
      _controller.updateCachedContainers([...others, ...updatedProject]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Compose sync failed: $error')));
    }
  }
}
