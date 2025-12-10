import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/ssh_host.dart';
import '../../modules/docker/view.dart';
import '../../modules/kubernetes/view.dart';
import '../../modules/servers/view.dart';
import '../../modules/settings/view.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../services/ssh/remote_command_logging.dart';
import '../../services/ssh/ssh_shell_factory.dart';
import '../../services/ssh/ssh_config_service.dart';
import '../../shared/theme/nerd_fonts.dart';
import 'module_registry.dart';
import 'shell_module.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<List<SshHost>> _hostsFuture;
  String _selectedDestination = 'servers';
  bool _sidebarCollapsed = false;
  bool _shellStateRestored = false;
  late final VoidCallback _settingsListener;
  late final BuiltInSshKeyStore _builtInKeyStore;
  late final BuiltInSshVault _builtInVault;
  late final BuiltInSshKeyService _builtInKeyService;
  late final RemoteCommandLogController _commandLog;
  late final SshShellFactory _shellFactory;
  String? _hostsSettingsSignature;
  _SidebarPlacement _sidebarPlacement = _SidebarPlacement.dynamic;
  final Map<String, Widget> _pageCache = {};
  late final ModuleRegistry _moduleRegistry;

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
    _shellFactory = SshShellFactory(
      settingsController: widget.settingsController,
      keyService: _builtInKeyService,
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
  }

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
    _commandLog.dispose();
    _moduleRegistry.removeListener(_handleModulesChanged);
    widget.settingsController.removeListener(_settingsListener);
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
  }

  void _applyShellSettings(AppSettings settings) {
    _selectedDestination =
        _destinationFromName(settings.shellDestination) ?? _selectedDestination;
    _sidebarCollapsed = settings.shellSidebarCollapsed;
    _sidebarPlacement = _placementFromString(settings.shellSidebarPlacement);
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
    return [
      ServersModule(
        hostsFuture: _hostsFuture,
        settingsController: widget.settingsController,
        keyService: _builtInKeyService,
        commandLog: _commandLog,
        shellFactory: _shellFactory,
      ),
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
    ];
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
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: content),
                if (navigationBar != null)
                  Align(alignment: navigationAlignment, child: navigationBar),
              ],
            ),
          ),
        );
      },
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
