import 'package:flutter/material.dart';

class HomeShellPageCache {
  final Map<String, Widget> _cache = {};

  void evictAllExcept(String destination) {
    _cache.removeWhere((key, _) => key != destination);
  }

  Widget? pageFor(String destination) => _cache[destination];

  Widget ensurePageCached({
    required String destination,
    required Widget Function() buildPage,
  }) {
    return _cache.putIfAbsent(destination, buildPage);
  }
}
