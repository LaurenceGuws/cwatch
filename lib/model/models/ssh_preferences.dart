import 'custom_ssh_host.dart';
import 'ssh_client_backend.dart';

class SshPreferences {
  const SshPreferences({
    this.clientBackend = SshClientBackend.platform,
    this.builtinHostKeyBindings = const {},
    this.customHosts = const [],
    this.customConfigPaths = const [],
    this.disabledConfigPaths = const [],
    this.disabledServerHosts = const [],
  });

  final SshClientBackend clientBackend;
  final Map<String, String> builtinHostKeyBindings;
  final List<CustomSshHost> customHosts;
  final List<String> customConfigPaths;
  final List<String> disabledConfigPaths;
  final List<String> disabledServerHosts;

  SshPreferences copyWith({
    SshClientBackend? clientBackend,
    Map<String, String>? builtinHostKeyBindings,
    List<CustomSshHost>? customHosts,
    List<String>? customConfigPaths,
    List<String>? disabledConfigPaths,
    List<String>? disabledServerHosts,
  }) {
    return SshPreferences(
      clientBackend: clientBackend ?? this.clientBackend,
      builtinHostKeyBindings:
          builtinHostKeyBindings ?? this.builtinHostKeyBindings,
      customHosts: customHosts ?? this.customHosts,
      customConfigPaths: customConfigPaths ?? this.customConfigPaths,
      disabledConfigPaths: disabledConfigPaths ?? this.disabledConfigPaths,
      disabledServerHosts: disabledServerHosts ?? this.disabledServerHosts,
    );
  }
}
