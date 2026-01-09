import 'dart:io';

abstract class SshConfigSource {
  const SshConfigSource();

  /// Entrypoint config files to parse (e.g., ~/.ssh/config, /etc/ssh/ssh_config).
  Future<List<String>> entryPoints();

  static SshConfigSource forPlatform() {
    if (Platform.isMacOS || Platform.isLinux) {
      return const UnixSshConfigSource();
    }
    if (Platform.isWindows) {
      return const WindowsSshConfigSource();
    }
    return const UnixSshConfigSource();
  }
}

class UnixSshConfigSource extends SshConfigSource {
  const UnixSshConfigSource();

  @override
  Future<List<String>> entryPoints() async {
    final home = Platform.environment['HOME'];
    final paths = <String>[];
    if (home != null) {
      paths.add('$home/.ssh/config');
    }
    paths.add('/etc/ssh/ssh_config');
    return paths;
  }
}

class WindowsSshConfigSource extends SshConfigSource {
  const WindowsSshConfigSource();

  @override
  Future<List<String>> entryPoints() async {
    final paths = <String>[];
    final userProfile = Platform.environment['USERPROFILE'];
    final programData = Platform.environment['PROGRAMDATA'];
    if (userProfile != null) {
      paths.add('$userProfile/.ssh/config');
    }
    if (programData != null) {
      paths.add('$programData/ssh/ssh_config');
    }
    return paths;
  }
}
