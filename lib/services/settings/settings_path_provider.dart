import 'dart:io';

class SettingsPathProvider {
  const SettingsPathProvider();

  Future<String> configFilePath() async {
    final directory = await configDirectory();
    return '$directory${Platform.pathSeparator}settings.json';
  }

  Future<String> configDirectory() async {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? env['LOCALAPPDATA'];
      if (base != null) {
        return _join(base, ['CWatch']);
      }
    }
    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null) {
        return _join(home, ['Library', 'Application Support', 'CWatch']);
      }
    }
    final home = env['HOME'];
    if (home != null) {
      return _join(home, ['.config', 'cwatch']);
    }
    return _join(Directory.systemTemp.path, ['cwatch']);
  }

  String _join(String root, List<String> parts) {
    final buffer = StringBuffer(root);
    for (final part in parts) {
      buffer
        ..write(Platform.pathSeparator)
        ..write(part);
    }
    return buffer.toString();
  }
}
