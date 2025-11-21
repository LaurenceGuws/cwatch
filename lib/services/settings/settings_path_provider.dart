import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SettingsPathProvider {
  const SettingsPathProvider();

  Future<String> configFilePath() async {
    final directory = await configDirectory();
    return p.join(directory, 'settings.json');
  }

  Future<String> configDirectory() async {
    // Prefer platform-safe app support dirs on mobile to survive updates.
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final dir = await getApplicationSupportDirectory();
        return dir.path;
      } catch (_) {
        // Fall back to legacy paths below.
      }
    }

    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? env['LOCALAPPDATA'];
      if (base != null) {
        return p.join(base, 'CWatch');
      }
    }
    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null) {
        return p.join(home, 'Library', 'Application Support', 'CWatch');
      }
    }
    final home = env['HOME'];
    if (home != null) {
      return p.join(home, '.config', 'cwatch');
    }
    return p.join(Directory.systemTemp.path, 'cwatch');
  }

  /// Legacy paths we previously used; used for one-time migration.
  Future<List<String>> legacyConfigPaths() async {
    final paths = <String>[];
    final env = Platform.environment;
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? env['LOCALAPPDATA'];
      if (base != null) {
        paths.add(p.join(base, 'CWatch', 'settings.json'));
      }
    } else if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null) {
        paths.add(
          p.join(home, 'Library', 'Application Support', 'CWatch', 'settings.json'),
        );
      }
    } else {
      final home = env['HOME'];
      if (home != null) {
        paths.add(p.join(home, '.config', 'cwatch', 'settings.json'));
        paths.add(p.join(home, '.cache', 'cwatch', 'settings.json'));
      }
    }
    // Keep system temp as last resort.
    paths.add(p.join(Directory.systemTemp.path, 'cwatch', 'settings.json'));
    return paths;
  }
}
