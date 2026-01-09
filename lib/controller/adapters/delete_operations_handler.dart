import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/view/shared/views/shared/tabs/file_explorer/path_utils.dart';
import 'explorer_ui_adapter.dart';

/// Handler for delete and trash operations.
class DeleteOperationsHandler {
  DeleteOperationsHandler({
    required this.shellService,
    required this.host,
    required this.trashManager,
    required this.runShellWrapper,
    required this.explorerContext,
    required this.uiAdapter,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final ExplorerTrashManager trashManager;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  final ExplorerContext explorerContext;
  final ExplorerUiAdapter uiAdapter;

  /// Delete a single entry permanently.
  Future<void> deletePermanently(
    RemoteFileEntry entry,
    String currentPath,
    Future<void> Function() refreshPath,
  ) async {
    final path = PathUtils.joinPath(currentPath, entry.name);
    try {
      await runShellWrapper(() => shellService.deletePath(host, path));
      await refreshPath();
      uiAdapter.showSnackBar('Deleted ${entry.name} permanently');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to delete ${entry.name} permanently',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to delete: $error');
    }
  }

  /// Move a single entry to trash.
  Future<void> moveToTrash(
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
      uiAdapter.showSnackBar('Moved ${entry.name} to trash');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to move ${entry.name} to trash',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (recorded != null) {
        await trashManager.deleteEntry(recorded, notify: false);
      }
      uiAdapter.showSnackBar('Failed to move to trash: $error');
    }
  }

  /// Delete multiple entries permanently.
  Future<void> deleteMultiplePermanently(
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
        AppLogger().warn(
          'Failed to delete ${entry.name}',
          tag: 'Explorer',
          error: error,
        );
      }
    }
    await refreshPath();
    if (failCount == 0) {
      uiAdapter.showSnackBar('Deleted $successCount items permanently');
    } else {
      uiAdapter.showSnackBar('Deleted $successCount items. $failCount failed.');
    }
  }

  /// Move multiple entries to trash.
  Future<void> moveMultipleToTrash(
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
        AppLogger().warn(
          'Failed to move ${entry.name} to trash',
          tag: 'Explorer',
          error: error,
        );
      }
    }
    trashManager.notifyListeners();
    await refreshPath();
    if (failCount == 0) {
      uiAdapter.showSnackBar('Moved $successCount items to trash');
    } else {
      uiAdapter.showSnackBar(
        'Moved $successCount items to trash. $failCount failed.',
      );
    }
  }
}
