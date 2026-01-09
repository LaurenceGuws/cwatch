import 'dart:io';

import 'package:path/path.dart' as p;

class RemoteEditorCache {
  RemoteEditorCache() : _baseDir = _resolveBaseDir();

  final Directory _baseDir;

  static Directory _resolveBaseDir() {
    final env = Platform.environment;
    String basePath;
    if (Platform.isWindows) {
      basePath =
          env['APPDATA'] ?? env['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    } else {
      basePath = env['HOME'] ?? Directory.systemTemp.path;
      basePath = p.join(basePath, '.cache');
    }
    final dir = Directory(p.join(basePath, 'cwatch', 'editor_cache'));
    dir.createSync(recursive: true);
    return dir;
  }

  Future<File> materialize({
    required String host,
    required String remotePath,
    required String contents,
  }) async {
    final safeName = _safeName(host, remotePath);
    final file = File(p.join(_baseDir.path, '$safeName-preview.txt'));
    await file.writeAsString(contents);
    return file;
  }

  Future<CachedEditorSession> createSession({
    required String host,
    required String remotePath,
    required String contents,
  }) async {
    final safeName = _safeName(host, remotePath);
    final dir = Directory(p.join(_baseDir.path, safeName));
    await dir.create(recursive: true);
    final fileName = _fileName(remotePath);
    final snapshot = File(p.join(dir.path, '$fileName.server'));
    final working = File(p.join(dir.path, fileName));
    await snapshot.writeAsString(contents);
    await working.writeAsString(contents);
    return CachedEditorSession(
      snapshotPath: snapshot.path,
      workingPath: working.path,
    );
  }

  Future<CachedEditorSession?> loadSession({
    required String host,
    required String remotePath,
  }) async {
    final safeName = _safeName(host, remotePath);
    final dir = Directory(p.join(_baseDir.path, safeName));
    if (!await dir.exists()) {
      return null;
    }
    final fileName = _fileName(remotePath);
    final snapshot = File(p.join(dir.path, '$fileName.server'));
    final working = File(p.join(dir.path, fileName));
    if (await snapshot.exists() && await working.exists()) {
      return CachedEditorSession(
        snapshotPath: snapshot.path,
        workingPath: working.path,
      );
    }
    return null;
  }

  Future<void> clearSession({
    required String host,
    required String remotePath,
  }) async {
    final safeName = _safeName(host, remotePath);
    final dir = Directory(p.join(_baseDir.path, safeName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String _safeName(String host, String remotePath) {
    final cleanHost = host.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cleanPath = remotePath.replaceAll(RegExp(r'[/:*?"<>|]'), '_');
    return '$cleanHost-$cleanPath';
  }

  String _fileName(String remotePath) {
    final base = p.basename(remotePath).trim();
    if (base.isEmpty || base == '/' || base == '.') {
      return 'file.txt';
    }
    return base;
  }
}

class CachedEditorSession {
  const CachedEditorSession({
    required this.snapshotPath,
    required this.workingPath,
  });

  final String snapshotPath;
  final String workingPath;
}
