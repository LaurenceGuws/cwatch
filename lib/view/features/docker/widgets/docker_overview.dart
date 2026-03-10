import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/features/docker/services/docker_engine_service.dart';
import 'package:cwatch/model/services_infra/cache/distro_cache_controller.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/view/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'docker_lists.dart';
import 'docker_shared.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/controller/adapters/docker_overview_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_overview_actions_controller.dart';
import 'package:cwatch/model/features/docker/services/container_distro_manager.dart';
import 'package:cwatch/model/features/docker/services/container_distro_key.dart';

typedef OpenTab = void Function(WorkspaceTab tab);

class DockerOverview extends StatefulWidget {
  const DockerOverview({
    super.key,
    required this.controller,
    required this.actions,
    required this.uiAdapter,
    required this.settingsController,
    required this.distroCacheController,
    this.optionsController,
  });

  final DockerOverviewController controller;
  final DockerOverviewActionsController actions;
  final DockerOverviewUiAdapter uiAdapter;
  final AppSettingsController settingsController;
  final DistroCacheController distroCacheController;
  final TabOptionsController? optionsController;

  @override
  State<DockerOverview> createState() => _DockerOverviewState();
}

class _DockerOverviewState extends State<DockerOverview>
    with SingleTickerProviderStateMixin, TabOptionsMixin {
  late final DockerOverviewController _controller;
  late final DockerOverviewActionsController _actions;
  late final DockerOverviewUiAdapter _uiAdapter;
  late DockerOverviewMenus _menus;
  late final VoidCallback _controllerListener;
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
    _controller = widget.controller;
    _actions = widget.actions;
    _uiAdapter = widget.uiAdapter;

    _controllerListener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_controllerListener);
    _controller.initialize();

    _containerDistroManager = ContainerDistroManager(
      distroCacheController: widget.distroCacheController,
      docker: _controller.docker,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _menus = DockerOverviewMenus(icons: _icons, uiAdapter: _uiAdapter);
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
        onSelected: () => _actions.runPrune(includeVolumes: false),
      ),
      TabChipOption(
        label: 'Prune incl. volumes',
        icon: Icons.delete_sweep_outlined,
        color: scheme.error,
        onSelected: () => _actions.runPrune(includeVolumes: true),
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
            contextName: _controller.contextName,
            remoteHost: _controller.remoteHost,
            shellService: _controller.shellService,
            force: !wasRunning,
          ),
        );
      }
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
          enableWindowDrag:
              !widget.settingsController.settings.windowUseSystemDecorations,
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
                                  selectedIds: _controller.selectedContainerIds,
                                  busyIds: _controller
                                      .containerActionInProgress
                                      .keys
                                      .toSet(),
                                  actionLabels:
                                      _controller.containerActionInProgress,
                                  onComposeAction: _handleComposeAction,
                                  onComposeForward:
                                      _controller.remoteHost != null
                                      ? (project) =>
                                            _actions.forwardComposePorts(
                                              project: project,
                                            )
                                      : null,
                                  onComposeStopForward:
                                      _controller.remoteHost != null
                                      ? (_) => _actions.stopForwardsForHost()
                                      : null,
                                  settingsController: widget.settingsController,
                                  distroCacheController:
                                      widget.distroCacheController,
                                  dockerService: _controller.docker,
                                  contextName: _controller.contextName,
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
                                busyIds: _controller.imageActionInProgress.keys.toSet(),
                                actionLabels: _controller.imageActionInProgress,
                                onRemoveImages: _handleRemoveImages,
                                onPruneImages: _handlePruneImages,
                                onPullImage: _handlePullImage,
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
                                selectedIds: _controller.selectedNetworkKeys,
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
                                selectedIds: _controller.selectedVolumeKeys,
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

  void _openContainerMenu(
    DockerContainer container,
    TapDownDetails details, {
    List<DockerContainer>? selectedRows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // Use provided selectedRows if available, otherwise fall back to helper function
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _selectedContainersForAction(container);
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
      _menus.menuItem('logs', 'Tail logs', Icons.list_alt_outlined),
      _menus.menuItem('shell', 'Open shell tab', NerdIcon.terminal.data),
      _menus.menuItem('copyExec', 'Copy exec command', _icons.copy),
      if (_controller.remoteHost != null)
        _menus.menuItem('forward', 'Port forward…', Icons.link_outlined),
      if (_controller.remoteHost != null)
        _menus.menuItem(
          'stopForward',
          'Stop port forwards',
          Icons.link_off_outlined,
        ),
      _menus.menuItem('explore', 'Open explorer', _icons.folderOpen),
      _menus.menuItem('start', 'Start', Icons.play_arrow_rounded),
      _menus.menuItem('stop', 'Stop', Icons.stop_rounded),
      _menus.menuItem('restart', 'Restart', _icons.refresh),
      const PopupMenuDivider(),
      _menus.menuItem(
        'remove',
        'Remove',
        Icons.delete_outline,
        color: scheme.error,
      ),
    ];
    _menus.showItemMenu(
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
              await _actions.openLogsTab(container: target);
            }
            break;
          case 'shell':
            for (final target in selection) {
              if (!mounted) return;
              await _actions.openExecTerminal(target);
            }
            break;
          case 'copyExec':
            if (selection.length == 1) {
              await _actions.copyExecCommand(selection.first.id);
            } else {
              final commands = selection
                  .map((item) => _actions.execCommand(item.id))
                  .join('\n');
              await _uiAdapter.copyToClipboard(
                commands,
                successMessage: 'Exec commands copied (${selection.length}).',
              );
            }
            break;
          case 'stopForward':
            await _actions.stopForwardsForHost();
            break;
          case 'forward':
            for (final target in selection) {
              await _actions.forwardContainerPorts(container: target);
            }
            break;
          case 'explore':
            for (final target in selection) {
              await _actions.openContainerExplorer(
                container: target,
                dockerContextName: _dockerContextName(
                  _controller.remoteHost ??
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
        await _actions.openComposeLogsTab(project: project);
        break;
      case 'restart':
        await _actions.runComposeCommand(
          project: project,
          action: 'restart',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
      case 'up':
        await _actions.runComposeCommand(
          project: project,
          action: 'up',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
      case 'down':
        await _actions.runComposeCommand(
          project: project,
          action: 'down',
          onSynced: () => _syncProjectContainers(project),
        );
        break;
    }
  }

  void _openImageMenu(
    DockerImage image,
    TapDownDetails details, {
    List<DockerImage>? selectedRows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // Use provided selectedRows if available, otherwise fall back to helper function
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _selectedImagesForAction(image);
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
    final extraActions = <PopupMenuEntry<String>>[
      _menus.menuItem('pull', 'Pull image', Icons.download_outlined),
      _menus.menuItem('tag', 'Tag image', Icons.label_outline),
      _menus.menuItem('push', 'Push to registry', Icons.upload_outlined),
      _menus.menuItem('inspect', 'Inspect', Icons.info_outline),
      _menus.menuItem('history', 'View history', Icons.history),
      const PopupMenuDivider(),
      _menus.menuItem(
        'remove',
        'Remove',
        Icons.delete_outline,
        color: scheme.error,
      ),
    ];
    _menus.showItemMenu(
      globalPosition: details.globalPosition,
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
      extraActions: extraActions,
      onAction: (action) async {
        switch (action) {
          case 'pull':
            final imageName = await _uiAdapter.showTextInputDialog(
              title: 'Pull Image',
              label: 'Image name',
              hintText: 'e.g., nginx:latest, ubuntu:22.04',
            );
            if (imageName != null && imageName.isNotEmpty) {
              await _actions.pullImage(imageName);
            }
            break;
          case 'tag':
            final imageRef = [
              selection.first.repository,
              selection.first.tag,
            ].where((s) => s.isNotEmpty).join(':');
            final newTag = await _uiAdapter.showTextInputDialog(
              title: 'Tag Image',
              label: 'New tag',
              hintText: 'e.g., myregistry.com/myimage:v1.0',
              initialValue: imageRef,
            );
            if (newTag != null && newTag.isNotEmpty) {
              await _actions.tagImage(
                sourceImage: imageRef,
                targetImage: newTag,
                sourceImageId: selection.first.id,
              );
            }
            break;
          case 'push':
            final imageRef = [
              selection.first.repository,
              selection.first.tag,
            ].where((s) => s.isNotEmpty).join(':');
            await _actions.pushImage(imageRef, imageId: selection.first.id);
            break;
          case 'inspect':
            await _actions.inspectImage(selection.first.id);
            break;
          case 'history':
            await _actions.showImageHistory(selection.first.id);
            break;
          case 'remove':
            final imageIds = selection.map((img) => img.id).toList();
            await _handleRemoveImages(imageIds);
            break;
          default:
            break;
        }
      },
    );
  }

  void _openNetworkMenu(
    DockerNetwork network,
    TapDownDetails details, {
    List<DockerNetwork>? selectedRows,
  }) {
    // Use provided selectedRows if available, otherwise fall back to helper function
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _selectedNetworksForAction(network);
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
      globalPosition: details.globalPosition,
      title: title,
      details: detailsMap,
      copyValue: copyValue,
      copyLabel: copyLabel,
    );
  }

  void _openVolumeMenu(
    DockerVolume volume,
    TapDownDetails details, {
    List<DockerVolume>? selectedRows,
  }) {
    // Use provided selectedRows if available, otherwise fall back to helper function
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _selectedVolumesForAction(volume);
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
    List<DockerContainer>? selectedRows,
  }) {
    if (secondary) {
      _openContainerMenu(container, details, selectedRows: selectedRows);
    }
  }

  void _handleImageTapDown(
    DockerImage image,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
    List<DockerImage>? selectedRows,
  }) {
    if (secondary) {
      _openImageMenu(image, details, selectedRows: selectedRows);
    }
  }

  void _handleNetworkTapDown(
    DockerNetwork network,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
    List<DockerNetwork>? selectedRows,
  }) {
    if (secondary) {
      _openNetworkMenu(network, details, selectedRows: selectedRows);
    }
  }

  void _handleVolumeTapDown(
    DockerVolume volume,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
    List<DockerVolume>? selectedRows,
  }) {
    if (secondary) {
      _openVolumeMenu(volume, details, selectedRows: selectedRows);
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

  Future<void> _handleRemoveImages(List<String> imageIds) async {
    await _actions.removeImages(imageIds: imageIds, force: true);
  }

  Future<void> _handlePruneImages() async {
    await _actions.pruneImages(all: false);
  }

  Future<void> _handlePullImage(String imageName) async {
    await _actions.pullImage(imageName);
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
    final trimmedContext = _controller.contextName?.trim();
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
      if (_controller.remoteHost != null && _controller.shellService != null) {
        final output = await _controller.shellService!.runCommand(
          _controller.remoteHost!,
          "docker inspect -f '{{.State.StartedAt}}' ${container.id}",
          timeout: const Duration(seconds: 8),
        );
        final raw = output.trim().replaceAll('"', '');
        return DateTime.tryParse(raw);
      }
      return await _controller.docker.inspectContainerStartTime(
        id: container.id,
        context: _controller.contextName,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load container start time for ${container.name}',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
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
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to sync compose project $project',
        tag: 'Docker',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      _uiAdapter.showSnackBar('Compose sync failed: $error');
    }
  }
}
