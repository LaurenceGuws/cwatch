import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../settings/settings_path_provider.dart';

class KnownHostEntry {
  KnownHostEntry({
    required this.host,
    required this.type,
    required this.fingerprint,
  });

  final String host;
  final String type;
  final String fingerprint;
}

class KnownHostVerificationResult {
  const KnownHostVerificationResult({
    required this.accepted,
    required this.added,
  });

  final bool accepted;
  final bool added;
}

/// Minimal fingerprint-based store for host keys used by the built-in backend.
/// We store MD5 fingerprints so we can validate with dartssh2's verifier, which
/// only surfaces fingerprints rather than full host key material.
class KnownHostsStore {
  const KnownHostsStore({SettingsPathProvider? pathProvider})
      : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;
  static const _fileName = 'known_hosts_fingerprints';

  Future<String> ensureStorePath() async {
    final dir = await _pathProvider.configDirectory();
    final file = File(p.join(dir, _fileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file.path;
  }

  Future<List<KnownHostEntry>> loadEntries() async {
    final path = await ensureStorePath();
    final file = File(path);
    final entries = <KnownHostEntry>[];
    if (!await file.exists()) {
      return entries;
    }
    final lines = const LineSplitter()
        .convert(await file.readAsString())
        .where((line) => line.trim().isNotEmpty && !line.trim().startsWith('#'));
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\\s+'));
      if (parts.length < 3) continue;
      entries.add(
        KnownHostEntry(
          host: parts[0],
          type: parts[1],
          fingerprint: parts[2],
        ),
      );
    }
    return entries;
  }

  Future<KnownHostVerificationResult> verifyAndRecord({
    required String host,
    required String type,
    required String fingerprint,
    bool acceptNew = true,
  }) async {
    final entries = await loadEntries();
    final existingIndex =
        entries.indexWhere((entry) => _hostsEqual(entry.host, host));
    if (existingIndex != -1) {
      final existing = entries[existingIndex];
      if (existing.fingerprint == fingerprint && existing.type == type) {
        return const KnownHostVerificationResult(accepted: true, added: false);
      }
      return const KnownHostVerificationResult(accepted: false, added: false);
    }
    if (!acceptNew) {
      return const KnownHostVerificationResult(accepted: false, added: false);
    }
    entries.add(
      KnownHostEntry(host: host, type: type, fingerprint: fingerprint),
    );
    await _writeEntries(entries);
    return const KnownHostVerificationResult(accepted: true, added: true);
  }

  Future<void> _writeEntries(List<KnownHostEntry> entries) async {
    final path = await ensureStorePath();
    final file = File(path);
    final buffer = StringBuffer();
    for (final entry in entries) {
      buffer.writeln('${entry.host} ${entry.type} ${entry.fingerprint}');
    }
    await file.writeAsString(buffer.toString());
  }

  bool _hostsEqual(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }
}
