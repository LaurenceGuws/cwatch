import 'dart:io';

import '../../models/ssh_host.dart';
import 'config_sources/config_source.dart';
import 'ssh_config_parser.dart';

class SshConfigService {
  SshConfigService({
    SshConfigSource? source,
    SshConfigParser? parser,
  })  : _source = source ?? SshConfigSource.forPlatform(),
        _parser = parser ?? const SshConfigParser();

  final SshConfigSource _source;
  final SshConfigParser _parser;

  Future<List<SshHost>> loadHosts() async {
    final visited = <String>{};
    final hosts = <ParsedHost>[];
    final entryPoints = await _source.entryPoints();

    for (final entry in entryPoints) {
      hosts.addAll(await _parser.collectEntries(entry, visited));
    }

    return Future.wait(hosts.map((entry) async {
      final online = await _checkAvailability(entry.hostname, entry.port);
      return SshHost(
        name: entry.name,
        hostname: entry.hostname,
        port: entry.port,
        available: online,
      );
    }));
  }

  Future<bool> _checkAvailability(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
