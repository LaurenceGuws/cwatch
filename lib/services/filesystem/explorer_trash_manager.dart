import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../models/ssh_host.dart';
import '../ssh/remote_shell_service.dart';

class ExplorerTrashManager {
  ExplorerTrashManager() : _baseDir = _resolveBaseDir();

  final Directory _baseDir;
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  final ValueNotifier<TrashRestoreEvent?> _restoreNotifier =
      ValueNotifier<TrashRestoreEvent?>(null);

  static Directory _resolveBaseDir() {
    final env = Platform.environment;
    String basePath;
    if (Platform.isWindows) {
      basePath = env['APPDATA'] ?? env['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    } else {
      basePath = env['HOME'] ?? Directory.systemTemp.path;
      basePath = p.join(basePath, '.cache');
    }
    final dir = Directory(p.join(basePath, 'cwatch', 'trash'));
    dir.createSync(recursive: true);
    return dir;
  }

  ValueListenable<int> get changes => _changes;
  ValueListenable<TrashRestoreEvent?> get restoreEvents => _restoreNotifier;

  Future<TrashedEntry> moveToTrash({
    required RemoteShellService shellService,
    required SshHost host,
    required String remotePath,
    required bool isDirectory,
    bool notify = true,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final entryDir = Directory(p.join(_baseDir.path, id));
    await entryDir.create(recursive: true);
    await shellService.downloadPath(
      host: host,
      remotePath: remotePath,
      localDestination: entryDir.path,
      recursive: isDirectory,
    );
    final payloadName = p.basename(remotePath);
    final payloadPath = p.join(entryDir.path, payloadName);
    final sizeBytes = await _computeSize(payloadPath);
    final entry = TrashedEntry(
      id: id,
      host: host,
      remotePath: remotePath,
      displayName: payloadName,
      isDirectory: isDirectory,
      trashedAt: DateTime.now(),
      localPath: payloadPath,
      sizeBytes: sizeBytes,
      storagePath: entryDir.path,
    );
    final metaFile = File(p.join(entryDir.path, 'meta.json'));
    await metaFile.writeAsString(jsonEncode(entry.toJson()));
    if (notify) {
      _notifyChanged();
    }
    return entry;
  }

  Future<List<TrashedEntry>> loadEntries() async {
    if (!await _baseDir.exists()) {
      return [];
    }
    final entries = <TrashedEntry>[];
    await for (final entity in _baseDir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final metaFile = File(p.join(entity.path, 'meta.json'));
      if (!await metaFile.exists()) {
        continue;
      }
      try {
        final contents = await metaFile.readAsString();
        final jsonMap = jsonDecode(contents);
        if (jsonMap is Map<String, dynamic>) {
          entries.add(TrashedEntry.fromJson(jsonMap, storagePath: entity.path));
        }
      } catch (_) {
        continue;
      }
    }
    return entries;
  }

  Future<void> deleteEntry(TrashedEntry entry, {bool notify = true}) async {
    final dir = Directory(entry.storagePath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    if (notify) {
      _notifyChanged();
    }
  }

  Future<void> restoreEntry({
    required TrashedEntry entry,
    required RemoteShellService shellService,
  }) async {
    await shellService.uploadPath(
      host: entry.host,
      localPath: entry.localPath,
      remoteDestination: entry.remotePath,
      recursive: entry.isDirectory,
    );
    _restoreNotifier.value = TrashRestoreEvent(
      hostName: entry.host.name,
      directory: _directoryOf(entry.remotePath),
      restoredPath: entry.remotePath,
    );
    await deleteEntry(entry, notify: false);
    _notifyChanged();
  }

  Future<int> _computeSize(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.file:
        final stat = await File(path).stat();
        return stat.size;
      case FileSystemEntityType.directory:
        final dir = Directory(path);
        int total = 0;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final stat = await entity.stat();
            total += stat.size;
          }
        }
        return total;
      default:
        return 0;
    }
  }

  void notifyListeners() => _notifyChanged();

  void _notifyChanged() {
    _changes.value += 1;
  }

  String _directoryOf(String path) {
    final normalized = _sanitizePath(path);
    if (normalized == '/' || !normalized.contains('/')) {
      return '/';
    }
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String _sanitizePath(String input) {
    if (input.isEmpty) {
      return '/';
    }
    if (!input.startsWith('/')) {
      return '/$input';
    }
    return input;
  }
}

class TrashedEntry {
  TrashedEntry({
    required this.id,
    required this.host,
    required this.remotePath,
    required this.displayName,
    required this.isDirectory,
    required this.trashedAt,
    required this.localPath,
    required this.sizeBytes,
    required this.storagePath,
  });

  final String id;
  final SshHost host;
  final String remotePath;
  final String displayName;
  final bool isDirectory;
  final DateTime trashedAt;
  final String localPath;
  final int sizeBytes;
  final String storagePath;

  String get hostName => host.name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host': {
        'name': host.name,
        'hostname': host.hostname,
        'port': host.port,
        'available': host.available,
      },
      'remotePath': remotePath,
      'displayName': displayName,
      'isDirectory': isDirectory,
      'trashedAt': trashedAt.toIso8601String(),
      'localPath': localPath,
      'sizeBytes': sizeBytes,
    };
  }

  factory TrashedEntry.fromJson(
    Map<String, dynamic> json, {
    required String storagePath,
  }) {
    final hostJson = json['host'] as Map<String, dynamic>?;
    final host = hostJson != null
        ? SshHost(
            name: hostJson['name'] as String? ?? 'Unknown',
            hostname: hostJson['hostname'] as String? ?? '',
            port: (hostJson['port'] as num?)?.toInt() ?? 22,
            available: hostJson['available'] as bool? ?? true,
          )
        : const SshHost(name: 'Unknown', hostname: '', port: 22, available: true);
    return TrashedEntry(
      id: json['id'] as String? ?? storagePath,
      host: host,
      remotePath: json['remotePath'] as String? ?? '/',
      displayName: json['displayName'] as String? ?? 'Unknown',
      isDirectory: json['isDirectory'] as bool? ?? false,
      trashedAt: DateTime.tryParse(json['trashedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      localPath: json['localPath'] as String? ?? storagePath,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      storagePath: storagePath,
    );
  }
}

class TrashRestoreEvent {
  const TrashRestoreEvent({
    required this.hostName,
    required this.directory,
    required this.restoredPath,
  });

  final String hostName;
  final String directory;
  final String restoredPath;
}
