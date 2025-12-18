import 'dart:async';

import 'package:cwatch/shared/theme/distro_icons.dart';

typedef DistroCommandRunner =
    Future<String> Function(String command, {Duration? timeout});

class DistroDetector {
  const DistroDetector(this.runner);

  final DistroCommandRunner runner;

  Future<String?> detect({
    Duration osReleaseTimeout = const Duration(seconds: 6),
    Duration unameTimeout = const Duration(seconds: 4),
  }) async {
    final release = await _readOsRelease(osReleaseTimeout);
    final slug = release != null ? _slugFromRelease(release) : null;
    if (slug != null) {
      return slug;
    }
    final uname = await _runUname(unameTimeout);
    return uname != null ? _slugFromUname(uname) : null;
  }

  Future<Map<String, String>?> _readOsRelease(Duration timeout) async {
    try {
      final output = await runner('cat /etc/os-release', timeout: timeout);
      final lines = output.split('\n');
      final result = <String, String>{};
      for (final rawLine in lines) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty || !trimmed.contains('=')) {
          continue;
        }
        final parts = trimmed.split('=');
        final key = parts.removeAt(0).trim();
        if (key.isEmpty) {
          continue;
        }
        final value = parts.join('=').trim();
        if (value.isEmpty) {
          continue;
        }
        result[key] = _stripQuotes(value);
      }
      if (result.isEmpty) {
        return null;
      }
      return result;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _runUname(Duration timeout) async {
    try {
      final output = await runner('uname -s', timeout: timeout);
      final trimmed = output.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _slugFromRelease(Map<String, String> release) {
    final id = release['ID'];
    if (id != null && id.isNotEmpty) {
      final slug = normalizeDistroSlug(id);
      if (slug != null) {
        return slug;
      }
    }
    final idLike = release['ID_LIKE'];
    if (idLike != null && idLike.isNotEmpty) {
      final parts = idLike.split(RegExp(r'[\s,]+'));
      for (final part in parts) {
        final slug = normalizeDistroSlug(part);
        if (slug != null) {
          return slug;
        }
      }
    }
    final name = release['NAME'] ?? release['PRETTY_NAME'];
    if (name != null && name.isNotEmpty) {
      return normalizeDistroSlug(name);
    }
    return null;
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

  String? _slugFromUname(String uname) {
    final lower = uname.toLowerCase();
    if (lower.contains('windows') ||
        lower.contains('mingw') ||
        lower.contains('msys')) {
      return 'windows';
    }
    if (lower.contains('darwin') || lower.contains('mac')) {
      return 'darwin';
    }
    if (lower.contains('linux')) {
      return 'linux';
    }
    return normalizeDistroSlug(uname);
  }
}
