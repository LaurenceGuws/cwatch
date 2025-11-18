import 'dart:async';

import 'package:flutter/material.dart';

import 'models/app_settings.dart';
import 'models/ssh_host.dart';
import 'services/code/grammar_manifest.dart';
import 'services/code/tree_sitter_support.dart';
import 'services/settings/app_settings_controller.dart';
import 'services/ssh/ssh_config_service.dart';
import 'services/ssh/builtin/builtin_ssh_key_store.dart';
import 'services/ssh/builtin/builtin_ssh_vault.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/nerd_fonts.dart';
import 'ui/views/docker/docker_view.dart';
import 'ui/views/kubernetes/kubernetes_view.dart';
import 'ui/views/servers/servers_view.dart';
import 'ui/views/settings/settings_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GrammarManifest.initialize();
  TreeSitterEnvironment.configure();
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
        final lightScheme = ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        );
        final lightTokens = AppThemeTokens.light(lightScheme);
        final darkTokens = AppThemeTokens.dark(darkScheme);
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: _buildTheme(lightScheme, lightTokens),
          darkTheme: _buildTheme(darkScheme, darkTokens),
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

  ThemeData _buildTheme(ColorScheme scheme, AppThemeTokens tokens) {
    final baseRadius = BorderRadius.circular(10);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: NerdFonts.family,
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
}

class HomeShell extends StatefulWidget {
  const HomeShell({required this.settingsController, super.key});

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const double _sidebarMinWidth = 44;
  static const double _sidebarContentMinWidth = 280;

  late Future<List<SshHost>> _hostsFuture;
  ShellDestination _selectedDestination = ShellDestination.servers;
  double? _sidebarWidthOverride;
  bool _sidebarCollapsed = false;
  bool _shellStateRestored = false;
  late final VoidCallback _settingsListener;
  late final BuiltInSshKeyStore _builtInKeyStore;
  late final BuiltInSshVault _builtInVault;

  @override
  void initState() {
    super.initState();
    _builtInKeyStore = BuiltInSshKeyStore();
    _builtInVault = BuiltInSshVault(keyStore: _builtInKeyStore);
    _refreshHosts();
    _applyShellSettings(widget.settingsController.settings);
    _shellStateRestored = widget.settingsController.isLoaded;
    _settingsListener = _handleSettingsChanged;
    widget.settingsController.addListener(_settingsListener);
  }

