import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache_storage.dart';

class DistroCacheController extends ChangeNotifier {
  DistroCacheController({
    CacheStorage? storage,
    Map<String, String> initialServerCache = const {},
    Map<String, String> initialDockerCache = const {},
  }) : _storage = storage ?? CacheStorage(),
       _serverCache = Map<String, String>.from(initialServerCache),
       _dockerCache = Map<String, String>.from(initialDockerCache) {
    unawaited(_ensureLoaded());
  }

  static const _serverKey = 'serverDistroMap';
  static const _dockerKey = 'dockerDistroMap';

  final CacheStorage _storage;
  final Map<String, String> _serverCache;
  final Map<String, String> _dockerCache;

  Future<void>? _loadFuture;

  String? serverSlug(String key) => _serverCache[key];
  String? dockerSlug(String key) => _dockerCache[key];

  bool hasServer(String key) => _serverCache.containsKey(key);
  bool hasDocker(String key) => _dockerCache.containsKey(key);

  Future<void> putServer(String key, String slug) async {
    await _ensureLoaded();
    if (_serverCache[key] == slug) return;
    _serverCache[key] = slug;
    await _storage.writeStringMap(_serverKey, _serverCache);
    notifyListeners();
  }

  Future<void> putDocker(String key, String slug) async {
    await _ensureLoaded();
    if (_dockerCache[key] == slug) return;
    _dockerCache[key] = slug;
    await _storage.writeStringMap(_dockerKey, _dockerCache);
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    final pending = _loadFuture;
    if (pending != null) {
      await pending;
      return;
    }
    final future = _hydrate();
    _loadFuture = future;
    await future;
    _loadFuture = null;
  }

  Future<void> _hydrate() async {
    final server = await _storage.readStringMap(_serverKey);
    final docker = await _storage.readStringMap(_dockerKey);

    var changed = false;
    if (server.isNotEmpty) {
      _serverCache
        ..clear()
        ..addAll(server);
      changed = true;
    } else if (_serverCache.isNotEmpty) {
      await _storage.writeStringMap(_serverKey, _serverCache);
    }

    if (docker.isNotEmpty) {
      _dockerCache
        ..clear()
        ..addAll(docker);
      changed = true;
    } else if (_dockerCache.isNotEmpty) {
      await _storage.writeStringMap(_dockerKey, _dockerCache);
    }

    if (changed) {
      notifyListeners();
    }
  }
}
