import 'dart:async';
import 'dart:io';

import 'package:cwatch/shared/theme/distro_data.dart';

/// Quick CLI helper to probe distro detection/icon mapping for running Docker
/// containers (useful with compose/distro-playground).
Future<void> main() async {
  final containers = await _listContainers();
  if (containers.isEmpty) {
    stdout.writeln('No running containers found.');
    return;
  }

  stdout.writeln('Probing ${containers.length} containers...\n');
  for (final container in containers) {
    try {
      final slug = await _detectSlug(container.id);
      final label = labelForDistro(slug);
      final codePoint = codePointForDistro(slug);
      final glyph = String.fromCharCode(codePoint);
      stdout.writeln(
        '[glyph: ${glyph}] ${container.name} (${container.image}) -> '
        '${slug ?? 'unknown'} | $label | icon 0x${codePoint.toRadixString(16)}',
      );
    } catch (error, stack) {
      stderr.writeln(
        'Failed to probe ${container.name} (${container.id}): $error\n$stack',
      );
    }
  }
}

class _ContainerInfo {
  _ContainerInfo({required this.id, required this.image, required this.name});

  final String id;
  final String image;
  final String name;
}

Future<List<_ContainerInfo>> _listContainers() async {
  final result = await Process.run(
    'docker',
    ['ps', '--format', '{{.ID}}|{{.Image}}|{{.Names}}'],
  );
  if (result.exitCode != 0) {
    stderr.writeln('docker ps failed: ${result.stderr}');
    return [];
  }
  final lines = (result.stdout as String).trim().split('\n');
  return lines
      .where((line) => line.trim().isNotEmpty)
      .map((line) {
        final parts = line.split('|');
        final id = parts.isNotEmpty ? parts[0] : '';
        final image = parts.length > 1 ? parts[1] : '';
        final name = parts.length > 2 ? parts[2] : '';
        return _ContainerInfo(id: id, image: image, name: name);
      })
      .where((c) => c.id.isNotEmpty)
      .toList();
}

Future<String?> _detectSlug(String containerId) async {
  // Try os-release, then fall back to uname.
  final release = await _readOsRelease(containerId);
  if (release != null) {
    final slug = _slugFromRelease(release);
    if (slug != null) return slug;
  }
  final uname = await _runUname(containerId);
  return uname != null ? normalizeDistroSlug(uname) : null;
}

Future<Map<String, String>?> _readOsRelease(String containerId) async {
  final result = await _runInContainer(
    containerId,
    ['cat', '/etc/os-release'],
  );
  if (result == null) return null;
  final lines = result.split('\n');
  final map = <String, String>{};
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || !line.contains('=')) continue;
    final parts = line.split('=');
    final key = parts.removeAt(0).trim();
    if (key.isEmpty) continue;
    final value = parts.join('=').trim();
    if (value.isEmpty) continue;
    map[key] = _stripQuotes(value);
  }
  return map.isEmpty ? null : map;
}

String? _slugFromRelease(Map<String, String> release) {
  final id = release['ID'];
  if (id != null && id.isNotEmpty) {
    final slug = normalizeDistroSlug(id);
    if (slug != null) return slug;
  }
  final idLike = release['ID_LIKE'];
  if (idLike != null && idLike.isNotEmpty) {
    final parts = idLike.split(RegExp(r'[\s,]+'));
    for (final part in parts) {
      final slug = normalizeDistroSlug(part);
      if (slug != null) return slug;
    }
  }
  final name = release['NAME'] ?? release['PRETTY_NAME'];
  if (name != null && name.isNotEmpty) {
    return normalizeDistroSlug(name);
  }
  return null;
}

Future<String?> _runUname(String containerId) =>
    _runInContainer(containerId, ['uname', '-s']);

Future<String?> _runInContainer(
  String containerId,
  List<String> args, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final process = Process.run(
    'docker',
    ['exec', containerId, ...args],
  );
  try {
    final result = await process.timeout(timeout);
    if (result.exitCode != 0) {
      return null;
    }
    final output = (result.stdout as String).trim();
    return output.isEmpty ? null : output;
  } on TimeoutException {
    return null;
  }
}

String _stripQuotes(String value) {
  var trimmed = value.trim();
  if (trimmed.length >= 2) {
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith('\'') && trimmed.endsWith('\''))) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }
  }
  return trimmed;
}
