import 'dart:convert';

import '../../models/remote_file_entry.dart';

List<RemoteFileEntry> parseLsOutput(String stdout) {
  final lines = const LineSplitter().convert(stdout);

  final entries = <RemoteFileEntry>[];
  for (final line in lines) {
    if (line.isEmpty || line.startsWith('total')) {
      continue;
    }
    final parsed = _parseLsLine(line);
    if (parsed != null) {
      entries.add(parsed);
    }
  }
  return entries;
}

RemoteFileEntry? _parseLsLine(String line) {
  final pattern = RegExp(
    r'^([\-ldcbps])([rwx\-]{9})\s+\d+\s+\S+\s+\S+\s+(\d+)\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(.+)$',
  );
  final match = pattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  final typeFlag = match.group(1)!;
  final size = int.tryParse(match.group(3) ?? '') ?? 0;
  final modified = DateTime.tryParse(match.group(4) ?? '') ?? DateTime.now();
  var name = match.group(5) ?? '';
  if (typeFlag == 'l') {
    final parts = name.split(' -> ');
    name = parts.first;
  }
  final isDirectory = typeFlag == 'd' || typeFlag == 'l';
  return RemoteFileEntry(
    name: name,
    isDirectory: isDirectory,
    sizeBytes: size,
    modified: modified,
  );
}
