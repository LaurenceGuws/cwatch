import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/models/ssh_host.dart';

/// Small helper to cache and restore ready remote endpoints (e.g., Docker hosts).
class RemoteEndpointCache {
  const RemoteEndpointCache({
    required this.settingsController,
    required this.readNames,
    required this.writeNames,
  });

  final AppSettingsController settingsController;
  final List<String> Function(AppSettings settings) readNames;
  final AppSettings Function(AppSettings current, List<String> names)
  writeNames;

  List<String> read() => readNames(settingsController.settings);

  Future<void> persist(List<String> names) async {
    final next = names.toSet().toList()..sort();
    final current = read();
    final currentSorted = [...current]..sort();
    if (_listEquals(next, currentSorted)) {
      return;
    }
    await settingsController.update((settings) => writeNames(settings, next));
  }

  List<SshHost> applyToHosts(List<String> names, List<SshHost> knownHosts) {
    return names
        .map((name) => _hostByName(knownHosts, name) ?? _placeholderHost(name))
        .toList();
  }

  SshHost? _hostByName(List<SshHost> hosts, String? name) {
    if (name == null) return null;
    for (final host in hosts) {
      if (host.name == name) return host;
    }
    return null;
  }

  SshHost _placeholderHost(String name) {
    return SshHost(
      name: name,
      hostname: '',
      port: 22,
      available: true,
      user: null,
      identityFiles: const <String>[],
      source: 'cached',
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
