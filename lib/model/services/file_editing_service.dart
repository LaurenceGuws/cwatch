import 'dart:io';

import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_editor_cache.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/path_utils.dart';

/// Service for handling file editing, caching, and syncing.
class FileEditingService {
  FileEditingService({
    required this.shellService,
    required this.host,
    required this.cache,
    required this.runShellWrapper,
    required this.promptMergeDialog,
    required this.launchLocalApp,
    this.onMessage,
    this.onOpenEditorTab,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final RemoteEditorCache cache;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  final Future<String?> Function({
    required String remotePath,
    required String local,
    required String remote,
  })
  promptMergeDialog;
  final Future<void> Function(String path) launchLocalApp;
  final void Function(String message)? onMessage;
  final Future<void> Function(String path, String initialContent)?
  onOpenEditorTab;

  /// Open a file in the editor (tab or dialog).
  Future<void> openEditor(RemoteFileEntry entry, String currentPath) async {
    final path = PathUtils.joinPath(currentPath, entry.name);
    try {
      final contents = await runShellWrapper(
        () => shellService.readFile(host, path),
      );

      if (onOpenEditorTab != null) {
        await onOpenEditorTab!(path, contents);
        return;
      }
      onMessage?.call(
        'Inline editor unavailable. Open via editor tab instead.',
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to open editor for $path',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      onMessage?.call('Failed to edit file: $error');
    }
  }

  /// Open a file locally in the system default app.
  Future<LocalFileSession?> openLocally(
    RemoteFileEntry entry,
    String currentPath,
  ) async {
    final remotePath = PathUtils.joinPath(currentPath, entry.name);
    try {
      CachedEditorSession? session = await cache.loadSession(
        host: host.name,
        remotePath: remotePath,
      );
      if (session == null) {
        final contents = await runShellWrapper(
          () => shellService.readFile(host, remotePath),
        );
        session = await cache.createSession(
          host: host.name,
          remotePath: remotePath,
          contents: contents,
        );
      }
      await launchLocalApp(session.workingPath);
      final localSession = LocalFileSession(
        localPath: session.workingPath,
        snapshotPath: session.snapshotPath,
        remotePath: remotePath,
      );
      onMessage?.call(
        'Opened local copy: ${session.workingPath}. Edit then press Sync.',
      );
      return localSession;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to open local copy of $remotePath',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      onMessage?.call('Failed to open locally: $error');
      return null;
    }
  }

  /// Sync local edits to remote.
  Future<void> syncLocalEdit(
    LocalFileSession session,
    void Function(LocalFileSession) onSynced,
  ) async {
    try {
      final workingFile = File(session.localPath);
      final snapshotFile = File(session.snapshotPath);
      final localContents = await workingFile.readAsString();
      final baseContents = await snapshotFile.readAsString();
      final remoteContents = await runShellWrapper(
        () => shellService.readFile(host, session.remotePath),
      );

      if (remoteContents == baseContents) {
        await runShellWrapper(
          () => shellService.writeFile(host, session.remotePath, localContents),
        );
        await snapshotFile.writeAsString(localContents);
        session.lastSynced = DateTime.now();
        onSynced(session);
        onMessage?.call('Synced ${session.remotePath} to remote host');
      } else if (localContents == baseContents) {
        await workingFile.writeAsString(remoteContents);
        await snapshotFile.writeAsString(remoteContents);
        onMessage?.call('Remote changes pulled for ${session.remotePath}');
      } else {
        final merged = await promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged != null) {
          await runShellWrapper(
            () => shellService.writeFile(host, session.remotePath, merged),
          );
          await workingFile.writeAsString(merged);
          await snapshotFile.writeAsString(merged);
          session.lastSynced = DateTime.now();
          onSynced(session);
          onMessage?.call('Merged and synced ${session.remotePath}');
        }
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to sync local edit for ${session.remotePath}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      onMessage?.call('Failed to sync: $error');
    }
  }

  /// Refresh cache from server.
  Future<void> refreshCacheFromServer(LocalFileSession session) async {
    try {
      final remoteContents = await runShellWrapper(
        () => shellService.readFile(host, session.remotePath),
      );
      final workingFile = File(session.localPath);
      final localContents = await workingFile.readAsString();
      String? nextWorking;
      if (localContents == remoteContents) {
        nextWorking = remoteContents;
      } else {
        final merged = await promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged == null) {
          await File(session.snapshotPath).writeAsString(remoteContents);
          return;
        }
        nextWorking = merged;
      }
      await workingFile.writeAsString(nextWorking);
      await File(session.snapshotPath).writeAsString(remoteContents);
      onMessage?.call('Cache refreshed for ${session.remotePath}');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to refresh cache for ${session.remotePath}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      onMessage?.call('Failed to refresh cache: $error');
    }
  }

  /// Clear cached copy.
  Future<void> clearCachedCopy(LocalFileSession session) async {
    await cache.clearSession(host: host.name, remotePath: session.remotePath);
    onMessage?.call('Cleared cached copy for ${session.remotePath}');
  }

  /// Hydrate cached sessions for entries.
  Future<Map<String, LocalFileSession>> hydrateCachedSessions(
    List<RemoteFileEntry> entries,
    String basePath,
  ) async {
    final updates = <String, LocalFileSession>{};
    for (final entry in entries) {
      if (entry.isDirectory) {
        continue;
      }
      final remotePath = PathUtils.joinWithBase(basePath, entry.name);
      final session = await cache.loadSession(
        host: host.name,
        remotePath: remotePath,
      );
      if (session != null) {
        updates[remotePath] = LocalFileSession(
          localPath: session.workingPath,
          snapshotPath: session.snapshotPath,
          remotePath: remotePath,
        );
      }
    }
    return updates;
  }
}
