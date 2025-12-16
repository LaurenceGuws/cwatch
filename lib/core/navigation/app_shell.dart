import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../models/app_settings.dart';
import '../../models/ssh_host.dart';
import '../../modules/docker/view.dart';
import '../../modules/kubernetes/view.dart';
import '../../modules/servers/view.dart';
import '../../modules/settings/view.dart';
import '../../modules/wsl/view.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../services/ssh/remote_command_logging.dart';
import '../../services/ssh/ssh_shell_factory.dart';
import '../../services/ssh/ssh_auth_prompter.dart';
import '../../services/ssh/ssh_auth_coordinator.dart';
import '../../services/ssh/ssh_config_service.dart';
import '../../shared/shortcuts/shortcut_actions.dart';
import '../../shared/shortcuts/shortcut_service.dart';
import '../../shared/theme/nerd_fonts.dart';
import '../../shared/shortcuts/input_mode_resolver.dart';
import '../../shared/gestures/gesture_activators.dart';
import '../../shared/gestures/gesture_service.dart';
import '../../shared/widgets/input_help_dialog.dart';
import '../../shared/widgets/command_palette.dart';
import 'command_palette_registry.dart';
import '../tabs/tab_bar_visibility.dart';
import '../../services/window/window_chrome_service.dart';
import '../../services/logging/app_logger.dart';
import 'gesture_detector_factory.dart';
import 'tab_navigation_registry.dart';
import 'module_registry.dart';
import 'shell_module.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WindowListener {
  late Future<List<SshHost>> _hostsFuture;
  String _selectedDestination = 'servers';
  bool _sidebarCollapsed = false;
  bool _shellStateRestored = false;
  bool _paletteOpen = false;
  late final GestureDetectorFactory _gestureDetectorFactory;
  late final WindowChromeService _windowChrome;
  late final VoidCallback _settingsListener;
  late final BuiltInSshKeyStore _builtInKeyStore;
  late final BuiltInSshVault _builtInVault;
  late final BuiltInSshKeyService _builtInKeyService;
  late final SshAuthCoordinator _authCoordinator;
  late final RemoteCommandLogController _commandLog;
  late final SshShellFactory _shellFactory;
  String? _hostsSettingsSignature;
  _SidebarPlacement _sidebarPlacement = _SidebarPlacement.dynamic;
  final Map<String, Widget> _pageCache = {};
  late final ModuleRegistry _moduleRegistry;
  bool _gesturesEnabled = true;
  GestureSubscription? _globalGestureSub;
  double? _scaleStartZoom;
  bool _isWindowMaximized = false;

  bool get _supportsCustomChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _commandLog = RemoteCommandLogController();
    _builtInKeyStore = BuiltInSshKeyStore();
    _builtInVault = BuiltInSshVault(keyStore: _builtInKeyStore);
    _builtInKeyService = BuiltInSshKeyService(
      keyStore: _builtInKeyStore,
      vault: _builtInVault,
    );
    _authCoordinator = SshAuthPrompter.forContext(
      context: context,
      keyService: _builtInKeyService,
    );
    _windowChrome = WindowChromeService();
    _shellFactory = SshShellFactory(
      settingsController: widget.settingsController,
      keyService: _builtInKeyService,
      authCoordinator: _authCoordinator,
      observer: _commandLog.add,
    );
    _refreshHosts();
    _moduleRegistry = ModuleRegistry(_buildModules());
    _moduleRegistry.addListener(_handleModulesChanged);
    _hostsSettingsSignature = _hostSettingsSignature(
      widget.settingsController.settings,
    );
    _applyShellSettings(widget.settingsController.settings);
    _shellStateRestored = widget.settingsController.isLoaded;
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
    ShortcutService.instance.updateSettings(widget.settingsController.settings);
    _gestureDetectorFactory = GestureDetectorFactory();
    _configureInputMode(widget.settingsController.settings);
    _syncWindowState();
  }

  ShortcutSubscription? _globalShortcutSub;

  void _refreshHosts() {
    final customHosts = widget.settingsController.settings.customSshHosts;
    final customConfigs =
        widget.settingsController.settings.customSshConfigPaths;
    final disabledConfigs =
        widget.settingsController.settings.disabledSshConfigPaths;
    _hostsFuture = SshConfigService(
      customHosts: customHosts,
      additionalEntryPoints: customConfigs,
      disabledEntryPoints: disabledConfigs,
    ).loadHosts();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _commandLog.dispose();
    _moduleRegistry.removeListener(_handleModulesChanged);
    widget.settingsController.removeListener(_settingsListener);
    _globalShortcutSub?.dispose();
    _globalGestureSub?.dispose();
    _gestureDetectorFactory.dispose();
    super.dispose();
  }

  void _handleModulesChanged() {
    if (!mounted) return;
    setState(() {
      final modules = _moduleRegistry.modules;
      if (modules.isEmpty) {
        _selectedDestination = '';
        return;
      }
      final exists = modules.any((module) => module.id == _selectedDestination);
      if (!exists) {
        _selectedDestination = modules.first.id;
      }
    });
  }

  void _handleSettingsChanged() {
    if (!widget.settingsController.isLoaded) {
      return;
    }
    if (!_shellStateRestored) {
      final previousDestination = _selectedDestination;
      setState(() {
        _applyShellSettings(widget.settingsController.settings);
        if (_selectedDestination != previousDestination) {
          _pageCache.removeWhere(
            (destination, _) => destination != _selectedDestination,
          );
        }
        _shellStateRestored = true;
      });
    }
    ShortcutService.instance.updateSettings(widget.settingsController.settings);
    _shellFactory.handleSettingsChanged(widget.settingsController.settings);
    _configureInputMode(widget.settingsController.settings);
    if (_moduleRegistry.modules.isEmpty) {
      return;
    }
    final nextSignature = _hostSettingsSignature(
      widget.settingsController.settings,
    );
    if (nextSignature != _hostsSettingsSignature) {
      _hostsSettingsSignature = nextSignature;
      setState(() {
        _refreshHosts();
      });
    }
    unawaited(_windowChrome.apply(widget.settingsController.settings));
  }

  void _applyShellSettings(AppSettings settings) {
    _selectedDestination =
        _destinationFromName(settings.shellDestination) ?? _selectedDestination;
    _sidebarCollapsed = settings.shellSidebarCollapsed;
    _sidebarPlacement = _placementFromString(settings.shellSidebarPlacement);
    unawaited(_windowChrome.apply(settings));
    _configureInputMode(settings);
  }

  Future<void> _changeAppZoom(double delta) async {
    await widget.settingsController.update((current) {
      final next = (current.zoomFactor + delta).clamp(0.8, 1.5).toDouble();
      return current.copyWith(zoomFactor: next);
    });
  }

  void _configureInputMode(AppSettings settings) {
    final config = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    if (mounted && _gesturesEnabled != config.enableGestures) {
      setState(() {
        _gesturesEnabled = config.enableGestures;
      });
    } else {
      _gesturesEnabled = config.enableGestures;
    }

    if (!config.enableShortcuts) {
      _globalShortcutSub?.dispose();
      _globalShortcutSub = null;
    } else {
      _globalShortcutSub ??= ShortcutService.instance.registerScope(
        id: 'global',
        priority: -10,
        handlers: {
          ShortcutActions.globalZoomIn: () => _changeAppZoom(0.05),
          ShortcutActions.globalZoomOut: () => _changeAppZoom(-0.05),
          ShortcutActions.tabsNext: _focusNextTab,
          ShortcutActions.tabsPrevious: _focusPreviousTab,
          ShortcutActions.viewsFocusUp: _focusPreviousDestination,
          ShortcutActions.viewsFocusDown: _focusNextDestination,
          ShortcutActions.globalCommandPalette: _openCommandPalette,
        },
        focusNode: null,
      );
    }

    if (!config.enableGestures) {
      _globalGestureSub?.dispose();
      _globalGestureSub = null;
    } else {
      _globalGestureSub ??= GestureService.instance.registerScope(
        id: 'global_gestures',
        priority: -10,
        handlers: {
          Gestures.commandPaletteTripleTap: (_) => _openCommandPalette(),
          Gestures.commandPaletteTripleSwipeDown: (_) => _openCommandPalette(),
          Gestures.tabsNextSwipe: (_) => _focusNextTab(),
          Gestures.tabsPreviousSwipe: (_) => _focusPreviousTab(),
          Gestures.viewsFocusUpSwipe: (_) => _focusPreviousDestination(),
          Gestures.globalPinchZoom: (invocation) {
            final next = invocation.payloadAs<double>();
            if (next != null) {
              _handleGlobalPinchZoom(next);
            }
          },
        },
        focusNode: null,
      );
    }
  }

  String _hostSettingsSignature(AppSettings settings) {
    final hosts = settings.customSshHosts
        .map(
          (host) =>
              '${host.name}|${host.hostname}|${host.port}|${host.user ?? ''}|${host.identityFile ?? ''}',
        )
        .join(';');
    final customConfigs = List<String>.from(settings.customSshConfigPaths)
      ..sort();
    final disabledConfigs = List<String>.from(settings.disabledSshConfigPaths)
      ..sort();
    return [
      hosts,
      customConfigs.join(';'),
      disabledConfigs.join(';'),
    ].join('::');
  }

  void _handleDestinationSelected(String destination) {
    if (_selectedDestination == destination) {
      return;
    }
    setState(() => _selectedDestination = destination);
    _persistShellState(destination: destination);
  }

  void _focusNextDestination() {
    final modules = _moduleRegistry.modules;
    if (modules.isEmpty) return;
    final currentIndex = modules.indexWhere(
      (m) => m.id == _selectedDestination,
    );
    final nextIndex = (currentIndex + 1) % modules.length;
    _handleDestinationSelected(modules[nextIndex].id);
  }

  void _focusPreviousDestination() {
    final modules = _moduleRegistry.modules;
    if (modules.isEmpty) return;
    final currentIndex = modules.indexWhere(
      (m) => m.id == _selectedDestination,
    );
    final prevIndex = (currentIndex - 1 + modules.length) % modules.length;
    _handleDestinationSelected(modules[prevIndex].id);
  }

  void _focusNextTab() {
    final navigator = TabNavigationRegistry.instance.forModule(
      _selectedDestination,
    );
    final handled = navigator?.next() ?? false;
    if (handled) return;
  }

  void _focusPreviousTab() {
    final navigator = TabNavigationRegistry.instance.forModule(
      _selectedDestination,
    );
    final handled = navigator?.previous() ?? false;
    if (handled) return;
  }

  void _setSidebarCollapsed(bool collapsed) {
    if (_sidebarCollapsed == collapsed) return;
    setState(() {
      _sidebarCollapsed = collapsed;
    });
    _persistShellState(collapsed: collapsed);
  }

  void _toggleSidebar() => _setSidebarCollapsed(!_sidebarCollapsed);

  Future<void> _openCommandPalette() async {
    if (_paletteOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    _paletteOpen = true;
    final entries = <CommandPaletteEntry>[
      CommandPaletteEntry(
        id: 'global:nextTab',
        label: 'Next tab',
        category: 'Navigation',
        onSelected: _focusNextTab,
        icon: Icons.arrow_forward,
      ),
      CommandPaletteEntry(
        id: 'global:previousTab',
        label: 'Previous tab',
        category: 'Navigation',
        onSelected: _focusPreviousTab,
        icon: Icons.arrow_back,
      ),
      CommandPaletteEntry(
        id: 'global:focusNextView',
        label: 'Focus next view',
        category: 'Navigation',
        onSelected: _focusNextDestination,
        icon: Icons.arrow_downward,
      ),
      CommandPaletteEntry(
        id: 'global:focusPreviousView',
        label: 'Focus previous view',
        category: 'Navigation',
        onSelected: _focusPreviousDestination,
        icon: Icons.arrow_upward,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:toggle',
        label: _sidebarCollapsed ? 'Show sidebar' : 'Hide sidebar',
        category: 'Chrome',
        onSelected: _toggleSidebar,
        icon: _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:show',
        label: 'Show sidebar',
        category: 'Chrome',
        onSelected: () => _setSidebarCollapsed(false),
        icon: Icons.chevron_right,
      ),
      CommandPaletteEntry(
        id: 'global:sidebar:hide',
        label: 'Hide sidebar',
        category: 'Chrome',
        onSelected: () => _setSidebarCollapsed(true),
        icon: Icons.chevron_left,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:toggleBar',
        label: TabBarVisibilityController.instance.value
            ? 'Hide tab bar'
            : 'Show tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.toggle,
        icon: Icons.tab,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:showBar',
        label: 'Show tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.show,
        icon: Icons.visibility,
      ),
      CommandPaletteEntry(
        id: 'global:tabs:hideBar',
        label: 'Hide tab bar',
        category: 'Chrome',
        onSelected: TabBarVisibilityController.instance.hide,
        icon: Icons.visibility_off,
      ),
      CommandPaletteEntry(
        id: 'global:help:input',
        label: 'Help: input & shortcuts',
        category: 'Help',
        description:
            'Show active shortcuts and gestures for the current context.',
        onSelected: () => showInputHelpDialog(
          context,
          settings: widget.settingsController.settings,
          moduleId: _selectedDestination,
        ),
        icon: Icons.info_outline,
      ),
    ];
    final handle = CommandPaletteRegistry.instance.forModule(
      _selectedDestination,
    );
    if (handle != null) {
      final moduleEntries = await Future<List<CommandPaletteEntry>>.value(
        handle.loader(),
      );
      entries.addAll(moduleEntries);
    }
    if (!mounted || entries.isEmpty) {
      _paletteOpen = false;
      return;
    }
    try {
      await showCommandPalette(context, entries: entries);
    } finally {
      _paletteOpen = false;
    }
  }

  void _ensurePageCached(String destination, BuildContext context) {
    if (_pageCache.containsKey(destination)) {
      return;
    }
    _pageCache[destination] = _buildPageForDestination(destination, context);
  }

  Widget _buildSidebarToggleButton(BuildContext context) {
    return _SidebarMenuButton(
      collapsed: _sidebarCollapsed,
      onShowOptions: (position) => _showSidebarOptions(context, position),
    );
  }

  Widget _buildPageForDestination(String destination, BuildContext context) {
    final toggleButton = _buildSidebarToggleButton(context);
    final module = _moduleById(destination);
    return module?.build(context, toggleButton) ?? const SizedBox.shrink();
  }

  Future<void> _showSidebarOptions(
    BuildContext context,
    Offset position,
  ) async {
    final choice = await showMenu<_SidebarOption>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        CheckedPopupMenuItem(
          value: _SidebarOption.hide,
          checked: _sidebarCollapsed,
          child: const Text('Hide sidebar'),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: _SidebarOption.pinLeft,
          checked:
              !_sidebarCollapsed && _sidebarPlacement == _SidebarPlacement.left,
          child: const Text('Pin to left'),
        ),
        CheckedPopupMenuItem(
          value: _SidebarOption.pinRight,
          checked:
              !_sidebarCollapsed &&
              _sidebarPlacement == _SidebarPlacement.right,
          child: const Text('Pin to right'),
        ),
        CheckedPopupMenuItem(
          value: _SidebarOption.pinBottom,
          checked:
              !_sidebarCollapsed &&
              _sidebarPlacement == _SidebarPlacement.bottom,
          child: const Text('Pin to bottom'),
        ),
        CheckedPopupMenuItem(
          value: _SidebarOption.dynamicPlacement,
          checked:
              !_sidebarCollapsed &&
              _sidebarPlacement == _SidebarPlacement.dynamic,
          child: const Text('Dynamic placement'),
        ),
      ],
    );
    if (choice != null) {
      _handleSidebarOption(choice);
    }
  }

  void _handleSidebarOption(_SidebarOption option) {
    setState(() {
      switch (option) {
        case _SidebarOption.hide:
          _sidebarCollapsed = true;
          break;
        case _SidebarOption.pinLeft:
          _sidebarCollapsed = false;
          _sidebarPlacement = _SidebarPlacement.left;
          break;
        case _SidebarOption.pinRight:
          _sidebarCollapsed = false;
          _sidebarPlacement = _SidebarPlacement.right;
          break;
        case _SidebarOption.pinBottom:
          _sidebarCollapsed = false;
          _sidebarPlacement = _SidebarPlacement.bottom;
          break;
        case _SidebarOption.dynamicPlacement:
          _sidebarCollapsed = false;
          _sidebarPlacement = _SidebarPlacement.dynamic;
          break;
      }
    });
    _persistShellState(
      collapsed: _sidebarCollapsed,
      placement: _sidebarPlacement,
    );
  }

  void _persistShellState({
    String? destination,
    bool? collapsed,
    _SidebarPlacement? placement,
  }) {
    final targetDestination = destination ?? _selectedDestination;
    final settings = widget.settingsController.settings;
    final targetCollapsed = collapsed ?? _sidebarCollapsed;
    final targetPlacement = placement ?? _sidebarPlacement;
    if (settings.shellDestination == targetDestination &&
        settings.shellSidebarCollapsed == targetCollapsed &&
        settings.shellSidebarPlacement == _placementToString(targetPlacement)) {
      return;
    }
    unawaited(
      widget.settingsController.update(
        (current) => current.copyWith(
          shellDestination: targetDestination,
          shellSidebarCollapsed: targetCollapsed,
          shellSidebarPlacement: _placementToString(targetPlacement),
        ),
      ),
    );
  }

  String? _destinationFromName(String? value) =>
      _moduleRegistry.modules.any((module) => module.id == value)
      ? value
      : (_moduleRegistry.modules.isNotEmpty
            ? _moduleRegistry.modules.first.id
            : null);

  int _moduleIndex(String id) {
    final modules = _moduleRegistry.modules;
    if (modules.isEmpty) return 0;
    final index = modules.indexWhere((module) => module.id == id);
    return index == -1 ? 0 : index;
  }

  ShellModuleView? _moduleById(String id) {
    final modules = _moduleRegistry.modules;
    if (modules.isEmpty) return null;
    return modules.firstWhere(
      (module) => module.id == id,
      orElse: () => modules.first,
    );
  }

  List<ShellModuleView> _buildModules() {
    final modules = <ShellModuleView>[
      ServersModule(
        hostsFuture: _hostsFuture,
        settingsController: widget.settingsController,
        keyService: _builtInKeyService,
        commandLog: _commandLog,
        shellFactory: _shellFactory,
      ),
    ];
    if (defaultTargetPlatform == TargetPlatform.windows) {
      modules.add(const WslModule());
    }
    modules.addAll([
      DockerModule(
        hostsFuture: _hostsFuture,
        settingsController: widget.settingsController,
        keyService: _builtInKeyService,
        commandLog: _commandLog,
        shellFactory: _shellFactory,
      ),
      KubernetesModule(settingsController: widget.settingsController),
      SettingsModule(
        controller: widget.settingsController,
        hostsFuture: _hostsFuture,
        keyService: _builtInKeyService,
        commandLog: _commandLog,
        shellFactory: _shellFactory,
      ),
    ]);
    return modules;
  }

  void _syncWindowState() {
    if (!_supportsCustomChrome) {
      return;
    }
    windowManager.addListener(this);
    unawaited(() async {
      final maximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _isWindowMaximized = maximized);
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        void showOptions(Offset position) =>
            _showSidebarOptions(context, position);
        _ensurePageCached(_selectedDestination, context);
        final viewportWidth = MediaQuery.of(context).size.width;
        final viewportHeight = MediaQuery.of(context).size.height;
        final isPortrait = viewportHeight > viewportWidth;
        final modules = _moduleRegistry.modules;
        final primaryModules = modules
            .where((module) => module.isPrimary)
            .toList();
        final secondaryModules = modules
            .where((module) => !module.isPrimary)
            .toList();
        final selectedIndex = _moduleIndex(_selectedDestination);
        final safeSelectedIndex = selectedIndex.clamp(
          0,
          (modules.length - 1).clamp(0, 9999),
        );
        final bool showSidebar = !_sidebarCollapsed;
        final bool useCustomChrome = _supportsCustomChrome &&
            !widget.settingsController.settings.windowUseSystemDecorations;
        final Widget? windowControls = useCustomChrome
            ? _WindowControls(
                isMaximized: _isWindowMaximized,
                onDrag: _startWindowDrag,
                onToggleMaximize: _toggleWindowMaximize,
                onMinimize: _minimizeWindow,
                onClose: _closeWindow,
              )
            : null;
        Widget? navigationBar;
        Alignment navigationAlignment = Alignment.centerLeft;
        EdgeInsets contentPadding = EdgeInsets.zero;
        if (showSidebar) {
          switch (_sidebarPlacement) {
            case _SidebarPlacement.dynamic:
              if (isPortrait) {
                navigationBar = _BottomNavBar(
                  modules: modules,
                  selected: _selectedDestination,
                  onSelect: _handleDestinationSelected,
                  onShowOptions: showOptions,
                );
                navigationAlignment = Alignment.bottomCenter;
                contentPadding = const EdgeInsets.only(
                  bottom: _BottomNavBar.height,
                );
              } else {
                navigationBar = _Sidebar(
                  primaryModules: primaryModules,
                  secondaryModules: secondaryModules,
                  selected: _selectedDestination,
                  onSelect: _handleDestinationSelected,
                  onShowOptions: showOptions,
                );
                navigationAlignment = Alignment.centerLeft;
                contentPadding = const EdgeInsets.only(left: _Sidebar.width);
              }
              break;
            case _SidebarPlacement.left:
              navigationBar = _Sidebar(
                primaryModules: primaryModules,
                secondaryModules: secondaryModules,
                selected: _selectedDestination,
                onSelect: _handleDestinationSelected,
                onShowOptions: showOptions,
              );
              navigationAlignment = Alignment.centerLeft;
              contentPadding = const EdgeInsets.only(left: _Sidebar.width);
              break;
            case _SidebarPlacement.right:
              navigationBar = _Sidebar(
                primaryModules: primaryModules,
                secondaryModules: secondaryModules,
                selected: _selectedDestination,
                onSelect: _handleDestinationSelected,
                alignRight: true,
                onShowOptions: showOptions,
              );
              navigationAlignment = Alignment.centerRight;
              contentPadding = const EdgeInsets.only(right: _Sidebar.width);
              break;
            case _SidebarPlacement.bottom:
              navigationBar = _BottomNavBar(
                modules: modules,
                selected: _selectedDestination,
                onSelect: _handleDestinationSelected,
                onShowOptions: showOptions,
              );
              navigationAlignment = Alignment.bottomCenter;
              contentPadding = const EdgeInsets.only(
                bottom: _BottomNavBar.height,
              );
              break;
          }
        }
        final content = Padding(
          padding: contentPadding,
          child: IndexedStack(
            key: const ValueKey('pages-indexed-stack'),
            index: safeSelectedIndex,
            children: modules
                .map(
                  (module) => _pageCache[module.id] ?? const SizedBox.shrink(),
                )
                .toList(),
          ),
        );
        return Focus(
          autofocus: true,
          canRequestFocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: _gesturesEnabled ? _handleScaleStart : null,
                    onScaleUpdate: _gesturesEnabled ? _handleScaleUpdate : null,
                    onScaleEnd: _gesturesEnabled ? _handleScaleEnd : null,
                    child: _gestureDetectorFactory.wrap(
                      context,
                      Stack(
                        children: [
                          Positioned.fill(child: content),
                          if (navigationBar != null)
                            Align(
                              alignment: navigationAlignment,
                              child: navigationBar,
                            ),
                        ],
                      ),
                      enabled: _gesturesEnabled,
                    ),
                  ),
                ),
                if (windowControls != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: windowControls,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _scaleStartZoom = widget.settingsController.settings.zoomFactor;
    AppLogger.d(
      'Pinch zoom start at ${_scaleStartZoom?.toStringAsFixed(2) ?? 'unknown'}',
      tag: 'Gestures',
    );
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final start = _scaleStartZoom;
    if (start == null || details.pointerCount < 2) return;
    final next = (start * details.scale).clamp(0.8, 1.5).toDouble();
    GestureService.instance.handle(Gestures.globalPinchZoom, payload: next);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _scaleStartZoom = null;
  }

  Future<void> _handleGlobalPinchZoom(double targetZoom) async {
    final current = widget.settingsController.settings.zoomFactor;
    if ((current - targetZoom).abs() < 0.005) {
      return;
    }
    AppLogger.d(
      'Pinch zoom updated app zoom from ${current.toStringAsFixed(2)} '
      'to ${targetZoom.toStringAsFixed(2)}',
      tag: 'Gestures',
    );
    await widget.settingsController.update(
      (settings) => settings.copyWith(zoomFactor: targetZoom),
    );
  }

  Future<void> _startWindowDrag() async {
    if (!_supportsCustomChrome) return;
    await windowManager.startDragging();
  }

  Future<void> _toggleWindowMaximize() async {
    if (!_supportsCustomChrome) return;
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
      if (mounted) setState(() => _isWindowMaximized = false);
    } else {
      await windowManager.maximize();
      if (mounted) setState(() => _isWindowMaximized = true);
    }
  }

  Future<void> _minimizeWindow() async {
    if (!_supportsCustomChrome) return;
    await windowManager.minimize();
  }

  Future<void> _closeWindow() async {
    if (!_supportsCustomChrome) return;
    await windowManager.close();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isWindowMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isWindowMaximized = false);
  }
}

