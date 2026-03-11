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
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/view/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/view/shared/widgets/section_nav_bar.dart';
import 'package:cwatch/view/shared/widgets/standard_empty_state.dart';
import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'docker_lists.dart';
import 'docker_overview_action_state.dart';
import 'docker_overview_container_menu_helper.dart';
import 'docker_overview_image_menu_helper.dart';
import 'docker_overview_interaction_helper.dart';
import 'docker_overview_runtime_state.dart';
import 'docker_overview_storage_menu_helper.dart';
import 'docker_shared.dart';
import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/controller/adapters/docker_overview_ui_adapter.dart';
import 'package:cwatch/controller/controllers/docker_overview_actions_controller.dart';
import 'package:cwatch/model/features/docker/services/container_distro_manager.dart';

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
  final DockerOverviewActionState _actionState =
      const DockerOverviewActionState();
  final DockerOverviewContainerMenuHelper _containerMenuHelper =
      const DockerOverviewContainerMenuHelper();
  final DockerOverviewImageMenuHelper _imageMenuHelper =
      const DockerOverviewImageMenuHelper();
  final DockerOverviewStorageMenuHelper _storageMenuHelper =
      const DockerOverviewStorageMenuHelper();
  final DockerOverviewInteractionHelper _interactionHelper =
      const DockerOverviewInteractionHelper();
  late final DockerOverviewController _controller;
  late final DockerOverviewActionsController _actions;
  late final DockerOverviewUiAdapter _uiAdapter;
  late DockerOverviewMenus _menus;
  late final VoidCallback _controllerListener;
  late final ContainerDistroManager _containerDistroManager;
  late final DockerOverviewRuntimeState _runtimeState;
  late final TabController _tabController;
  final FocusNode _containerFocus = FocusNode(debugLabel: 'docker-containers');
  List<DockerImage> _currentImages = const [];
  List<DockerNetwork> _currentNetworks = const [];
  List<DockerVolume> _currentVolumes = const [];
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
    _runtimeState = DockerOverviewRuntimeState(
      controller: _controller,
      containerDistroManager: _containerDistroManager,
      actionState: _actionState,
      uiAdapter: _uiAdapter,
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
              !widget
                  .settingsController
                  .settings
                  .shellPreferences
                  .useSystemDecorations,
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
                        : Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                _handleTabSurfacePointerDown(1, event),
                            child: ListView(
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
                          ),
                    images.isEmpty
                        ? _buildEmptyTab('No images found.')
                        : Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                _handleTabSurfacePointerDown(2, event),
                            child: ListView(
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
                          ),
                    networks.isEmpty
                        ? _buildEmptyTab('No networks found.')
                        : Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                _handleTabSurfacePointerDown(3, event),
                            child: ListView(
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
                          ),
                    volumes.isEmpty
                        ? _buildEmptyTab('No volumes found.')
                        : Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                _handleTabSurfacePointerDown(4, event),
                            child: ListView(
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

  void _handleTabSurfacePointerDown(int tabIndex, PointerDownEvent event) {
    _interactionHelper.handleTabSurfacePointerDown(
      tabIndex: tabIndex,
      event: event,
      controller: _controller,
    );
  }

  void _openContainerMenu(
    DockerContainer container,
    TapDownDetails details, {
    List<DockerContainer>? selectedRows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _actionState.selectedContainersForAction(
            fallback: container,
            selectedIds: _controller.selectedContainerIds,
            containers: _currentContainers,
          );
    _runtimeState.ensureContainerDistroOnDemand(selection);
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
        await _containerMenuHelper.handleAction(
          action: action,
          selection: selection,
          dockerContextNameFor: _dockerContextName,
          remoteHost: _controller.remoteHost,
          openLogs: (target) async {
            if (!mounted) return;
            await _actions.openLogsTab(container: target);
          },
          openShell: (target) async {
            if (!mounted) return;
            await _actions.openExecTerminal(target);
          },
          copyExecCommand: _actions.copyExecCommand,
          execCommand: _actions.execCommand,
          copyExecCommands: (commands, count) => _uiAdapter.copyToClipboard(
            commands,
            successMessage: 'Exec commands copied ($count).',
          ),
          stopForwards: _actions.stopForwardsForHost,
          forwardPorts: (target) =>
              _actions.forwardContainerPorts(container: target),
          openExplorer: (target, dockerContextName) =>
              _actions.openContainerExplorer(
                container: target,
                dockerContextName: dockerContextName,
              ),
          runAction: (target, selectedAction) => _actions.runContainerAction(
            container: target,
            action: selectedAction,
            onRestarted: () => _runtimeState.updateContainerAfterRestart(target),
            onStarted: () => _runtimeState.updateContainerAfterStart(target),
            onStopped: () => _runtimeState.markContainerStopped(target.id),
            onRefresh: _refresh,
            loadStartTime: () => _runtimeState.loadStartTime(target),
          ),
        );
      },
    );
  }

  Future<void> _handleComposeAction(String project, String action) async {
    await _interactionHelper.handleComposeAction(
      project: project,
      action: action,
      openLogs: (targetProject) =>
          _actions.openComposeLogsTab(project: targetProject),
      runCommand: (targetProject, targetAction) => _actions.runComposeCommand(
        project: targetProject,
        action: targetAction,
        onSynced: () => _runtimeState.syncProjectContainers(targetProject),
      ),
    );
  }

  void _openImageMenu(
    DockerImage image,
    TapDownDetails details, {
    List<DockerImage>? selectedRows,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selection = selectedRows?.isNotEmpty == true
        ? selectedRows!
        : _actionState.selectedImagesForAction(
            fallback: image,
            selectedKeys: _controller.selectedImageKeys,
            images: _currentImages,
          );
    final isMulti = selection.length > 1;
    final ref = _imageMenuHelper.imageReference(image);
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
        await _imageMenuHelper.handleAction(
          action: action,
          selection: selection,
          promptTag: (initialValue) => _uiAdapter.showTextInputDialog(
            title: 'Tag Image',
            label: 'New tag',
            hintText: 'e.g., myregistry.com/myimage:v1.0',
            initialValue: initialValue,
          ),
          promptPull: () => _uiAdapter.showTextInputDialog(
            title: 'Pull Image',
            label: 'Image name',
            hintText: 'e.g., nginx:latest, ubuntu:22.04',
          ),
          pullImage: _actions.pullImage,
          tagImage: _actions.tagImage,
          pushImage: _actions.pushImage,
          inspectImage: _actions.inspectImage,
          showImageHistory: _actions.showImageHistory,
          removeImages: _handleRemoveImages,
        );
      },
    );
  }

  void _openNetworkMenu(
    DockerNetwork network,
    TapDownDetails details, {
    List<DockerNetwork>? selectedRows,
  }) {
    final projection = _storageMenuHelper.projectNetworkMenu(
      network: network,
      selectedRows: selectedRows,
      selectedKeys: _controller.selectedNetworkKeys,
      networks: _currentNetworks,
      actionState: _actionState,
    );
    _menus.showItemMenu(
      globalPosition: details.globalPosition,
      title: projection.title,
      details: projection.details,
      copyValue: projection.copyValue,
      copyLabel: projection.copyLabel,
    );
  }

  void _openVolumeMenu(
    DockerVolume volume,
    TapDownDetails details, {
    List<DockerVolume>? selectedRows,
  }) {
    final projection = _storageMenuHelper.projectVolumeMenu(
      volume: volume,
      selectedRows: selectedRows,
      selectedKeys: _controller.selectedVolumeKeys,
      volumes: _currentVolumes,
      actionState: _actionState,
    );
    _menus.showItemMenu(
      globalPosition: details.globalPosition,
      title: projection.title,
      details: projection.details,
      copyValue: projection.copyValue,
      copyLabel: projection.copyLabel,
    );
  }

  void _handleContainerTapDown(
    DockerContainer container,
    TapDownDetails details, {
    bool secondary = false,
    int? flatIndex,
    List<DockerContainer>? selectedRows,
  }) {
    if (secondary) {
      _interactionHelper.handleContainerSecondaryTap(
        container: container,
        controller: _controller,
        containers: _currentContainers,
        flatIndex: flatIndex,
      );
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
      _interactionHelper.handleImageSecondaryTap(
        image: image,
        controller: _controller,
        actionState: _actionState,
      );
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
      _interactionHelper.handleNetworkSecondaryTap(
        network: network,
        controller: _controller,
        actionState: _actionState,
      );
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
      _interactionHelper.handleVolumeSecondaryTap(
        volume: volume,
        controller: _controller,
      );
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
      selected.map(_actionState.imageKey),
    );
  }

  void _handleNetworkSelectionChanged(
    Set<String> tableKeys,
    List<DockerNetwork> selected,
  ) {
    _controller.replaceSelection(
      _controller.selectedNetworkKeys,
      tableKeys,
      selected.map(_actionState.networkKey),
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

  List<DockerContainer> get _currentContainers => _controller.cachedContainers;
}
