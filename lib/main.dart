import 'dart:async';

import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'models/ssh_host.dart';
import 'services/settings/app_settings_controller.dart';
import 'services/ssh/ssh_config_service.dart';
import 'services/ssh/builtin/builtin_ssh_key_store.dart';
import 'services/ssh/builtin/builtin_ssh_vault.dart';
import 'services/ssh/remote_command_logging.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/nerd_fonts.dart';
import 'ui/views/docker/docker_view.dart';
import 'ui/views/kubernetes/kubernetes_view.dart';
import 'ui/views/servers/servers_list.dart';
import 'ui/views/settings/settings_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CwatchApp());
}

class CwatchApp extends StatefulWidget {
  const CwatchApp({super.key});

  @override
  State<CwatchApp> createState() => _CwatchAppState();
}

class _CwatchAppState extends State<CwatchApp> {
  late final AppSettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController = AppSettingsController()..load();
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, _) {
        final settings = _settingsController.settings;
        final appFontFamily = settings.appFontFamily;
        final seed = _seedForKey(settings.appThemeKey);
        final lightScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        );
        final lightTokens = AppThemeTokens.light(
          lightScheme,
          fontFamily: appFontFamily,
        );
        final darkTokens = AppThemeTokens.dark(
          darkScheme,
          fontFamily: appFontFamily,
        );
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: _buildTheme(lightScheme, lightTokens, appFontFamily),
          darkTheme: _buildTheme(darkScheme, darkTokens, appFontFamily),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final zoom = settings.zoomFactor.clamp(0.8, 1.5).toDouble();
            return MediaQuery(
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(zoom)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: HomeShell(settingsController: _settingsController),
        );
      },
    );
  }

  ThemeData _buildTheme(
    ColorScheme scheme,
    AppThemeTokens tokens,
    String? fontFamily,
  ) {
    final baseRadius = BorderRadius.circular(10);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
        color: scheme.surfaceContainerHigh,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(12),
        thickness: WidgetStateProperty.all(4),
        thumbVisibility: WidgetStateProperty.all(true),
        thumbColor: WidgetStateProperty.all(
          scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      extensions: [tokens],
    );
  }

  Color _seedForKey(String key) {
    switch (key) {
      case 'teal':
        return Colors.teal;
      case 'amber':
        return Colors.amber;
      case 'indigo':
        return Colors.indigo;
      case 'purple':
        return Colors.deepPurple;
      case 'green':
        return Colors.green;
      case 'blue-grey':
      default:
        return Colors.blueGrey;
    }
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<List<SshHost>> _hostsFuture;
  ShellDestination _selectedDestination = ShellDestination.servers;
  bool _sidebarCollapsed = false;
  bool _shellStateRestored = false;
  late final VoidCallback _settingsListener;
  late final BuiltInSshKeyStore _builtInKeyStore;
  late final BuiltInSshVault _builtInVault;
  late final RemoteCommandLogController _commandLog;
  String? _hostsSettingsSignature;
  _SidebarPlacement _sidebarPlacement = _SidebarPlacement.dynamic;
  final Map<ShellDestination, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    _commandLog = RemoteCommandLogController();
    _builtInKeyStore = BuiltInSshKeyStore();
    _builtInVault = BuiltInSshVault(keyStore: _builtInKeyStore);
    _refreshHosts();
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
    widget.settingsController.removeListener(_settingsListener);
    super.dispose();
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
    final storedDestination = _destinationFromName(settings.shellDestination);
    if (storedDestination != null) {
      _selectedDestination = storedDestination;
    }
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

  void _handleDestinationSelected(ShellDestination destination) {
    if (_selectedDestination == destination) {
      return;
    }
    setState(() => _selectedDestination = destination);
    _persistShellState(destination: destination);
  }

  void _ensurePageCached(ShellDestination destination, BuildContext context) {
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

  Widget _buildPageForDestination(
    ShellDestination destination,
    BuildContext context,
  ) {
    final toggleButton = _buildSidebarToggleButton(context);
    switch (destination) {
      case ShellDestination.servers:
        return ServersList(
          hostsFuture: _hostsFuture,
          settingsController: widget.settingsController,
          builtInVault: _builtInVault,
          commandLog: _commandLog,
          leading: toggleButton,
        );
      case ShellDestination.docker:
        return DockerView(
          leading: toggleButton,
          hostsFuture: _hostsFuture,
          settingsController: widget.settingsController,
          builtInVault: _builtInVault,
          commandLog: _commandLog,
        );
      case ShellDestination.kubernetes:
        return KubernetesView(leading: toggleButton);
      case ShellDestination.settings:
        return SettingsView(
          controller: widget.settingsController,
          hostsFuture: _hostsFuture,
          builtInKeyStore: _builtInKeyStore,
          builtInVault: _builtInVault,
          commandLog: _commandLog,
          leading: toggleButton,
        );
    }
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
    ShellDestination? destination,
    bool? collapsed,
    _SidebarPlacement? placement,
  }) {
    final targetDestination = destination ?? _selectedDestination;
    final settings = widget.settingsController.settings;
    final targetCollapsed = collapsed ?? _sidebarCollapsed;
    final targetPlacement = placement ?? _sidebarPlacement;
    if (settings.shellDestination == targetDestination.name &&
        settings.shellSidebarCollapsed == targetCollapsed &&
        settings.shellSidebarPlacement == _placementToString(targetPlacement)) {
      return;
    }
    unawaited(
      widget.settingsController.update(
        (current) => current.copyWith(
          shellDestination: targetDestination.name,
          shellSidebarCollapsed: targetCollapsed,
          shellSidebarPlacement: _placementToString(targetPlacement),
        ),
      ),
    );
  }

  ShellDestination? _destinationFromName(String? value) {
    if (value == null) {
      return null;
    }
    for (final destination in ShellDestination.values) {
      if (destination.name == value) {
        return destination;
      }
    }
    return null;
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
        final bool showSidebar = !_sidebarCollapsed;
        Widget? navigationBar;
        Alignment navigationAlignment = Alignment.centerLeft;
        EdgeInsets contentPadding = EdgeInsets.zero;
        if (showSidebar) {
          switch (_sidebarPlacement) {
            case _SidebarPlacement.dynamic:
              if (isPortrait) {
                navigationBar = _BottomNavBar(
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
                selected: _selectedDestination,
                onSelect: _handleDestinationSelected,
                onShowOptions: showOptions,
              );
              navigationAlignment = Alignment.centerLeft;
              contentPadding = const EdgeInsets.only(left: _Sidebar.width);
              break;
            case _SidebarPlacement.right:
              navigationBar = _Sidebar(
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
            index: _selectedDestination.index,
            children: ShellDestination.values
                .map(
                  (destination) =>
                      _pageCache[destination] ?? const SizedBox.shrink(),
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

const List<ShellDestination> _primaryDestinations = [
  ShellDestination.servers,
  ShellDestination.docker,
  ShellDestination.kubernetes,
];

const List<ShellDestination> _secondaryDestinations = [
  ShellDestination.settings,
];

class _Sidebar extends StatelessWidget {
  static const double width = 56;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
    this.alignRight = false,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
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
            children: _primaryDestinations
                .map(
                  (destination) => _NavigationButton(
                    destination: destination,
                    icon: _iconForDestination(destination),
                    label: _labelForDestination(destination),
                    selected: selected == destination,
                    onSelect: onSelect,
                    vertical: true,
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: _secondaryDestinations
                .map(
                  (destination) => _NavigationButton(
                    destination: destination,
                    icon: _iconForDestination(destination),
                    label: _labelForDestination(destination),
                    selected: selected == destination,
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
    required this.selected,
    required this.onSelect,
    this.onShowOptions,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final ValueChanged<Offset>? onShowOptions;

  static const List<ShellDestination> _destinations = [
    ..._primaryDestinations,
    ..._secondaryDestinations,
  ];
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
          children: _destinations
              .map(
                (destination) => Expanded(
                  child: _NavigationButton(
                    destination: destination,
                    icon: _iconForDestination(destination),
                    label: _labelForDestination(destination),
                    selected: selected == destination,
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
    required this.destination,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.vertical,
  });

  final ShellDestination destination;
  final NerdIcon icon;
  final String label;
  final bool selected;
  final ValueChanged<ShellDestination> onSelect;
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
      onTap: () => widget.onSelect(widget.destination),
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

enum _SidebarPlacement { dynamic, left, right, bottom }

enum _SidebarOption { hide, pinLeft, pinRight, pinBottom, dynamicPlacement }

_SidebarPlacement _placementFromString(String? value) {
  switch (value) {
    case 'left':
      return _SidebarPlacement.left;
    case 'right':
      return _SidebarPlacement.right;
    case 'bottom':
      return _SidebarPlacement.bottom;
    default:
      return _SidebarPlacement.dynamic;
  }
}

String _placementToString(_SidebarPlacement placement) {
  switch (placement) {
    case _SidebarPlacement.left:
      return 'left';
    case _SidebarPlacement.right:
      return 'right';
    case _SidebarPlacement.dynamic:
      return 'dynamic';
    case _SidebarPlacement.bottom:
      return 'bottom';
  }
}

NerdIcon _iconForDestination(ShellDestination destination) {
  switch (destination) {
    case ShellDestination.servers:
      return NerdIcon.servers;
    case ShellDestination.docker:
      return NerdIcon.docker;
    case ShellDestination.kubernetes:
      return NerdIcon.kubernetes;
    case ShellDestination.settings:
      return NerdIcon.settings;
  }
}

String _labelForDestination(ShellDestination destination) {
  switch (destination) {
    case ShellDestination.servers:
      return 'Servers';
    case ShellDestination.docker:
      return 'Docker';
    case ShellDestination.kubernetes:
      return 'Kubernetes';
    case ShellDestination.settings:
      return 'Settings';
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

enum ShellDestination { servers, docker, kubernetes, settings }