class _WindowControls extends StatefulWidget {
  const _WindowControls({
    required this.isMaximized,
    required this.onDrag,
    required this.onToggleMaximize,
    required this.onMinimize,
    required this.onClose,
  });

  final bool isMaximized;
  final VoidCallback onDrag;
  final VoidCallback onToggleMaximize;
  final VoidCallback onMinimize;
  final VoidCallback onClose;

  @override
  State<_WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<_WindowControls> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => widget.onDrag(),
      onDoubleTap: widget.onToggleMaximize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CaptionButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimize',
            onPressed: widget.onMinimize,
          ),
          _CaptionButton(
            icon: widget.isMaximized
                ? Icons.filter_none_rounded
                : Icons.check_box_outline_blank_rounded,
            tooltip: widget.isMaximized ? 'Restore' : 'Maximize',
            onPressed: widget.onToggleMaximize,
          ),
          _CaptionButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: widget.onClose,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;

  void _setHover(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoverColor = widget.destructive
        ? Colors.red.withValues(alpha: 0.8)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.35);
    final iconColor = widget.destructive
        ? (_hovering ? Colors.white : scheme.onSurface)
        : scheme.onSurface;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: 32,
            color: _hovering ? hoverColor : Colors.transparent,
            child: Icon(widget.icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  static const double width = 56;

  const _Sidebar({
    required this.primaryModules,
    required this.secondaryModules,
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
    this.alignRight = false,
  });

  final List<ShellModuleView> primaryModules;
  final List<ShellModuleView> secondaryModules;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool alignRight;
  final ValueChanged<Offset>? onShowOptions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
      border: alignRight
          ? Border(
              left: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            )
          : Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
    );
    final content = Container(
      width: width,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: primaryModules
                .map(
                  (module) => _NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: true,
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: secondaryModules
                .map(
                  (module) => _NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: true,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    return GestureDetector(
      onLongPressStart: (details) =>
          onShowOptions?.call(details.globalPosition),
      onSecondaryTapDown: (details) =>
          onShowOptions?.call(details.globalPosition),
      child: content,
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.modules,
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
  });

  final List<ShellModuleView> modules;
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<Offset>? onShowOptions;

  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPressStart: (details) =>
          onShowOptions?.call(details.globalPosition),
      onSecondaryTapDown: (details) =>
          onShowOptions?.call(details.globalPosition),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Row(
          children: modules
              .map(
                (module) => Expanded(
                  child: _NavigationButton(
                    destinationId: module.id,
                    icon: module.icon,
                    label: module.label,
                    selected: selected == module.id,
                    onSelect: onSelect,
                    vertical: false,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavigationButton extends StatefulWidget {
  const _NavigationButton({
    required this.destinationId,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.vertical,
  });

  final String destinationId;
  final NerdIcon icon;
  final String label;
  final bool selected;
  final ValueChanged<String> onSelect;
  final bool vertical;

  @override
  State<_NavigationButton> createState() => _NavigationButtonState();
}

class _NavigationButtonState extends State<_NavigationButton> {
  bool _hovering = false;

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultColor = colorScheme.onSurfaceVariant;
    final hoverColor = colorScheme.primary.withValues(alpha: 0.75);
    final iconColor = widget.selected
        ? colorScheme.primary
        : (_hovering ? hoverColor : defaultColor);
    final indicatorColor = widget.selected
        ? colorScheme.primary
        : Colors.transparent;

    final iconWidget = Icon(widget.icon.data, size: 30, color: iconColor);

    final buttonWidth = widget.vertical ? _Sidebar.width : double.infinity;
    final button = InkWell(
      onTap: () => widget.onSelect(widget.destinationId),
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: buttonWidth,
        height: 56,
        child: widget.vertical
            ? Row(
                children: [
                  Container(width: 4, height: 56, color: indicatorColor),
                  Expanded(child: Center(child: iconWidget)),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 4,
                    color: indicatorColor,
                  ),
                  const Spacer(),
                  iconWidget,
                  const Spacer(),
                ],
              ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),
        cursor: SystemMouseCursors.click,
        child: Tooltip(message: widget.label, child: button),
      ),
    );
  }
}

class _SidebarMenuButton extends StatefulWidget {
  const _SidebarMenuButton({
    required this.collapsed,
    required this.onShowOptions,
  });

  final bool collapsed;
  final ValueChanged<Offset> onShowOptions;

  @override
  State<_SidebarMenuButton> createState() => _SidebarMenuButtonState();
}

class _SidebarMenuButtonState extends State<_SidebarMenuButton> {
  Offset? _tapPosition;

  void _onTapDown(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  void _onTap() {
    final position = _tapPosition ?? Offset.zero;
    widget.onShowOptions(position);
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = widget.collapsed ? 'Show navigation' : 'Sidebar options';
    return GestureDetector(
      onTapDown: _onTapDown,
      onTap: _onTap,
      behavior: HitTestBehavior.translucent,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(widget.collapsed ? Icons.menu : Icons.menu_open),
        ),
      ),
    );
  }
}

enum _SidebarPlacement { dynamic, left, right, bottom }

_SidebarPlacement _placementFromString(String? value) {
  switch (value) {
    case 'left':
      return _SidebarPlacement.left;
    case 'right':
      return _SidebarPlacement.right;
    case 'bottom':
      return _SidebarPlacement.bottom;
    case 'dynamic':
    default:
      return _SidebarPlacement.dynamic;
  }
}

String _placementToString(_SidebarPlacement placement) {
  switch (placement) {
    case _SidebarPlacement.dynamic:
      return 'dynamic';
    case _SidebarPlacement.left:
      return 'left';
    case _SidebarPlacement.right:
      return 'right';
    case _SidebarPlacement.bottom:
      return 'bottom';
  }
}

enum _SidebarOption { hide, pinLeft, pinRight, pinBottom, dynamicPlacement }
