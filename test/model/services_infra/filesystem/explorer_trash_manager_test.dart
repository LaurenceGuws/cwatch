import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/terminal_session.dart';

void main() {
  group('ExplorerTrashManager', () {
    test('moveToTrash downloads payload, stores metadata, and notifies once', () async {
      final shell = _FakeRemoteShellService();
      final manager = ExplorerTrashManager();
      var changes = 0;
      manager.changes.addListener(() => changes++);

      final entry = await manager.moveToTrash(
        shellService: shell,
        host: _host,
        context: _context,
        remotePath: '/srv/readme.md',
        isDirectory: false,
      );

      expect(shell.downloads, hasLength(1));
      expect(shell.downloads.single.remotePath, '/srv/readme.md');
      expect(shell.downloads.single.recursive, isFalse);
      expect(entry.displayName, 'readme.md');
      expect(entry.contextId, _context.id);
      expect(entry.contextKind, _context.kind);
      expect(entry.localPath, endsWith('/readme.md'));
      expect(await File(entry.localPath).readAsString(), 'payload:/srv/readme.md');
      expect(entry.sizeBytes, 'payload:/srv/readme.md'.length);
      expect(changes, 1);
      addTearDown(() => Directory(entry.storagePath).delete(recursive: true));

      final loaded = await manager.loadEntries(contextId: _context.id);
      expect(loaded, hasLength(1));
      expect(loaded.single.remotePath, '/srv/readme.md');
    });

    test('loadEntries filters by context and ignores invalid metadata', () async {
      final manager = ExplorerTrashManager();
      final trashRoot = Directory(_trashRootPath());
      await Directory(p.join(trashRoot.path, 'bad')).create(recursive: true);
      await File(p.join(trashRoot.path, 'bad', 'meta.json')).writeAsString('{bad json');
      addTearDown(() => Directory(p.join(trashRoot.path, 'bad')).delete(recursive: true));

      final matchingDir = Directory(p.join(trashRoot.path, 'match'))..createSync(recursive: true);
      final otherDir = Directory(p.join(trashRoot.path, 'other'))..createSync(recursive: true);
      addTearDown(() => matchingDir.delete(recursive: true));
      addTearDown(() => otherDir.delete(recursive: true));
      final matching = _trashedEntry(storagePath: matchingDir.path, contextId: 'ctx-a');
      final other = _trashedEntry(storagePath: otherDir.path, contextId: 'ctx-b');
      await File(p.join(matchingDir.path, 'meta.json')).writeAsString(jsonEncode(matching.toJson()));
      await File(p.join(otherDir.path, 'meta.json')).writeAsString(jsonEncode(other.toJson()));

      final all = await manager.loadEntries();
      final filtered = await manager.loadEntries(contextId: 'ctx-a');

      expect(all.map((e) => e.id), containsAll(['match', 'other']));
      expect(filtered.map((e) => e.id), ['match']);
    });

    test('restoreEntry uploads payload, emits restore event, and removes stored entry', () async {
      final shell = _FakeRemoteShellService();
      final manager = ExplorerTrashManager();
      final entry = await manager.moveToTrash(
        shellService: shell,
        host: _host,
        context: _context,
        remotePath: '/srv/folder/readme.md',
        isDirectory: false,
      );
      var changes = 0;
      manager.changes.addListener(() => changes++);

      await manager.restoreEntry(entry: entry, shellService: shell);

      expect(shell.uploads, hasLength(1));
      expect(shell.uploads.single.remoteDestination, '/srv/folder/readme.md');
      expect(shell.uploads.single.recursive, isFalse);
      final event = manager.restoreEvents.value;
      expect(event, isNotNull);
      expect(event!.hostName, _host.name);
      expect(event.directory, '/srv/folder');
      expect(event.restoredPath, '/srv/folder/readme.md');
      expect(event.contextId, _context.id);
      expect(await Directory(entry.storagePath).exists(), isFalse);
      expect(await manager.loadEntries(), isEmpty);
      expect(changes, 1);
    });

    test('deleteEntry removes storage and notifies', () async {
      final manager = ExplorerTrashManager();
      final storageDir = Directory(p.join(_trashRootPath(), 'manual'))
        ..createSync(recursive: true);
      final entry = _trashedEntry(storagePath: storageDir.path, contextId: _context.id);
      var changes = 0;
      manager.changes.addListener(() => changes++);

      await manager.deleteEntry(entry);

      expect(await storageDir.exists(), isFalse);
      expect(changes, 1);
    });
  });
}

const _host = SshHost(
  name: 'test-host',
  hostname: 'example.com',
  port: 22,
  available: true,
);

const _context = ExplorerContext(
  id: 'ctx-1',
  host: _host,
  kind: ExplorerContextKind.server,
  label: 'Test Host',
);

String _trashRootPath() {
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return p.join(home, '.cache', 'cwatch', 'trash');
}

TrashedEntry _trashedEntry({required String storagePath, required String contextId}) {
  return TrashedEntry(
    id: p.basename(storagePath),
    host: _host,
    remotePath: '/srv/${p.basename(storagePath)}',
    displayName: p.basename(storagePath),
    isDirectory: false,
    trashedAt: DateTime.utc(2026, 1, 1),
    localPath: p.join(storagePath, p.basename(storagePath)),
    sizeBytes: 0,
    storagePath: storagePath,
    contextId: contextId,
    contextKind: ExplorerContextKind.server,
    contextLabel: 'Test Host',
  );
}

class _DownloadCall {
  const _DownloadCall({
    required this.remotePath,
    required this.localDestination,
    required this.recursive,
  });

  final String remotePath;
  final String localDestination;
  final bool recursive;
}

class _UploadCall {
  const _UploadCall({
    required this.localPath,
    required this.remoteDestination,
    required this.recursive,
  });

  final String localPath;
  final String remoteDestination;
  final bool recursive;
}

class _FakeRemoteShellService extends RemoteShellService {
  final downloads = <_DownloadCall>[];
  final uploads = <_UploadCall>[];

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    downloads.add(
      _DownloadCall(
        remotePath: remotePath,
        localDestination: localDestination,
        recursive: recursive,
      ),
    );
    final payloadPath = p.join(localDestination, p.basename(remotePath));
    final file = File(payloadPath)..createSync(recursive: true);
    file.writeAsStringSync('payload:$remotePath');
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    uploads.add(
      _UploadCall(
        localPath: localPath,
        remoteDestination: remoteDestination,
        recursive: recursive,
      ),
    );
  }

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<List<RemoteFileEntry>> searchPaths(
    SshHost host,
    String basePath,
    String query, {
    String? includePattern,
    String? excludePattern,
    bool matchCase = false,
    bool matchWholeWord = false,
    bool searchContents = false,
    void Function(RemoteFileEntry entry)? onEntry,
    RemoteCommandCancellation? cancellation,
    Duration timeout = const Duration(seconds: 30),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
    RunTimeoutHandler? onTimeout,
  }) => throw UnimplementedError();

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
    void Function(int exitCode)? onExit,
  }) => throw UnimplementedError();
}
