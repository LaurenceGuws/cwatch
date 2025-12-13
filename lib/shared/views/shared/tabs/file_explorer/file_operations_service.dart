import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'explorer_clipboard.dart';
import '../../../../widgets/file_operation_progress_dialog.dart';

/// Service for handling file operations (copy, move, delete, download, upload)
class FileOperationsService {
  FileOperationsService({
    required this.shellService,
    required this.host,
    required this.trashManager,
    required this.runShellWrapper,
    required this.explorerContext,
  }) : assert(explorerContext.host == host);

  final RemoteShellService shellService;
  final SshHost host;
  final ExplorerContext explorerContext;
  final ExplorerTrashManager trashManager;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  static const Duration _uploadTimeout = Duration(minutes: 20);

  /// Copy files/directories
  Future<void> copyPath(
    String sourcePath,
    String destinationPath, {
    required bool recursive,
  }) async {
    await runShellWrapper(
      () => shellService.copyPath(
        host,
        sourcePath,
        destinationPath,
        recursive: recursive,
      ),
    );
  }

  /// Move files/directories
  Future<void> movePath(String sourcePath, String destinationPath) async {
    await runShellWrapper(
      () => shellService.movePath(host, sourcePath, destinationPath),
    );
  }

  /// Delete files/directories
  Future<void> deletePath(String path) async {
    await runShellWrapper(() => shellService.deletePath(host, path));
  }

  /// Download files/directories
  Future<void> downloadPath({
    required String remotePath,
    required String localDestination,
    required bool recursive,
  }) async {
    await runShellWrapper(
      () => shellService.downloadPath(
        host: host,
        remotePath: remotePath,
        localDestination: localDestination,
        recursive: recursive,
      ),
    );
  }

  /// Upload files/directories
  Future<void> uploadPath({
    required String localPath,
    required String remoteDestination,
    required bool recursive,
  }) async {
    await runShellWrapper(
      () => shellService.uploadPath(
        host: host,
        localPath: localPath,
        remoteDestination: remoteDestination,
        recursive: recursive,
      ),
    );
  }

