import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/view/shared/widgets/file_operation_progress_dialog.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'package:cwatch/model/services/file_operations_service.dart';
import 'file_operation_item_progress.dart';
import 'file_operation_transfer_runtime.dart';
import 'explorer_ui_adapter.dart';

class FileOperationsUiHandler {
  FileOperationsUiHandler({required this.service, required this.uiAdapter});

  final FileOperationsService service;
  final ExplorerUiAdapter uiAdapter;

  Future<void> handlePaste({
    required String targetDirectory,
    required String currentPath,
    required String Function(String, String) joinPath,
    required String Function(String) normalizePath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    final context = uiAdapter.context;
    final clipboardEntries = ExplorerClipboard.entries;
    if (clipboardEntries.isEmpty) {
      return;
    }
    final destinationDir = normalizePath(targetDirectory);
    final refreshCurrent = destinationDir == currentPath;

    FileOperationProgressController? progressController;
    if (clipboardEntries.length > 1) {
      if (!context.mounted) return;
      progressController = FileOperationProgressDialog.show(
        context,
        operation:
            clipboardEntries.first.operation == ExplorerClipboardOperation.copy
            ? 'Copying'
            : 'Moving',
        totalItems: clipboardEntries.length,
      );
    }

    int successCount = 0;
    int failCount = 0;
    final cutEntries = <ExplorerClipboardEntry>[];

    for (var i = 0; i < clipboardEntries.length; i++) {
      final clipboard = clipboardEntries[i];
      final destinationPath = joinPath(destinationDir, clipboard.displayName);

      if (clipboard.contextId == service.explorerContext.id &&
          clipboard.remotePath == destinationPath) {
        if (progressController != null) {
          progressController.increment();
        }
        continue;
      }

      if (progressController != null) {
        progressController.updateProgress(currentItem: clipboard.displayName);
      }

      try {
        final isSameContext = clipboard.contextId == service.explorerContext.id;
        if (isSameContext) {
          if (clipboard.operation == ExplorerClipboardOperation.copy) {
            await service.copyPath(
              clipboard.remotePath,
              destinationPath,
              recursive: clipboard.isDirectory,
            );
            successCount++;
          } else {
            await service.movePath(clipboard.remotePath, destinationPath);
            cutEntries.add(clipboard);
            successCount++;
          }
        } else {
          await service.copyAcrossContexts(
            clipboard,
            destinationPath,
            move: clipboard.operation == ExplorerClipboardOperation.cut,
          );
          if (clipboard.operation == ExplorerClipboardOperation.cut) {
            cutEntries.add(clipboard);
          }
          successCount++;
        }
        if (progressController != null) {
          progressController.increment();
        }
      } catch (error) {
        failCount++;
        AppLogger().warn(
          'Failed to paste ${clipboard.displayName}',
          tag: 'Explorer',
          error: error,
        );
        if (progressController != null) {
          progressController.increment();
        }
      }
    }

    if (progressController != null && context.mounted) {
      progressController.dismiss();
    }

    if (cutEntries.isNotEmpty) {
      ExplorerClipboard.notifyCutsCompleted(cutEntries);
    }

    if (refreshCurrent) {
      await refreshCurrentPath();
    }
    if (!context.mounted) return;

    if (failCount == 0) {
      _showSnackBar(
        successCount == 1
            ? 'Pasted ${clipboardEntries.first.displayName}'
            : 'Pasted $successCount item${successCount > 1 ? 's' : ''}',
      );
    } else {
      _showSnackBar(
        'Pasted $successCount item${successCount > 1 ? 's' : ''}. $failCount failed.',
      );
    }
  }

  Future<void> handleDownload({
    required List<RemoteFileEntry> entries,
    required String currentPath,
    required String Function(String, String) joinPath,
  }) async {
    final context = uiAdapter.context;
    if (entries.isEmpty) {
      return;
    }

    String? selectedDirectory;
    if (Platform.isAndroid) {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select download location',
      );
      if (selectedDirectory == null) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final downloadsDir = Directory(
              p.join(externalDir.path, 'Downloads'),
            );
            selectedDirectory = downloadsDir.path;
          } else {
            final appDir = await getApplicationDocumentsDirectory();
            final downloadsDir = Directory(p.join(appDir.path, 'Downloads'));
            selectedDirectory = downloadsDir.path;
          }
        } catch (e) {
          AppLogger().warn(
            'Failed to get Android storage directory',
            tag: 'Explorer',
            error: e,
          );
          if (!context.mounted) return;
          _showSnackBar('Failed to access download directory');
          return;
        }
      }
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select download location',
      );
    }

    if (selectedDirectory == null) {
      return;
    }

    final downloadDir = Directory(selectedDirectory);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final downloadEntries = await service.collectDownloadEntries(
      entries: entries,
      baseRemotePath: currentPath,
      baseLocalDir: downloadDir.path,
      joinPath: joinPath,
    );
    final items = downloadEntries
        .map(
          (entry) =>
              FileOperationItem(label: entry.label, sizeBytes: entry.sizeBytes),
        )
        .toList();
    final totalItems = items.isNotEmpty ? items.length : entries.length;

    if (!context.mounted) return;
    final runtime = FileOperationTransferRuntime.show(
      context: context,
      operation: 'Downloading',
      totalItems: totalItems,
      items: items,
      maxConcurrency: service.downloadConcurrency,
      showMessage: _showSnackBar,
    );
    final progressController = runtime.progressController;
    final transferSession = runtime.session;

    var successCount = 0;

    try {
      await service.runConcurrent(
        total: downloadEntries.length,
        maxConcurrency: () => progressController.maxConcurrency,
        isCancelled: () => progressController.cancelled,
        task: (index) async {
          final entry = downloadEntries[index];
          if (!context.mounted) return;
          if (progressController.cancelled) return;
          final itemProgress = FileOperationItemProgress(
            controller: progressController,
            label: entry.label,
            itemIndex: index,
          )..start();

          try {
            if (entry.isDirectory) {
              await Directory(entry.localDestination).create(recursive: true);
            } else {
              await service.downloadPath(
                remotePath: entry.remotePath,
                localDestination: entry.localDestination,
                recursive: false,
                onBytes: itemProgress.onBytes,
              );
            }
            if (!context.mounted) return;
            successCount++;
            itemProgress.complete();
          } catch (error) {
            if (!context.mounted) return;
            itemProgress.fail();
            AppLogger().warn(
              'Failed to download ${entry.label}',
              tag: 'Explorer',
              error: error,
            );
          }
        },
      );

      await transferSession.complete(
        successCount: successCount,
        failCount: 0,
        successVerb: 'Downloaded',
        cancelledMessage: 'Download cancelled',
        refresh: () async {},
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Download operation failed',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      transferSession.fail(error, failedVerb: 'Download');
    }
  }

  Future<void> handleUploadFiles({
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    final context = uiAdapter.context;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select files to upload',
      withData: false,
    );

    final resultFiles = result?.files ?? const <PlatformFile>[];

    if (result == null || resultFiles.isEmpty) {
      return;
    }

    final files = resultFiles.where((f) => f.path != null).toList();

    if (files.isEmpty) {
      if (!context.mounted) return;
      _showSnackBar('No valid files selected');
      return;
    }

    final items = await service.buildFileItems(
      files
          .map(
            (file) => TransferItemInput(
              name: file.name,
              path: file.path,
              bytes: file.bytes,
            ),
          )
          .toList(),
    );
    final uiItems = items
        .map(
          (item) =>
              FileOperationItem(label: item.label, sizeBytes: item.sizeBytes),
        )
        .toList();

    if (!context.mounted) return;
    final runtime = FileOperationTransferRuntime.show(
      context: context,
      operation: 'Uploading',
      totalItems: uiItems.length,
      items: uiItems,
      maxConcurrency: service.uploadConcurrency,
      showMessage: _showSnackBar,
    );
    final progressController = runtime.progressController;
    final transferSession = runtime.session;

    try {
      int successCount = 0;
      int failCount = 0;

      await service.runConcurrent(
        total: files.length,
        maxConcurrency: () => progressController.maxConcurrency,
        isCancelled: () => progressController.cancelled,
        task: (i) async {
          final file = files[i];

          if (!context.mounted) {
            return;
          }
          if (progressController.cancelled) {
            return;
          }

          final fileName = file.name.isNotEmpty
              ? file.name
              : (file.path != null ? p.basename(file.path!) : 'file_$i');
          final remotePath = joinPath(targetDirectory, fileName);

          final itemProgress = FileOperationItemProgress(
            controller: progressController,
            label: fileName,
            itemIndex: i,
          )..start();

          try {
            if (file.path == null || file.path!.isEmpty) {
              throw Exception('File has no accessible path');
            }

            final localEntityType = FileSystemEntity.typeSync(file.path!);
            final isDirectory =
                localEntityType == FileSystemEntityType.directory;

            if (isDirectory) {
              failCount++;
              AppLogger().warn(
                'Skipping directory in file upload: ${file.path}',
                tag: 'Explorer',
              );
              itemProgress.fail();
              return;
            }

            await service.uploadPath(
              localPath: file.path!,
              remoteDestination: remotePath,
              recursive: false,
              onBytes: itemProgress.onBytes,
            );
            if (!context.mounted) return;
            successCount++;
            itemProgress.complete();
          } catch (error) {
            if (!context.mounted) return;
            failCount++;
            itemProgress.fail();
            AppLogger().warn(
              'Failed to upload $fileName',
              tag: 'Explorer',
              error: error,
            );
            AppLogger().debug(
              'File details: path=${file.path}, name=${file.name}, bytes=${file.bytes?.length ?? 0}',
              tag: 'Explorer',
            );
          }
        },
      );

      await transferSession.complete(
        successCount: successCount,
        failCount: failCount,
        successVerb: 'Uploaded',
        cancelledMessage: 'Upload cancelled',
        refresh: refreshCurrentPath,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Upload operation failed',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      transferSession.fail(error, failedVerb: 'Upload');
    }
  }

  Future<void> handleUploadFolder({
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    final context = uiAdapter.context;
    final createdRemoteDirs = <String>{};

    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select a folder to upload',
    );

    if (directoryPath == null || directoryPath.isEmpty) {
      return;
    }

    final directoryName = p.basename(directoryPath);
    final baseRemotePath = joinPath(
      targetDirectory,
      directoryName,
    ).replaceAll('\\', '/');
    final remoteBaseDir = p.dirname(baseRemotePath).replaceAll('\\', '/');

    final directoryCounts = await service.countDirectoryEntries([
      directoryPath,
    ]);
    final totalItems = directoryCounts.totalUnits == 0
        ? 1
        : directoryCounts.totalUnits;
    final items = await service.buildDirectoryItems(
      directoryPath,
      directoryName,
    );
    final uiItems = items
        .map(
          (item) =>
              FileOperationItem(label: item.label, sizeBytes: item.sizeBytes),
        )
        .toList();

    if (!context.mounted) return;
    final runtime = FileOperationTransferRuntime.show(
      context: context,
      operation: 'Uploading',
      totalItems: totalItems,
      items: uiItems,
      maxConcurrency: service.uploadConcurrency,
      showMessage: _showSnackBar,
    );
    final progressController = runtime.progressController;
    final transferSession = runtime.session;

    try {
      int successCount = 0;
      int failCount = 0;

      try {
        await service.ensureRemoteDirectory(remoteBaseDir, createdRemoteDirs);
      } catch (error) {
        if (!context.mounted) return;
        failCount++;
        AppLogger().warn(
          'Failed to prepare remote directory for $directoryName',
          tag: 'Explorer',
          error: error,
        );
        progressController.increment();
        return;
      }

      final itemIndexByLabel = <String, int>{
        for (var i = 0; i < uiItems.length; i++) uiItems[i].label: i,
      };
      final uploadEntries = await service.collectDirectoryUploads(
        directoryPath: directoryPath,
        directoryName: directoryName,
        baseRemotePath: baseRemotePath,
        itemIndexByLabel: itemIndexByLabel,
        joinPath: joinPath,
      );

      if (uploadEntries.isNotEmpty) {
        await service.runConcurrent(
          total: uploadEntries.length,
          maxConcurrency: () => progressController.maxConcurrency,
          isCancelled: () => progressController.cancelled,
          task: (index) async {
            final entry = uploadEntries[index];
            if (!context.mounted) return;
            if (progressController.cancelled) return;
            final itemProgress = FileOperationItemProgress(
              controller: progressController,
              label: entry.remotePath,
              itemIndex: entry.itemIndex,
            )..start();

            final remoteDir = p.dirname(entry.remotePath).replaceAll('\\', '/');
            try {
              await service.ensureRemoteDirectory(remoteDir, createdRemoteDirs);
              await service.uploadPath(
                localPath: entry.localPath,
                remoteDestination: entry.remotePath,
                recursive: false,
                onBytes: itemProgress.onBytes,
              );
              if (!context.mounted) return;
              successCount++;
              itemProgress.complete();
            } catch (error) {
              if (!context.mounted) return;
              failCount++;
              itemProgress.fail();
              AppLogger().warn(
                'Failed to upload ${entry.remotePath}',
                tag: 'Explorer',
                error: error,
              );
            }
          },
        );
      }

      if (uploadEntries.isEmpty) {
        try {
          await service.ensureRemoteDirectory(
            baseRemotePath,
            createdRemoteDirs,
          );
          successCount++;
        } catch (error) {
          failCount++;
          AppLogger().warn(
            'Failed to create empty folder $directoryName',
            tag: 'Explorer',
            error: error,
          );
        }
        final emptyIndex = uiItems.indexWhere(
          (item) => item.label == directoryName,
        );
        if (emptyIndex != -1) {
          progressController.markCompleted(emptyIndex);
        }
      }

      await transferSession.complete(
        successCount: failCount == 0
            ? directoryCounts.totalUnits
            : successCount,
        failCount: failCount,
        successVerb: 'Uploaded',
        cancelledMessage: 'Upload cancelled',
        refresh: refreshCurrentPath,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Directory upload failed',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      transferSession.fail(error, failedVerb: 'Upload');
    }
  }

  Future<void> handleDroppedPaths({
    required List<String> paths,
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    final context = uiAdapter.context;
    final toUpload = paths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (toUpload.isEmpty) {
      _showSnackBar('No valid paths to upload');
      return;
    }

    final items = await service.buildDroppedItems(toUpload);
    final uiItems = items
        .map(
          (item) =>
              FileOperationItem(label: item.label, sizeBytes: item.sizeBytes),
        )
        .toList();
    final totalItems = uiItems.isNotEmpty ? uiItems.length : toUpload.length;

    if (!context.mounted) {
      return;
    }
    final runtime = FileOperationTransferRuntime.show(
      context: context,
      operation: 'Uploading',
      totalItems: totalItems,
      items: uiItems.isEmpty ? null : uiItems,
      maxConcurrency: service.uploadConcurrency,
      showMessage: _showSnackBar,
    );
    final progressController = runtime.progressController;
    final transferSession = runtime.session;

    var successCount = 0;
    var failCount = 0;

    await service.runConcurrent(
      total: toUpload.length,
      maxConcurrency: () => progressController.maxConcurrency,
      isCancelled: () => progressController.cancelled,
      task: (i) async {
        if (!context.mounted) {
          return;
        }
        if (progressController.cancelled) {
          return;
        }
        final localPath = toUpload[i];
        final entityType = FileSystemEntity.typeSync(localPath);
        if (entityType == FileSystemEntityType.notFound) {
          failCount++;
          progressController.increment();
          return;
        }
        final name = p.basename(localPath);
        final remotePath = joinPath(
          targetDirectory,
          name,
        ).replaceAll('\\', '/');
        final itemIndex = uiItems.indexWhere((item) {
          return item.label == name || item.label.startsWith('$name/');
        });
        final itemProgress = FileOperationItemProgress(
          controller: progressController,
          label: name,
          itemIndex: itemIndex,
        )..start();

        try {
          final isDirectory = entityType == FileSystemEntityType.directory;
          await service.uploadPath(
            localPath: localPath,
            remoteDestination: remotePath,
            recursive: isDirectory,
            onBytes: itemProgress.onBytes,
          );
          successCount++;
          itemProgress.complete();
        } catch (error) {
          failCount++;
          AppLogger().warn(
            'Failed to upload dropped path $localPath',
            tag: 'Explorer',
            error: error,
          );
          itemProgress.fail();
        }
      },
    );

    await transferSession.complete(
      successCount: successCount,
      failCount: failCount,
      successVerb: 'Uploaded',
      cancelledMessage: 'Upload cancelled',
      refresh: refreshCurrentPath,
      refreshOnSuccessOnly: true,
    );
  }

  void _showSnackBar(String message) {
    uiAdapter.showSnackBar(message);
  }
}
