import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/cache/cache_storage.dart';

/// Small helper to cache and restore ready remote endpoints (e.g., Docker hosts).
///
/// This uses the app's cache file (not `settings.json`) because it's derived
/// state that can be rebuilt by rescanning.
class RemoteEndpointCache {
  const RemoteEndpointCache({
    required this.storage,
    this.key = 'dockerRemoteHosts',
  });

  final CacheStorage storage;
  final String key;

  Future<List<String>> read() => storage.readStringList(key);

  Future<void> persist(List<String> names) async {
    final next = names.toSet().toList()..sort();
    final current = await read();
    final currentSorted = [...current]..sort();
    if (_listEquals(next, currentSorted)) {
      return;
    }
    await storage.writeStringList(key, next);
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