  /// Handle paste operation
  Future<void> handlePaste({
    required BuildContext context,
    required String targetDirectory,
    required String currentPath,
    required String Function(String, String) joinPath,
    required String Function(String) normalizePath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    final clipboardEntries = ExplorerClipboard.entries;
    if (clipboardEntries.isEmpty) {
      return;
    }
    final destinationDir = normalizePath(targetDirectory);
    final refreshCurrent = destinationDir == currentPath;

    // Show progress dialog for multiple items
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

      // Skip if pasting to same location
      if (clipboard.contextId == explorerContext.id &&
          clipboard.remotePath == destinationPath) {
        if (progressController != null) {
          progressController.increment();
        }
        continue;
      }

      // Update progress
      if (progressController != null) {
        progressController.updateProgress(currentItem: clipboard.displayName);
      }

      try {
        final isSameContext = clipboard.contextId == explorerContext.id;
        if (isSameContext) {
          if (clipboard.operation == ExplorerClipboardOperation.copy) {
            await copyPath(
              clipboard.remotePath,
              destinationPath,
              recursive: clipboard.isDirectory,
            );
            successCount++;
          } else {
            await movePath(clipboard.remotePath, destinationPath);
            cutEntries.add(clipboard);
            successCount++;
          }
        } else {
          await _copyAcrossContexts(
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
        AppLogger.w(
          'Failed to paste ${clipboard.displayName}',
          tag: 'Explorer',
          error: error,
        );
        if (progressController != null) {
          progressController.increment();
        }
      }
    }

    // Close progress dialog if shown
    if (progressController != null && context.mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    // Notify cut completion for all cut entries
    if (cutEntries.isNotEmpty) {
      ExplorerClipboard.notifyCutsCompleted(cutEntries);
    }

    if (refreshCurrent) {
      await refreshCurrentPath();
    }
    if (!context.mounted) return;

    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount == 1
                ? 'Pasted ${clipboardEntries.first.displayName}'
                : 'Pasted $successCount item${successCount > 1 ? 's' : ''}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pasted $successCount item${successCount > 1 ? 's' : ''}. $failCount failed.',
          ),
        ),
      );
    }
  }

  /// Handle download operation
  Future<void> handleDownload({
    required BuildContext context,
    required List<RemoteFileEntry> entries,
    required String currentPath,
    required String Function(String, String) joinPath,
  }) async {
    if (entries.isEmpty) {
      return;
    }

    // Prompt user to select download directory
    String? selectedDirectory;
    if (Platform.isAndroid) {
      // On Android, use file_picker to select directory
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select download location',
      );
      // Fallback to app's external storage Downloads directory if user cancels
      if (selectedDirectory == null) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final downloadsDir = Directory(
              p.join(externalDir.path, 'Downloads'),
            );
            selectedDirectory = downloadsDir.path;
          } else {
            // Last resort: use app's documents directory
            final appDir = await getApplicationDocumentsDirectory();
            final downloadsDir = Directory(p.join(appDir.path, 'Downloads'));
            selectedDirectory = downloadsDir.path;
          }
        } catch (e) {
          AppLogger.w(
            'Failed to get Android storage directory',
            tag: 'Explorer',
            error: e,
          );
          // Show error and return
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to access download directory'),
              ),
            );
          }
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

    // Show progress dialog
    if (!context.mounted) return;
    final progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Downloading',
      totalItems: entries.length,
    );

    try {
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (!context.mounted) return;

        progressController.updateProgress(currentItem: entry.name);
        final remotePath = joinPath(currentPath, entry.name);
        await downloadPath(
          remotePath: remotePath,
          localDestination: downloadDir.path,
          recursive: entry.isDirectory,
        );
        if (!context.mounted) return;
        progressController.increment();
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded ${entries.length} item${entries.length > 1 ? 's' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
    }
  }

  /// Handle upload operation
  Future<void> handleUploadFiles({
    required BuildContext context,
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    // Prompt user to select files/directories to upload
    FilePickerResult? result;
    result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select files to upload',
      // Avoid loading entire files into memory (especially videos) on mobile.
      withData: false,
    );

    final resultFiles = result?.files ?? const <PlatformFile>[];

    if (result == null || resultFiles.isEmpty) {
      return;
    }

    final files = resultFiles.where((f) => f.path != null).toList();

    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid files selected')),
        );
      }
      return;
    }

    final items = await _buildFileItems(files);

    // Show progress dialog
    if (!context.mounted) return;
    late final FileOperationProgressController progressController;
    progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Uploading',
      totalItems: items.length,
      items: items,
      onCancel: () {
        progressController.cancel();
      },
    );

    try {
      int successCount = 0;
      int failCount = 0;

      for (var i = 0; i < files.length; i++) {
        final file = files[i];

        if (!context.mounted) {
          return;
        }
        if (progressController.cancelled) {
          break;
        }

        // Get file name - prefer name from PlatformFile, fallback to path basename
        final fileName = file.name.isNotEmpty
            ? file.name
            : (file.path != null ? p.basename(file.path!) : 'file_$i');
        final remotePath = joinPath(targetDirectory, fileName);

        progressController.markInProgress(i);

        try {
          if (file.path == null || file.path!.isEmpty) {
            throw Exception('File has no accessible path');
          }

          final localEntityType = FileSystemEntity.typeSync(file.path!);
          final isDirectory = localEntityType == FileSystemEntityType.directory;

          if (isDirectory) {
            failCount++;
            AppLogger.w(
              'Skipping directory in file upload: ${file.path}',
              tag: 'Explorer',
            );
            progressController.markFailed(i);
            continue;
          }

          // Stream from path to avoid loading full file into memory and report progress
          await uploadPath(
            localPath: file.path!,
            remoteDestination: remotePath,
            recursive: false,
          );
          if (!context.mounted) return;
          successCount++;
          progressController.markCompleted(i, addSize: true);
        } catch (error) {
          if (!context.mounted) return;
          failCount++;
          progressController.markFailed(i);
          AppLogger.w(
            'Failed to upload $fileName',
            tag: 'Explorer',
            error: error,
          );
          AppLogger.d(
            'File details: path=${file.path}, name=${file.name}, bytes=${file.bytes?.length ?? 0}',
            tag: 'Explorer',
          );
        }
      }

      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await refreshCurrentPath();

      if (!context.mounted) return;
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount item${successCount > 1 ? 's' : ''}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount item${successCount > 1 ? 's' : ''}. $failCount failed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<void> handleUploadFolder({
    required BuildContext context,
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
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

    final directoryCounts = await _countDirectoryEntries([directoryPath]);
    final totalItems = directoryCounts.totalUnits == 0
        ? 1
        : directoryCounts.totalUnits;
    final items = await _buildDirectoryItems(directoryPath, directoryName);

    if (!context.mounted) return;
    late final FileOperationProgressController progressController;
    progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Uploading',
      totalItems: totalItems,
      items: items,
      onCancel: () {
        progressController.cancel();
      },
    );

    try {
      int successCount = 0;
      int failCount = 0;

      try {
        await _ensureRemoteDirectory(remoteBaseDir, createdRemoteDirs);
      } catch (error) {
        if (!context.mounted) return;
        failCount++;
        AppLogger.w(
          'Failed to prepare remote directory for $directoryName',
          tag: 'Explorer',
          error: error,
        );
        progressController.increment();
        return;
      }

      var hasFiles = false;
      try {
        await for (final entity in Directory(
          directoryPath,
        ).list(recursive: true, followLinks: false)) {
          if (!context.mounted) {
            return;
          }
          if (progressController.cancelled) {
            break;
          }
          if (entity is! File) {
            continue;
          }
          hasFiles = true;
          final relativePath = p
              .relative(entity.path, from: directoryPath)
              .replaceAll('\\', '/');
          final remotePath = joinPath(
            baseRemotePath,
            relativePath,
          ).replaceAll('\\', '/');
          final remoteDir = p.dirname(remotePath).replaceAll('\\', '/');
          final itemLabel = '$directoryName/$relativePath';
          final itemIndex = items.indexWhere((i) => i.label == itemLabel);
          if (itemIndex != -1) {
            progressController.markInProgress(itemIndex);
          }

          try {
            await _ensureRemoteDirectory(remoteDir, createdRemoteDirs);
            await uploadPath(
              localPath: entity.path,
              remoteDestination: remotePath,
              recursive: false,
            );
            if (!context.mounted) return;
            successCount++;
            if (itemIndex != -1) {
              progressController.markCompleted(itemIndex, addSize: true);
            }
          } catch (error) {
            if (!context.mounted) return;
            failCount++;
            if (itemIndex != -1) {
              progressController.markFailed(itemIndex);
            }
            AppLogger.w(
              'Failed to upload $remotePath',
              tag: 'Explorer',
              error: error,
            );
          }
        }
      } catch (error) {
        if (!context.mounted) return;
        failCount++;
        AppLogger.w(
          'Failed to read directory $directoryPath',
          tag: 'Explorer',
          error: error,
        );
      }

      if (!hasFiles) {
        try {
          await _ensureRemoteDirectory(baseRemotePath, createdRemoteDirs);
          successCount++;
        } catch (error) {
          failCount++;
          AppLogger.w(
            'Failed to create empty folder $directoryName',
            tag: 'Explorer',
            error: error,
          );
        }
        final emptyIndex = items.indexWhere((i) => i.label == directoryName);
        if (emptyIndex != -1) {
          progressController.markCompleted(emptyIndex);
        }
      }

      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await refreshCurrentPath();

      if (!context.mounted) return;
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded ${directoryCounts.totalUnits} item${directoryCounts.totalUnits == 1 ? '' : 's'}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount item${successCount == 1 ? '' : 's'}. $failCount failed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<_DirectoryCountResult> _countDirectoryEntries(
    List<String> directories,
  ) async {
    var fileCount = 0;
    var emptyDirectories = 0;

    for (final directory in directories) {
      var hasFile = false;
      try {
        final dir = Directory(directory);
        if (!await dir.exists()) {
          continue;
        }
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            hasFile = true;
            fileCount++;
          }
        }
      } catch (error) {
        AppLogger.w(
          'Failed to count files in $directory',
          tag: 'Explorer',
          error: error,
        );
      }

      if (!hasFile) {
        emptyDirectories++;
      }
    }

    return _DirectoryCountResult(
      fileCount: fileCount,
      emptyDirectories: emptyDirectories,
    );
  }

  Future<List<FileOperationItem>> _buildFileItems(
    List<PlatformFile> files,
  ) async {
    final items = <FileOperationItem>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final name = file.name.isNotEmpty
          ? file.name
          : (file.path != null ? p.basename(file.path!) : 'file_$i');
      var size = 0;
      if (file.path != null && file.path!.isNotEmpty) {
        try {
          final stat = await FileStat.stat(file.path!);
          size = stat.size;
        } catch (_) {
          size = 0;
        }
      } else if (file.bytes != null) {
        size = file.bytes!.length;
      }
      items.add(FileOperationItem(label: name, sizeBytes: size));
    }
    return items;
  }

  Future<List<FileOperationItem>> _buildDirectoryItems(
    String directoryPath,
    String directoryName,
  ) async {
    final items = <FileOperationItem>[];
    var hasFiles = false;
    try {
      await for (final entity in Directory(
        directoryPath,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        hasFiles = true;
        final relativePath = p
            .relative(entity.path, from: directoryPath)
            .replaceAll('\\', '/');
        var size = 0;
        try {
          final stat = await entity.stat();
          size = stat.size;
        } catch (_) {
          size = 0;
        }
        items.add(
          FileOperationItem(
            label: '$directoryName/$relativePath',
            sizeBytes: size,
          ),
        );
      }
    } catch (_) {
      // Counting errors are logged during upload; ignore here.
    }
    if (!hasFiles) {
      items.add(FileOperationItem(label: directoryName, sizeBytes: 0));
    }
    return items;
  }

  Future<void> _ensureRemoteDirectory(
    String remotePath,
    Set<String> created,
  ) async {
    if (created.contains(remotePath) ||
        remotePath.isEmpty ||
        remotePath == '.') {
      return;
    }
    final escaped = remotePath.replaceAll("'", r"'\''");
    await runShellWrapper(
      () => shellService.runCommand(host, "mkdir -p '$escaped'"),
    );
    created.add(remotePath);
  }

  Future<void> _copyAcrossContexts(
    ExplorerClipboardEntry entry,
    String destinationPath, {
    required bool move,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cwatch-explorer-copy-',
    );
    try {
      await entry.shellService.downloadPath(
        host: entry.host,
        remotePath: entry.remotePath,
        localDestination: tempDir.path,
        recursive: entry.isDirectory,
        timeout: _uploadTimeout,
      );
      final payloadPath = p.join(tempDir.path, p.basename(entry.remotePath));
      await uploadPath(
        localPath: payloadPath,
        remoteDestination: destinationPath,
        recursive: entry.isDirectory,
      );
      if (move) {
        await entry.shellService.deletePath(entry.host, entry.remotePath);
      }
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Ignore cleanup failures.
      }
    }
  }
}

class _DirectoryCountResult {
  const _DirectoryCountResult({
    required this.fileCount,
    required this.emptyDirectories,
  });

  final int fileCount;
  final int emptyDirectories;

  int get totalUnits => fileCount + emptyDirectories;
}
