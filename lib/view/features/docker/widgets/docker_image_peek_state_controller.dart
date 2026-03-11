import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/docker_image.dart';

class DockerImageGroupRow {
  const DockerImageGroupRow({
    required this.repository,
    required this.images,
  });

  final String repository;
  final List<DockerImage> images;

  String get displayName => repository.isNotEmpty ? repository : '<none>';
  int get tagCount => images.length;
  String get totalSize => _displayGroupSize(images);

  static String _displayGroupSize(List<DockerImage> images) {
    if (images.isEmpty) return '—';
    if (images.length == 1) return images.first.size;
    return '${images.length} tag${images.length == 1 ? '' : 's'}';
  }
}

class DockerImagePeekStateController {
  final Map<String, ValueNotifier<bool>> _expandedRows = {};

  List<DockerImageGroupRow> buildRows(List<DockerImage> images) {
    final groups = <String, List<DockerImage>>{};
    for (final image in images) {
      final key = image.repository.isNotEmpty ? image.repository : '<none>';
      groups.putIfAbsent(key, () => []).add(image);
    }
    final keys = groups.keys.toList()..sort();
    final rows = [
      for (final key in keys)
        DockerImageGroupRow(repository: key, images: groups[key]!)
    ];
    syncExpandedRows(rows);
    return rows;
  }

  ValueNotifier<bool> expansionFor(String repository) {
    return _expandedRows.putIfAbsent(
      repository,
      () => ValueNotifier<bool>(false),
    );
  }

  void syncExpandedRows(List<DockerImageGroupRow> rows) {
    if (_expandedRows.isEmpty) {
      return;
    }
    final active = rows.map((row) => row.repository).toSet();
    final staleKeys = _expandedRows.keys
        .where((repository) => !active.contains(repository))
        .toList();
    for (final repository in staleKeys) {
      _expandedRows.remove(repository)?.dispose();
    }
  }

  int totalTags(List<DockerImage> images) => images.length;

  int totalRepositories(List<DockerImageGroupRow> rows) => rows.length;

  String calculateTotalSize(List<DockerImage> images) {
    if (images.isEmpty) return '0 B';

    double totalBytes = 0;
    var parsedCount = 0;
    for (final image in images) {
      final bytes = _parseSizeToBytes(image.size);
      if (bytes == null) {
        continue;
      }
      totalBytes += bytes;
      parsedCount++;
    }

    if (parsedCount == 0) return '—';
    return _formatBytes(totalBytes);
  }

  double? _parseSizeToBytes(String size) {
    final trimmed = size.trim();
    if (trimmed.isEmpty || trimmed == '—') return null;

    final match = RegExp(
      r'^([\d.]+)\s*([KMGT]?B)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return null;

    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;

    switch ((match.group(2) ?? 'B').toUpperCase()) {
      case 'B':
        return value;
      case 'KB':
        return value * 1024;
      case 'MB':
        return value * 1024 * 1024;
      case 'GB':
        return value * 1024 * 1024 * 1024;
      case 'TB':
        return value * 1024 * 1024 * 1024 * 1024;
      default:
        return null;
    }
  }

  String _formatBytes(double bytes) {
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB';
  }

  void dispose() {
    for (final notifier in _expandedRows.values) {
      notifier.dispose();
    }
    _expandedRows.clear();
  }
}
