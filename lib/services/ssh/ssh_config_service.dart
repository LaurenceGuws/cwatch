import 'dart:io';

import '../../models/custom_ssh_host.dart';
import '../../models/ssh_host.dart';
import 'config_sources/config_source.dart';
import 'ssh_config_parser.dart';

class SshConfigService {
  SshConfigService({
    SshConfigSource? source,
    SshConfigParser? parser,
    List<CustomSshHost> customHosts = const [],
  })  : _source = source ?? SshConfigSource.forPlatform(),
        _parser = parser ?? const SshConfigParser(),
        _customHosts = customHosts;

  final SshConfigSource _source;
  final SshConfigParser _parser;
  final List<CustomSshHost> _customHosts;

  Future<List<SshHost>> loadHosts() async {
    final visited = <String>{};
    final hostsWithSource = <({ParsedHost host, String source})>[];
    final entryPoints = await _source.entryPoints();

    for (final entryPoint in entryPoints) {
      final hosts = await _parser.collectEntries(entryPoint, visited);
      for (final host in hosts) {
        // Use the actual source path from the parsed host (which tracks includes)
        hostsWithSource.add((host: host, source: host.sourcePath));
      }
    }

    // Add custom hosts
    for (final customHost in _customHosts) {
      hostsWithSource.add((
        host: ParsedHost(
          name: customHost.name,
          hostname: customHost.hostname,
          port: customHost.port,
          user: customHost.user,
          identityFiles: customHost.identityFile != null
              ? [customHost.identityFile!]
              : [],
          sourcePath: 'custom',
        ),
        source: 'custom',
      ));
    }

    return Future.wait(
      hostsWithSource.map((entry) async {
        final online = await _checkAvailability(
          entry.host.hostname,
          entry.host.port,
        );
        return SshHost(
          name: entry.host.name,
          hostname: entry.host.hostname,
          port: entry.host.port,
          available: online,
          user: entry.host.user,
          identityFiles: entry.host.identityFiles,
          source: entry.source,
        );
      }),
    );
  }

  Future<bool> _checkAvailability(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