  void _refreshHosts() {
    final customHosts = widget.settingsController.settings.customSshHosts;
    _hostsFuture = SshConfigService(customHosts: customHosts).loadHosts();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_settingsListener);
    super.dispose();
  }

  void _handleSettingsChanged() {
    if (!widget.settingsController.isLoaded) {
      return;
    }
    if (!_shellStateRestored) {
      setState(() {
        _applyShellSettings(widget.settingsController.settings);
        _shellStateRestored = true;
      });
    }
    // Refresh hosts when custom hosts change
    setState(() {
      _refreshHosts();
    });
  }

  void _applyShellSettings(AppSettings settings) {
    final storedDestination = _destinationFromName(settings.shellDestination);
    if (storedDestination != null) {
      _selectedDestination = storedDestination;
    }
    _sidebarWidthOverride = settings.shellSidebarWidth;
    _sidebarCollapsed = settings.shellSidebarCollapsed;
  }

  void _handleSidebarDrag(double delta) {
    if (_sidebarCollapsed) return;
    if (delta == 0) return;
    final viewportWidth = MediaQuery.of(context).size.width;
    final maxWidth = _maxSidebarWidth(viewportWidth);
    setState(() {
      final current =
          _sidebarWidthOverride ?? _defaultSidebarWidth(viewportWidth);
      final next = (current + delta).clamp(_sidebarMinWidth, maxWidth);
      if ((next - current).abs() < 0.5) {
        return;
      }
      _sidebarWidthOverride = next;
    });
    _persistShellState(width: _sidebarWidthOverride);
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
    _persistShellState(collapsed: _sidebarCollapsed);
  }

  void _handleDestinationSelected(ShellDestination destination) {
    if (_selectedDestination == destination) {
      return;
    }
    setState(() => _selectedDestination = destination);
    _persistShellState(destination: destination);
  }

  void _persistShellState({
    double? width,
    ShellDestination? destination,
    bool? collapsed,
  }) {
    final targetDestination = destination ?? _selectedDestination;
    final settings = widget.settingsController.settings;
    final targetWidth = width ?? settings.shellSidebarWidth;
    final targetCollapsed = collapsed ?? settings.shellSidebarCollapsed;
    if (settings.shellSidebarWidth == targetWidth &&
        settings.shellDestination == targetDestination.name &&
        settings.shellSidebarCollapsed == targetCollapsed) {
      return;
    }
    unawaited(
      widget.settingsController.update(
        (current) => current.copyWith(
          shellSidebarWidth: targetWidth,
          shellDestination: targetDestination.name,
          shellSidebarCollapsed: targetCollapsed,
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

  double _defaultSidebarWidth(double viewportWidth) {
    final desired = viewportWidth * 0.25;
    final maxWidth = _maxSidebarWidth(viewportWidth);
    return desired.clamp(_sidebarMinWidth, maxWidth);
  }

  double _maxSidebarWidth(double viewportWidth) {
    final limit = viewportWidth - _sidebarContentMinWidth;
    if (limit <= _sidebarMinWidth) {
      return _sidebarMinWidth;
    }
    return limit;
  }

  double _effectiveSidebarWidth(double viewportWidth) {
    final base = _defaultSidebarWidth(viewportWidth);
    final maxWidth = _maxSidebarWidth(viewportWidth);
    final override = _sidebarWidthOverride ?? base;
    return override.clamp(_sidebarMinWidth, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.settingsController,
      builder: (context, _) {
        final viewportWidth = MediaQuery.of(context).size.width;
        final sidebarWidth = _effectiveSidebarWidth(viewportWidth);
        Widget buildToggleButton() {
          return _SidebarToggleButton(
            collapsed: _sidebarCollapsed,
            onPressed: _toggleSidebar,
          );
        }

        final pages = [
          ServersView(
            hostsFuture: _hostsFuture,
            settingsController: widget.settingsController,
            builtInVault: _builtInVault,
            leading: buildToggleButton(),
          ),
          DockerView(leading: buildToggleButton()),
          KubernetesView(leading: buildToggleButton()),
          SettingsView(
            controller: widget.settingsController,
            hostsFuture: _hostsFuture,
            builtInKeyStore: _builtInKeyStore,
            builtInVault: _builtInVault,
            leading: buildToggleButton(),
          ),
        ];
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (!_sidebarCollapsed) ...[
                  _Sidebar(
                    selected: _selectedDestination,
                    width: sidebarWidth,
                    onSelect: _handleDestinationSelected,
                  ),
                  _SidebarResizeHandle(onDrag: _handleSidebarDrag),
                ],
                Expanded(
                  child: IndexedStack(
                    index: _selectedDestination.index,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.width,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sections = [
      const [
        _SidebarEntry(
          destination: ShellDestination.servers,
          icon: NerdIcon.servers,
          label: 'Servers',
        ),
        _SidebarEntry(
          destination: ShellDestination.docker,
          icon: NerdIcon.docker,
          label: 'Docker',
        ),
        _SidebarEntry(
          destination: ShellDestination.kubernetes,
          icon: NerdIcon.kubernetes,
          label: 'Kubernetes',
        ),
      ],
      const [
        _SidebarEntry(
          destination: ShellDestination.settings,
          icon: NerdIcon.settings,
          label: 'Settings',
        ),
      ],
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = colorScheme.outlineVariant;
    final iconScale = (width / 220).clamp(0.5, 1.0).toDouble();
    final iconSize = 72 * iconScale;
    final showLabels = width >= 160;
    return Container(
      width: width,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Column(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            Expanded(
              flex: sections[i].length,
              child: Column(
                children: [
                  for (var entry in sections[i])
                    Expanded(
                      child: _SidebarButton(
                        icon: entry.icon,
                        label: entry.label,
                        selected: selected == entry.destination,
                        onTap: () => onSelect(entry.destination),
                        dividerColor: dividerColor,
                        iconSize: iconSize,
                        showLabel: showLabels,
                      ),
                    ),
                ],
              ),
            ),
            if (i < sections.length - 1)
              _SidebarDivider(color: dividerColor, inset: 12),
          ],
        ],
      ),
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 12,
          child: Center(
            child: Container(
              width: 1,
              height: double.infinity,
              color: dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarToggleButton extends StatelessWidget {
  const _SidebarToggleButton({
    required this.collapsed,
    required this.onPressed,
  });

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: collapsed ? 'Show navigation' : 'Hide navigation',
      icon: Icon(collapsed ? Icons.menu : Icons.menu_open),
      onPressed: onPressed,
    );
  }
}

enum ShellDestination { servers, docker, kubernetes, settings }

class _SidebarEntry {
  const _SidebarEntry({
    required this.destination,
    required this.icon,
    required this.label,
  });

  final ShellDestination destination;
  final NerdIcon icon;
  final String label;
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.dividerColor,
    required this.iconSize,
    required this.showLabel,
  });

  final NerdIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color dividerColor;
  final double iconSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final textColor = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon.data, size: iconSize, color: iconColor),
                      if (showLabel) ...[
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: textColor,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _SidebarDivider(
                color: selected ? colorScheme.primary : dividerColor,
                inset: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider({required this.color, this.inset = 12});

  final Color color;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Divider(color: color, height: 1, thickness: 1),
    );
  }
}
