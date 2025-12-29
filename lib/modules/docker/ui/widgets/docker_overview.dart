import 'dart:async';
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
import 'package:cwatch/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/shared/widgets/standard_empty_state.dart';
import '../engine_tab.dart';
import '../docker_tab_factory.dart';
import 'docker_lists.dart';
import 'docker_shared.dart';
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

class _DockerOverviewState extends State<DockerOverview>
    with SingleTickerProviderStateMixin, TabOptionsMixin {
  late DockerOverviewController _controller;
  late final VoidCallback _controllerListener;
  late DockerOverviewActions _actions;
  late DockerOverviewMenus _menus;
  late final ContainerDistroManager _containerDistroManager;
  late final TabController _tabController;
  final FocusNode _containerFocus = FocusNode(debugLabel: 'docker-containers');
  final Map<String, bool> _containerRunning = {};
  List<DockerImage> _currentImages = const [];
  List<DockerNetwork> _currentNetworks = const [];
  List<DockerVolume> _currentVolumes = const [];
  bool _didProbeDistro = false;
  AppIcons get _icons => context.appTheme.icons;
  AppDockerTokens get _dockerTheme => context.appTheme.docker;
  bool _tabOptionsRegistered = false;

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Containers'),
    Tab(text: 'Images'),
    Tab(text: 'Networks'),
    Tab(text: 'Volumes'),
  ];

  static const _tabIcons = [
    Icons.dashboard_outlined,
    Icons.apps_outlined,
    Icons.layers_outlined,
    Icons.lan_outlined,
    Icons.storage_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
    queueTabOptions(widget.optionsController, options);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_controllerListener)
      ..dispose();
    _tabController.dispose();
    _containerFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    _controller.refresh();
  }

  void _trackContainerDistro(List<DockerContainer> containers) {
    if (_didProbeDistro) {
      return;
    }
    _didProbeDistro = true;
    for (final container in containers) {
      final key = containerDistroCacheKey(container);
      final wasRunning = _containerRunning[key] ?? false;
      _containerRunning[key] = container.isRunning;
      if (!container.isRunning) {
        continue;
      }
      final needsProbe = !_containerDistroManager.hasCached(key) || !wasRunning;
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
    final spacing = context.appTheme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionNavBar(
          title: 'Docker',
          tabs: _tabs,
          tabIcons: _tabIcons,
          controller: _tabController,
          showTitle: false,
          enableWindowDrag: false,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(spacing.xs),
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
                _currentImages = images;
                _currentNetworks = networks;
                _currentVolumes = volumes;
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

                return TabBarView(
                  controller: _tabController,
                  children: [
                    ListView(
                      children: [
                        Wrap(
                          spacing: spacing.sm,
                          runSpacing: spacing.sm,
                          children: statsCards,
                        ),
                        if (containers.isEmpty &&
                            images.isEmpty &&
                            networks.isEmpty &&
                            volumes.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: spacing.lg),
                            child: const StandardEmptyState(
                              message:
                                  'No containers, images, networks, or volumes found.',
                            ),
                          ),
                      ],
                    ),
                    containers.isEmpty
                        ? _buildEmptyTab('No containers found.')
                        : ListView(
                            children: [
                              Focus(
                                focusNode: _containerFocus,
                                onKeyEvent: _handleContainerKey,
                                  child: ContainerPeek(
                                    containers: containers,
                                    onTapDown: _handleContainerTapDown,
                                    onSelectionChanged:
                                        _handleContainerSelectionChanged,
                                    selectedIds:
                                        _controller.selectedContainerIds,
                                    busyIds:
                                        _controller
                                            .containerActionInProgress
                                            .keys
                                            .toSet(),
                                    actionLabels:
                                        _controller.containerActionInProgress,
                                    onComposeAction: _handleComposeAction,
                                    onComposeForward: widget.remoteHost != null
                                        ? (project) =>
                                            _actions.forwardComposePorts(
                                              context,
                                              project: project,
                                            )
                                        : null,
                                    onComposeStopForward:
                                        widget.remoteHost != null
                                        ? (_) => _actions.stopForwardsForHost(
                                            context,
                                          )
                                        : null,
                                    settingsController:
                                        widget.settingsController,
                                ),
                              ),
                            ],
                          ),
                    images.isEmpty
                        ? _buildEmptyTab('No images found.')
                        : ListView(
                            children: [
                              ImagePeek(
                                  images: images,
                                  onTapDown: _handleImageTapDown,
                                  onSelectionChanged:
                                      _handleImageSelectionChanged,
                                  selectedIds: _controller.selectedImageKeys,
                              ),
                            ],
                          ),
                    networks.isEmpty
                        ? _buildEmptyTab('No networks found.')
                        : ListView(
                            children: [
                              NetworkList(
                                  networks: networks,
                                  onTapDown: _handleNetworkTapDown,
                                  onSelectionChanged:
                                      _handleNetworkSelectionChanged,
                                  selectedIds:
                                      _controller.selectedNetworkKeys,
                              ),
                            ],
                          ),
                    volumes.isEmpty
                        ? _buildEmptyTab('No volumes found.')
                        : ListView(
                            children: [
                              VolumeList(
                                  volumes: volumes,
                                  onTapDown: _handleVolumeTapDown,
                                  onSelectionChanged:
                                      _handleVolumeSelectionChanged,
                                  selectedIds:
                                      _controller.selectedVolumeKeys,
                              ),
                            ],
                          ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTab(String message) {
    return StandardEmptyState(message: message);
  }

  List<DockerContainer> _selectedContainersForAction(DockerContainer fallback) {
    final selectedIds = _controller.selectedContainerIds;
    if (selectedIds.isEmpty) {
      return [fallback];
    }
    final selected = _currentContainers
        .where((container) => selectedIds.contains(container.id))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  String _networkKey(DockerNetwork network) {
    return network.id.isNotEmpty ? network.id : network.name;
  }

  List<DockerImage> _selectedImagesForAction(DockerImage fallback) {
    final selectedKeys = _controller.selectedImageKeys;
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = _currentImages
        .where((image) => selectedKeys.contains(_imageKey(image)))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  List<DockerNetwork> _selectedNetworksForAction(DockerNetwork fallback) {
    final selectedKeys = _controller.selectedNetworkKeys;
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = _currentNetworks
        .where((network) => selectedKeys.contains(_networkKey(network)))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  List<DockerVolume> _selectedVolumesForAction(DockerVolume fallback) {
    final selectedKeys = _controller.selectedVolumeKeys;
    if (selectedKeys.isEmpty) {
      return [fallback];
    }
    final selected = _currentVolumes
        .where((volume) => selectedKeys.contains(volume.name))
        .toList();
    return selected.isEmpty ? [fallback] : selected;
  }

  void _openContainerMenu(DockerContainer container, TapDownDetails details) {
    final scheme = Theme.of(context).colorScheme;
    final selection = _selectedContainersForAction(container);
    final isMulti = selection.length > 1;
    final title = isMulti
        ? '${selection.length} containers selected'
        : (container.name.isNotEmpty ? container.name : container.id);
    final detailsMap = isMulti
        ? {'Selected': '${selection.length}'}
        : {
            'Image': container.image,
            'Status': container.status,
            'Ports': container.ports,
          };
    final copyValue = isMulti
        ? selection.map((item) => item.id).join('\n')
        : container.id;
    final copyLabel = isMulti ? 'Container IDs' : 'Container ID';
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
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
      extraActions: extraActions,
      onAction: (action) async {
        switch (action) {
          case 'logs':
            for (final target in selection) {
              if (!mounted) return;
              await _actions.openLogsTab(target, context: context);
            }
            break;
          case 'shell':
            for (final target in selection) {
              if (!mounted) return;
              await _actions.openExecTerminal(context, target);
            }
            break;
          case 'copyExec':
            if (selection.length == 1) {
              await _actions.copyExecCommand(context, selection.first.id);
            } else {
              final commands = selection
                  .map((item) => _actions.execCommand(item.id))
                  .join('\n');
              await Clipboard.setData(ClipboardData(text: commands));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Exec commands copied (${selection.length}).'),
                ),
              );
            }
            break;
          case 'stopForward':
            await _actions.stopForwardsForHost(context);
            break;
          case 'forward':
            for (final target in selection) {
              await _actions.forwardContainerPorts(context, container: target);
            }
            break;
          case 'explore':
            for (final target in selection) {
              await _actions.openContainerExplorer(
                context,
                target,
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
            }
            break;
          case 'start':
          case 'stop':
          case 'restart':
            await Future.wait(
              selection.map(
                (target) => _actions.runContainerAction(
                  context,
                  container: target,
                  action: action,
                  onRestarted: () => _updateContainerAfterRestart(target),
                  onStarted: () => _updateContainerAfterStart(target),
                  onStopped: () => _markContainerStopped(target.id),
                  onRefresh: _refresh,
                  loadStartTime: () => _loadStartTime(target),
                ),
              ),
            );
            break;
          case 'remove':
            for (final target in selection) {
              await _actions.runContainerAction(
                context,
                container: target,
                action: action,
                onRestarted: () => _updateContainerAfterRestart(target),
                onStarted: () => _updateContainerAfterStart(target),
                onStopped: () => _markContainerStopped(target.id),
                onRefresh: _refresh,
                loadStartTime: () => _loadStartTime(target),
              );
            }
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
    final selection = _selectedImagesForAction(image);
    final isMulti = selection.length > 1;
    final ref = [
      image.repository.isNotEmpty ? image.repository : '<none>',
      image.tag.isNotEmpty ? image.tag : '<none>',
    ].join(':');
    final title = isMulti ? '${selection.length} images selected' : ref;
    final detailsMap = isMulti
        ? {'Selected': '${selection.length}'}
        : {'ID': image.id, 'Size': image.size};
    final copyValue = isMulti
        ? selection.map((item) => item.id).join('\n')
        : image.id;
    final copyLabel = isMulti ? 'Image IDs' : 'Image ID';
    _menus.showItemMenu(
      context: context,
      globalPosition: details.globalPosition,
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
    );
  }

  void _openNetworkMenu(DockerNetwork network, TapDownDetails details) {
    final selection = _selectedNetworksForAction(network);
    final isMulti = selection.length > 1;
    final title = isMulti
        ? '${selection.length} networks selected'
        : network.name;
    final detailsMap = isMulti
        ? {'Selected': '${selection.length}'}
        : {'Driver': network.driver, 'Scope': network.scope};
    final copyValue = isMulti
        ? selection.map(_networkKey).join('\n')
        : _networkKey(network);
    final copyLabel = isMulti ? 'Network IDs' : 'Network ID';
    _menus.showItemMenu(
      context: context,
      globalPosition: details.globalPosition,
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
    );
  }

  void _openVolumeMenu(DockerVolume volume, TapDownDetails details) {
    final selection = _selectedVolumesForAction(volume);
    final isMulti = selection.length > 1;
    final title = isMulti
        ? '${selection.length} volumes selected'
        : volume.name;
    final detailsMap = isMulti
        ? {'Selected': '${selection.length}'}
        : {
            'Driver': volume.driver,
            'Mountpoint': volume.mountpoint ?? '—',
            'Scope': volume.scope ?? '—',
          };
    final copyValue = isMulti
        ? selection.map((item) => item.name).join('\n')
        : volume.name;
    final copyLabel = isMulti ? 'Volume names' : 'Volume name';
    _menus.showItemMenu(
      context: context,
      globalPosition: details.globalPosition,
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
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
    if (secondary) {
      _openVolumeMenu(volume, details);
    }
  }

  void _handleContainerSelectionChanged(
    Set<String> tableKeys,
    List<DockerContainer> selected,
  ) {
    _controller.replaceSelection(
      _controller.selectedContainerIds,
      tableKeys,
      selected.map((container) => container.id),
    );
  }

  void _handleImageSelectionChanged(
    Set<String> tableKeys,
    List<DockerImage> selected,
  ) {
    _controller.replaceSelection(
      _controller.selectedImageKeys,
      tableKeys,
      selected.map(_imageKey),
    );
  }

  void _handleNetworkSelectionChanged(
    Set<String> tableKeys,
    List<DockerNetwork> selected,
  ) {
    _controller.replaceSelection(
      _controller.selectedNetworkKeys,
      tableKeys,
      selected.map(
        (network) => network.id.isNotEmpty ? network.id : network.name,
      ),
    );
  }

  void _handleVolumeSelectionChanged(
    Set<String> tableKeys,
    List<DockerVolume> selected,
  ) {
    _controller.replaceSelection(
      _controller.selectedVolumeKeys,
      tableKeys,
      selected.map((volume) => volume.name),
    );
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
