import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/remote_editor_cache.dart';
import '../remote_file_editor_dialog.dart';
import 'file_entry_list.dart';
import 'path_utils.dart';

/// Service for handling file editing, caching, and syncing
class FileEditingService {
  FileEditingService({
    required this.shellService,
    required this.host,
    required this.cache,
    required this.runShellWrapper,
    required this.promptMergeDialog,
    required this.launchLocalApp,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final RemoteEditorCache cache;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  final Future<String?> Function({
    required String remotePath,
    required String local,
    required String remote,
  }) promptMergeDialog;
  final Future<void> Function(String path) launchLocalApp;

  /// Open a file in the editor dialog
  Future<void> openEditor(
    BuildContext context,
    RemoteFileEntry entry,
    String currentPath,
  ) async {
    final path = PathUtils.joinPath(currentPath, entry.name);
    try {
      final contents = await runShellWrapper(
        () => shellService.readFile(host, path),
      );
      if (!context.mounted) {
        return;
      }
      final updated = await showDialog<String>(
        context: context,
        builder: (context) =>
            RemoteFileEditorDialog(path: path, initialContent: contents),
      );
      if (updated != null && updated != contents) {
        await runShellWrapper(
          () => shellService.writeFile(host, path, updated),
        );
        final localFile = await cache.materialize(
          host: host.name,
          remotePath: path,
          contents: updated,
        );
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $path · Cached at ${localFile.path}')),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit file: $error')),
      );
    }
  }

  /// Open a file locally in the system default app
  Future<LocalFileSession?> openLocally(
    BuildContext context,
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
      if (!context.mounted) {
        return localSession;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opened local copy: ${session.workingPath}. Edit then press Sync.',
          ),
        ),
      );
      return localSession;
    } catch (error) {
      if (!context.mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open locally: $error')),
      );
      return null;
    }
  }

  /// Sync local edits to remote
  Future<void> syncLocalEdit(
    BuildContext context,
    LocalFileSession session,
    ValueChanged<LocalFileSession> onSynced,
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
          () => shellService.writeFile(
            host,
            session.remotePath,
            localContents,
          ),
        );
        await snapshotFile.writeAsString(localContents);
        session.lastSynced = DateTime.now();
        onSynced(session);
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${session.remotePath} to remote host'),
          ),
        );
      } else if (localContents == baseContents) {
        await workingFile.writeAsString(remoteContents);
        await snapshotFile.writeAsString(remoteContents);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remote changes pulled for ${session.remotePath}'),
            ),
          );
        }
      } else {
        final merged = await promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged != null) {
          await runShellWrapper(
            () => shellService.writeFile(
              host,
              session.remotePath,
              merged,
            ),
          );
          await workingFile.writeAsString(merged);
          await snapshotFile.writeAsString(merged);
          session.lastSynced = DateTime.now();
          onSynced(session);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Merged and synced ${session.remotePath}'),
              ),
            );
          }
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync: $error')),
        );
      }
    }
  }

  /// Refresh cache from server
  Future<void> refreshCacheFromServer(
    BuildContext context,
    LocalFileSession session,
  ) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cache refreshed for ${session.remotePath}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh cache: $error')),
        );
      }
    }
  }

  /// Clear cached copy
  Future<void> clearCachedCopy(
    BuildContext context,
    LocalFileSession session,
  ) async {
    await cache.clearSession(
      host: host.name,
      remotePath: session.remotePath,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared cached copy for ${session.remotePath}')),
    );
  }

  /// Hydrate cached sessions for entries
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

