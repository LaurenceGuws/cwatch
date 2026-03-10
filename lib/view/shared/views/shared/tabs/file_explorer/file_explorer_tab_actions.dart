import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/model/data/models/local_file_session.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';

import 'context_menu_builder.dart';
import 'selection_controller.dart';

typedef ExplorerMountedGetter = bool Function();

class FileExplorerTabActions {
  FileExplorerTabActions({
    required this.controller,
    required this.selectionController,
    required this.scrollController,
    required this.isMounted,
    required this.showSnackBar,
    this.openTerminalTab,
  });

  final FileExplorerController controller;
  final SelectionController selectionController;
  final ScrollController scrollController;
  final ExplorerMountedGetter isMounted;
  final ValueChanged<String> showSnackBar;
  final ValueChanged<String>? openTerminalTab;

  Future<void> loadPath(String path, {bool forceReload = false}) async {
    await controller.loadPath(path, forceReload: forceReload);
  }

  Future<void> handleLocalDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) {
      AppLogger().debug('Drop ignored: no files', tag: 'Explorer');
      return;
    }
    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty);
    AppLogger().debug(
      'Handling drop of ${details.files.length} items to '
      '${controller.currentPath}: ${paths.join(', ')}',
      tag: 'Explorer',
    );
    await controller.fileOpsUiHandler.handleDroppedPaths(
      targetDirectory: controller.currentPath,
      paths: paths.toList(),
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: refreshCurrentPath,
    );
    if (isMounted()) {
      final count = details.files.length;
      showSnackBar(
        'Uploading $count dropped item${count == 1 ? '' : 's'} to ${controller.currentPath}',
      );
    }
  }

  Future<void> handleDropDone(DropDoneDetails details) async {
    if (controller.isSelfDragDrop(
      paths: details.files.map((file) => file.path).toList(),
      targetDirectory: controller.currentPath,
    )) {
      AppLogger().debug(
        'Drop ignored: source and target match',
        tag: 'Explorer',
      );
      return;
    }
    AppLogger().debug(
      'Drop done ${details.files.length} files at ${details.localPosition}',
      tag: 'Explorer',
    );
    await handleLocalDrop(details);
  }

  Future<void> refreshCurrentPath() async {
    final scrollOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    await controller.refreshCurrentPath();
    if (scrollController.hasClients && scrollOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(scrollOffset);
        }
      });
    }
  }

  Future<void> showEntryContextMenu(
    BuildContext context,
    RemoteFileEntry entry,
    Offset position,
  ) async {
    final sortedEntries = controller.currentSortedEntries();
    final selectedEntries = selectionController.getSelectedEntries(
      sortedEntries,
    );
    final builder = ContextMenuBuilder(
      hostName: controller.host.name,
      currentPath: controller.currentPath,
      selectedEntries: selectedEntries,
      clipboardAvailable: ExplorerClipboard.hasEntries,
      onOpen: (e) => loadPath(PathUtils.joinPath(controller.currentPath, e.name)),
      onCopyPath: (e) async {
        final path = PathUtils.joinPath(controller.currentPath, e.name);
        await Clipboard.setData(ClipboardData(text: path));
        if (isMounted()) {
          showSnackBar('Copied $path');
        }
      },
      onOpenLocally: openLocally,
      onEditFile: openEditor,
      onRename: promptRename,
      onCopy: (entries) async {
        if (entries.length > 1) {
          await handleMultiCopy(entries);
        } else {
          handleClipboardSet(entries.first, ExplorerClipboardOperation.copy);
        }
      },
      onCut: (entries) async {
        if (entries.length > 1) {
          await handleMultiCut(entries);
        } else {
          handleClipboardSet(entries.first, ExplorerClipboardOperation.cut);
        }
      },
      onPaste: () => handlePaste(targetDirectory: controller.currentPath),
      onPasteInto: (e) => handlePaste(
        targetDirectory: PathUtils.joinPath(controller.currentPath, e.name),
      ),
      onMove: promptMove,
      onDelete: (entries) async {
        if (entries.length > 1) {
          await confirmMultiDelete(
            entries,
            permanent: SelectionController.isShiftPressed(),
          );
        } else {
          await confirmDelete(
            entries.first,
            permanent: SelectionController.isShiftPressed(),
          );
        }
      },
      onDownload: handleDownload,
      onUploadFiles: handleUploadFiles,
      onUploadFolder: handleUploadFolder,
      onOpenTerminal: openTerminalTab,
      onMessage: showSnackBar,
      joinPath: PathUtils.joinPath,
    );

    final menuItems = builder.buildEntryMenuItems(entry);
    final action = await controller.uiAdapter.showContextMenu<ExplorerContextAction>(
      position: position,
      items: menuItems,
    );

    if (!isMounted()) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await builder.handleAction(context, action, entry);
  }

  void handleEntryDoubleTap(RemoteFileEntry entry) {
    final targetPath = PathUtils.joinPath(controller.currentPath, entry.name);
    if (entry.isDirectory) {
      unawaited(loadPath(targetPath));
    } else {
      unawaited(openLocally(entry));
    }
  }

  Future<void> openEditor(RemoteFileEntry entry) async {
    await controller.fileEditingService.openEditor(
      entry,
      controller.currentPath,
    );
  }

  Future<void> openLocally(RemoteFileEntry entry) async {
    final session = await controller.fileEditingService.openLocally(
      entry,
      controller.currentPath,
    );
    if (session != null && isMounted()) {
      controller.updateLocalEdit(session);
    }
  }

  Future<void> syncLocalEdit(LocalFileSession session) async {
    controller.markSyncing(session.remotePath, syncing: true);
    await controller.fileEditingService.syncLocalEdit(session, (s) {
      if (isMounted()) {
        controller.updateLocalEdit(s);
      }
    });
    if (isMounted()) {
      controller.markSyncing(session.remotePath, syncing: false);
    }
  }

  Future<void> refreshCacheFromServer(LocalFileSession session) async {
    controller.markRefreshing(session.remotePath, refreshing: true);
    await controller.fileEditingService.refreshCacheFromServer(session);
    if (isMounted()) {
      controller.markRefreshing(session.remotePath, refreshing: false);
    }
  }

  Future<void> clearCachedCopy(LocalFileSession session) async {
    await controller.fileEditingService.clearCachedCopy(session);
    if (isMounted()) {
      controller.removeLocalEdit(session);
    }
  }

  void handleClipboardSet(
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    controller.clipboardHandler.setClipboardEntry(entry, operation);
  }

  Future<void> promptRename(RemoteFileEntry entry) async {
    final newName = await controller.uiAdapter.showRenameDialog(entry);
    if (newName == null) {
      return;
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == entry.name) {
      return;
    }
    final sourcePath = PathUtils.joinPath(controller.currentPath, entry.name);
    final destinationPath = PathUtils.joinPath(
      controller.currentPath,
      trimmed,
    );
    try {
      await controller.runShell(
        () => controller.shellService.movePath(
          controller.host,
          sourcePath,
          destinationPath,
        ),
      );
      await refreshCurrentPath();
      if (!isMounted()) return;
      showSnackBar('Renamed ${entry.name} to $trimmed');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to rename ${entry.name}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is CancelledExplorerOperation) return;
      if (!isMounted()) return;
      showSnackBar('Failed to rename: $error');
    }
  }

  Future<void> promptMove(RemoteFileEntry entry) async {
    final target = await controller.uiAdapter.showMoveDialog(
      entry,
      controller.currentPath,
    );
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final normalized = PathUtils.normalizePath(
      target,
      currentPath: controller.currentPath,
    );
    if (normalized == PathUtils.joinPath(controller.currentPath, entry.name)) {
      return;
    }
    try {
      await controller.runShell(
        () => controller.shellService.movePath(
          controller.host,
          PathUtils.joinPath(controller.currentPath, entry.name),
          normalized,
        ),
      );
      await refreshCurrentPath();
      if (!isMounted()) return;
      showSnackBar('Moved ${entry.name} to $normalized');
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to move ${entry.name}',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is CancelledExplorerOperation) return;
      if (!isMounted()) return;
      showSnackBar('Failed to move: $error');
    }
  }

  Future<void> confirmDelete(
    RemoteFileEntry entry, {
    bool permanent = false,
  }) async {
    final deletePermanently = permanent || SelectionController.isShiftPressed();
    final confirmed = await controller.uiAdapter.showDeleteDialog(
      entry,
      controller.host,
      deletePermanently,
    );
    if (confirmed != true) {
      return;
    }
    if (!isMounted()) return;
    if (deletePermanently) {
      await controller.deleteHandler.deletePermanently(
        entry,
        controller.currentPath,
        refreshCurrentPath,
      );
    } else {
      await controller.deleteHandler.moveToTrash(
        entry,
        controller.currentPath,
        refreshCurrentPath,
      );
    }
  }

  Future<void> handlePaste({required String targetDirectory}) async {
    await controller.fileOpsUiHandler.handlePaste(
      targetDirectory: targetDirectory,
      currentPath: controller.currentPath,
      joinPath: PathUtils.joinPath,
      normalizePath: (path) =>
          PathUtils.normalizePath(path, currentPath: controller.currentPath),
      refreshCurrentPath: refreshCurrentPath,
    );
  }

  Future<void> handleMultiCopy(List<RemoteFileEntry> entries) async {
    controller.clipboardHandler.setClipboardEntries(
      entries,
      ExplorerClipboardOperation.copy,
    );
  }

  Future<void> handleMultiCut(List<RemoteFileEntry> entries) async {
    controller.clipboardHandler.setClipboardEntries(
      entries,
      ExplorerClipboardOperation.cut,
    );
  }

  Future<void> confirmMultiDelete(
    List<RemoteFileEntry> entries, {
    bool permanent = false,
  }) async {
    if (entries.isEmpty) {
      return;
    }
    final deletePermanently = permanent || SelectionController.isShiftPressed();
    final count = entries.length;
    final confirmed = await controller.uiAdapter.showMultiDeleteDialog(
      count: count,
      hostName: controller.host.name,
      deletePermanently: deletePermanently,
    );
    if (confirmed != true) {
      return;
    }
    if (!isMounted()) return;
    if (deletePermanently) {
      await controller.deleteHandler.deleteMultiplePermanently(
        entries,
        controller.currentPath,
        refreshCurrentPath,
      );
    } else {
      await controller.deleteHandler.moveMultipleToTrash(
        entries,
        controller.currentPath,
        refreshCurrentPath,
      );
    }
  }

  Future<void> handleDownload(List<RemoteFileEntry> entries) async {
    await controller.fileOpsUiHandler.handleDownload(
      entries: entries,
      currentPath: controller.currentPath,
      joinPath: PathUtils.joinPath,
    );
  }

  Future<void> handleUploadFiles(String targetDirectory) async {
    await controller.fileOpsUiHandler.handleUploadFiles(
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: refreshCurrentPath,
    );
  }

  Future<void> handleUploadFolder(String targetDirectory) async {
    await controller.fileOpsUiHandler.handleUploadFolder(
      targetDirectory: targetDirectory,
      joinPath: PathUtils.joinPath,
      refreshCurrentPath: refreshCurrentPath,
    );
  }

  Future<void> showNavigateToSubdirectoryDialog() async {
    final selected = await controller.uiAdapter.showNavigateToSubdirectoryDialog(
      controller.state.entries,
    );
    if (selected != null && isMounted()) {
      final targetPath = PathUtils.joinPath(controller.currentPath, selected);
      await loadPath(targetPath);
    }
  }
}
