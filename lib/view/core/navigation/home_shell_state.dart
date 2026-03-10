import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/ssh_config_service.dart';
import 'home_shell_page_cache.dart';

class HomeShellState {
  HomeShellState();

  Future<List<SshHost>> hostsFuture = Future.value(const []);
  String selectedDestination = 'servers';
  bool sidebarCollapsed = false;
  bool shellStateRestored = false;
  bool paletteOpen = false;
  SidebarPlacement sidebarPlacement = SidebarPlacement.dynamic;
  final HomeShellPageCache pageCache = HomeShellPageCache();
  String? hostsSettingsSignature;
  bool isWindowMaximized = false;
  bool closeToTrayEnabled = false;

  void refreshHosts(AppSettings settings) {
    final ssh = settings.sshPreferences;
    hostsFuture = SshConfigService(
      customHosts: ssh.customHosts,
      additionalEntryPoints: ssh.customConfigPaths,
      disabledEntryPoints: ssh.disabledConfigPaths,
    ).loadHosts(checkAvailability: false);
  }

  String hostSettingsSignature(AppSettings settings) {
    final ssh = settings.sshPreferences;
    final hosts = ssh.customHosts
        .map(
          (host) =>
              '${host.name}|${host.hostname}|${host.port}|${host.user ?? ''}|${host.identityFile ?? ''}',
        )
        .join(';');
    final customConfigs = List<String>.from(ssh.customConfigPaths)
      ..sort();
    final disabledConfigs = List<String>.from(ssh.disabledConfigPaths)
      ..sort();
    return [
      hosts,
      customConfigs.join(';'),
      disabledConfigs.join(';'),
    ].join('::');
  }

  SidebarPlacement placementFromString(String? value) {
    switch (value) {
      case 'left':
        return SidebarPlacement.left;
      case 'right':
        return SidebarPlacement.right;
      case 'bottom':
        return SidebarPlacement.bottom;
      default:
        return SidebarPlacement.dynamic;
    }
  }

  String placementToString(SidebarPlacement placement) {
    switch (placement) {
      case SidebarPlacement.dynamic:
        return 'dynamic';
      case SidebarPlacement.left:
        return 'left';
      case SidebarPlacement.right:
        return 'right';
      case SidebarPlacement.bottom:
        return 'bottom';
    }
  }
}

enum SidebarPlacement { dynamic, left, right, bottom }
