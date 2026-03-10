import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../logging/app_logger.dart';
import 'cache_path_provider.dart';

class CacheStorage {
  CacheStorage({CachePathProvider? pathProvider})
    : _pathProvider = pathProvider ?? const CachePathProvider();

  final CachePathProvider _pathProvider;

  Future<List<String>> readStringList(String key) async {
    final map = await _load();
    final raw = map[key];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  Future<Map<String, String>> readStringMap(String key) async {
    final map = await _load();
    final raw = map[key];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  Future<void> writeStringList(String key, List<String> values) async {
    final map = await _load();
    map[key] = values;
    await _save(map);
  }

  Future<void> writeStringMap(String key, Map<String, String> values) async {
    final map = await _load();
    map[key] = values;
    await _save(map);
  }

  Future<Map<String, dynamic>> _load() async {
    final file = await _cacheFile();
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    try {
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load cache; starting fresh',
        tag: 'Cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return <String, dynamic>{};
  }

  Future<void> _save(Map<String, dynamic> map) async {
    final file = await _cacheFile();
    final encoded = await Isolate.run(() => jsonEncode(map));
    await file.writeAsString(encoded);
  }

  Future<File> _cacheFile() async {
    final path = await _pathProvider.cacheFilePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    return file;
  }
}
