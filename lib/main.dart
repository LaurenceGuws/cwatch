import 'package:flutter/material.dart';

import 'models/ssh_host.dart';
import 'services/code/grammar_manifest.dart';
import 'services/code/tree_sitter_support.dart';
import 'services/settings/app_settings_controller.dart';
import 'services/ssh/ssh_config_service.dart';
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
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            fontFamily: NerdFonts.family,
            extensions: [AppThemeTokens.light(lightScheme)],
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            fontFamily: NerdFonts.family,
            extensions: [AppThemeTokens.dark(darkScheme)],
          ),
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _hostsFuture = SshConfigService().loadHosts();
    _pages = [
      ServersView(hostsFuture: _hostsFuture),
      const DockerView(),
      const KubernetesView(),
      SettingsView(controller: widget.settingsController),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Control Center')),
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              selected: _selectedDestination,
              onSelect: (destination) => setState(() {
                _selectedDestination = destination;
              }),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedDestination.index,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;

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
    return Container(
      width: 220,
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
  });

  final NerdIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color dividerColor;

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
                      Icon(icon.data, size: 72, color: iconColor),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
