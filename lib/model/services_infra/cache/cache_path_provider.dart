import 'dart:io';

import 'package:path/path.dart' as p;

import '../logging/app_logger.dart';

class CachePathProvider {
  const CachePathProvider();

  Future<String> cacheFilePath({String fileName = 'cache.json'}) async {
    final directory = await cacheDirectory();
    return p.join(directory, fileName);
  }

  Future<String> cacheDirectory() async {
    final env = Platform.environment;

    if (Platform.isWindows) {
      final base = env['LOCALAPPDATA'] ?? env['APPDATA'];
      if (base != null) {
        return p.join(base, 'CWatch', 'Cache');
      }
    }

    if (Platform.isMacOS) {
      final home = env['HOME'];
      if (home != null) {
        return p.join(home, 'Library', 'Caches', 'CWatch');
      }
    }

    final home = env['HOME'];
    if (home != null) {
      return p.join(home, '.cache', 'cwatch');
    }

    AppLogger().warn(
      'Falling back to system temp for cache directory',
      tag: 'Cache',
    );
    return p.join(Directory.systemTemp.path, 'cwatch');
  }
}
