import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

class GrammarRecord {
  GrammarRecord({
    required this.name,
    required this.owner,
    required this.repo,
    required this.url,
  });

  final String name;
  final String owner;
  final String repo;
  final String url;

  String get repository => '$owner/$repo';

  factory GrammarRecord.fromRow(List<dynamic> row) {
    final name = row[0].toString().trim().toLowerCase();
    final rawUrl = row[1].toString().trim();
    final normalized = _normalizeUrl(rawUrl);
    final parts = normalized.split('/');
    if (parts.length < 2) {
      throw FormatException('Invalid repository url: $rawUrl');
    }
    final owner = parts[0];
    final repo = parts[1].replaceAll('.git', '');
    return GrammarRecord(name: name, owner: owner, repo: repo, url: normalized);
  }

  static String _normalizeUrl(String input) {
    var value = input;
    if (value.startsWith('http')) {
      value = value.replaceFirst(RegExp(r'^https?://'), '');
    }
    if (value.startsWith('github.com/')) {
      value = value.substring('github.com/'.length);
    }
    return value;
  }
}

class GrammarManifest {
  GrammarManifest._();

  static const String defaultAssetPath = 'assets/data/grammers.csv';
  static Map<String, GrammarRecord>? _records;

  static Future<void> initialize([String assetPath = defaultAssetPath]) async {
    if (_records != null) return;
    final csvData = await rootBundle.loadString(assetPath);
    _records = _parse(csvData);
  }

  static Map<String, GrammarRecord> _parse(String csvContent) {
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);
    if (rows.isEmpty) {
      return {};
    }
    final map = <String, GrammarRecord>{};
    for (final row in rows.skip(1)) {
      if (row.length < 2) continue;
      final name = row[0].toString().trim().toLowerCase();
      if (name.isEmpty) continue;
      try {
        map.putIfAbsent(name, () => GrammarRecord.fromRow(row));
      } catch (_) {
        // Ignore malformed lines.
      }
    }
    return map;
  }

  static GrammarRecord? lookup(String name) {
    final records = _records;
    if (records == null) {
      throw StateError(
        'GrammarManifest.initialize() must be called before lookup',
      );
    }
    return records[name];
  }
}
