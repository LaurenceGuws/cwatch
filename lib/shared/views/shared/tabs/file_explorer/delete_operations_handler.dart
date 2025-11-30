import 'package:flutter/material.dart';

import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'path_utils.dart';

/// Handler for delete and trash operations
class DeleteOperationsHandler {
  DeleteOperationsHandler({
    required this.shellService,
    required this.host,
    required this.trashManager,
    required this.runShellWrapper,
    required this.explorerContext,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final ExplorerTrashManager trashManager;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  final ExplorerContext explorerContext;

  /// Delete a single entry permanently
  Future<void> deletePermanently(
    BuildContext context,
    RemoteFileEntry entry,
    String currentPath,
    Future<void> Function() refreshPath,
  ) async {
    final path = PathUtils.joinPath(currentPath, entry.name);
    try {
      await runShellWrapper(() => shellService.deletePath(host, path));
      await refreshPath();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${entry.name} permanently')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $error')),
      );
    }
  }

  /// Move a single entry to trash
  Future<void> moveToTrash(
    BuildContext context,
    RemoteFileEntry entry,
    String currentPath,
    Future<void> Function() refreshPath,
  ) async {
    final path = PathUtils.joinPath(currentPath, entry.name);
    TrashedEntry? recorded;
    try {
      recorded = await runShellWrapper(
        () => trashManager.moveToTrash(
          shellService: shellService,
          host: host,
          context: explorerContext,
          remotePath: path,
          isDirectory: entry.isDirectory,
          notify: false,
        ),
      );
      await runShellWrapper(() => shellService.deletePath(host, path));
      trashManager.notifyListeners();
      await refreshPath();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${entry.name} to trash')),
      );
    } catch (error) {
      if (recorded != null) {
        await trashManager.deleteEntry(recorded, notify: false);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move to trash: $error')),
      );
    }
  }

  /// Delete multiple entries permanently
  Future<void> deleteMultiplePermanently(
    BuildContext context,
    List<RemoteFileEntry> entries,
    String currentPath,
    Future<void> Function() refreshPath,
  ) async {
    int successCount = 0;
    int failCount = 0;
    for (final entry in entries) {
      try {
        final path = PathUtils.joinPath(currentPath, entry.name);
        await runShellWrapper(() => shellService.deletePath(host, path));
        successCount++;
      } catch (error) {
        failCount++;
        AppLogger.w('Failed to delete ${entry.name}', tag: 'Explorer', error: error);
      }
    }
    await refreshPath();
    if (!context.mounted) return;
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $successCount items permanently')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $successCount items. $failCount failed.'),
        ),
      );
    }
  }

  /// Move multiple entries to trash
  Future<void> moveMultipleToTrash(
    BuildContext context,
    List<RemoteFileEntry> entries,
    String currentPath,
    Future<void> Function() refreshPath,
  ) async {
    int successCount = 0;
    int failCount = 0;
    for (final entry in entries) {
      try {
        final path = PathUtils.joinPath(currentPath, entry.name);
        await runShellWrapper(
          () => trashManager.moveToTrash(
            shellService: shellService,
            host: host,
            context: explorerContext,
            remotePath: path,
            isDirectory: entry.isDirectory,
            notify: false,
          ),
        );
        await runShellWrapper(() => shellService.deletePath(host, path));
        successCount++;
      } catch (error) {
        failCount++;
        AppLogger.w('Failed to move ${entry.name} to trash', tag: 'Explorer', error: error);
      }
    }
    trashManager.notifyListeners();
    await refreshPath();
    if (!context.mounted) return;
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $successCount items to trash')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved $successCount items to trash. $failCount failed.'),
        ),
      );
    }
  }
}
