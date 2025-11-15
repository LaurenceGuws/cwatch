import 'package:flutter/material.dart';

import 'models/ssh_host.dart';
import 'services/settings/app_settings_controller.dart';
import 'services/ssh/ssh_config_service.dart';
import 'ui/views/docker/docker_view.dart';
import 'ui/views/kubernetes/kubernetes_view.dart';
import 'ui/views/servers/servers_view.dart';
import 'ui/views/settings/settings_view.dart';

void main() {
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
        return MaterialApp(
          title: 'CWatch',
          themeMode: settings.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
            useMaterial3: true,
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
  const HomeShell({
    required this.settingsController,
    super.key,
  });

  final AppSettingsController settingsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<List<SshHost>> _hostsFuture;
  ShellDestination _selectedDestination = ShellDestination.servers;

  @override
  void initState() {
    super.initState();
    _hostsFuture = SshConfigService().loadHosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Control Center'),
      ),
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
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedDestination) {
      case ShellDestination.servers:
        return ServersView(hostsFuture: _hostsFuture);
      case ShellDestination.docker:
        return const DockerView();
      case ShellDestination.kubernetes:
        return const KubernetesView();
      case ShellDestination.settings:
        return SettingsView(controller: widget.settingsController);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelect(ShellDestination.values[index]),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.computer_outlined),
          selectedIcon: Icon(Icons.computer_rounded),
          label: Text('Servers'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.dns_outlined),
          selectedIcon: Icon(Icons.dns),
          label: Text('Docker'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: Text('Kubernetes'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

enum ShellDestination { servers, docker, kubernetes, settings }
