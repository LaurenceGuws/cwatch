import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../explorer_clipboard.dart';
import '../../../../widgets/file_operation_progress_dialog.dart';

/// Service for handling file operations (copy, move, delete, download, upload)
class FileOperationsService {
  FileOperationsService({
    required this.shellService,
    required this.host,
    required this.trashManager,
    required this.runShellWrapper,
  });

  final RemoteShellService shellService;
  final SshHost host;
  final ExplorerTrashManager trashManager;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;

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
    await runShellWrapper(
      () => shellService.deletePath(host, path),
    );
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
        operation: clipboardEntries.first.operation == ExplorerClipboardOperation.copy
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
      if (clipboard.host.name == host.name &&
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
        if (clipboard.host.name == host.name) {
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
          await runShellWrapper(
            () => shellService.copyBetweenHosts(
              sourceHost: clipboard.host,
              sourcePath: clipboard.remotePath,
              destinationHost: host,
              destinationPath: destinationPath,
              recursive: clipboard.isDirectory,
            ),
          );
          if (clipboard.operation == ExplorerClipboardOperation.cut) {
            await runShellWrapper(
              () => shellService.deletePath(clipboard.host, clipboard.remotePath),
            );
            cutEntries.add(clipboard);
          }
          successCount++;
        }
        if (progressController != null) {
          progressController.increment();
        }
      } catch (error) {
        failCount++;
        AppLogger.w('Failed to paste ${clipboard.displayName}', tag: 'Explorer', error: error);
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
            final downloadsDir = Directory(p.join(externalDir.path, 'Downloads'));
            selectedDirectory = downloadsDir.path;
          } else {
            // Last resort: use app's documents directory
            final appDir = await getApplicationDocumentsDirectory();
            final downloadsDir = Directory(p.join(appDir.path, 'Downloads'));
            selectedDirectory = downloadsDir.path;
          }
        } catch (e) {
          AppLogger.w('Failed to get Android storage directory', tag: 'Explorer', error: e);
          // Show error and return
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to access download directory')),
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
      if (entries.length == 1) {
        // Single file/directory download
        progressController.updateProgress(currentItem: entries.first.name);
        await _downloadSingleEntry(entries.first, downloadDir.path, currentPath, joinPath);
        progressController.increment();
      } else {
        // Multiple files/directories download - download to temp then zip
        final tempDir = await Directory.systemTemp.createTemp(
          'cwatch-download-${DateTime.now().microsecondsSinceEpoch}',
        );
        try {
          // Download all entries to temp directory
          for (var i = 0; i < entries.length; i++) {
            final entry = entries[i];
            if (!context.mounted) return;

            progressController.updateProgress(currentItem: entry.name);
            final remotePath = joinPath(currentPath, entry.name);
            await downloadPath(
              remotePath: remotePath,
              localDestination: tempDir.path,
              recursive: entry.isDirectory,
            );
            if (!context.mounted) return;
            progressController.increment();
          }

          // Create zip archive for multiple items
          if (!context.mounted) return;
          progressController.updateProgress(
            currentItem: 'Creating archive...',
          );
          await _createZipArchiveFromTemp(entries, tempDir.path, downloadDir.path);
          if (!context.mounted) return;
        } finally {
          await tempDir.delete(recursive: true);
        }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _downloadSingleEntry(
    RemoteFileEntry entry,
    String downloadDir,
    String currentPath,
    String Function(String, String) joinPath,
  ) async {
    final remotePath = joinPath(currentPath, entry.name);

    if (entry.isDirectory) {
      // Download directory to temp first, then compress
      final tempDir = await Directory.systemTemp.createTemp(
        'cwatch-download-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        // Download to temp directory first
        await downloadPath(
          remotePath: remotePath,
          localDestination: tempDir.path,
          recursive: true,
        );

        // Find the downloaded directory
        final downloadedPath = p.join(tempDir.path, entry.name);
        final downloadedDir = Directory(downloadedPath);
        if (!await downloadedDir.exists()) {
          throw Exception('Downloaded directory not found');
        }

        // Create zip archive
        final archive = Archive();
        await _addDirectoryToArchive(archive, downloadedDir, entry.name);

        // Write zip file
        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        final zipFile = File(p.join(downloadDir, '${entry.name}.zip'));
        await zipFile.writeAsBytes(zipBytes);
      } finally {
        await tempDir.delete(recursive: true);
      }
    } else {
      // Download single file
      await downloadPath(
        remotePath: remotePath,
        localDestination: downloadDir,
        recursive: false,
      );
    }
  }

  Future<void> _createZipArchiveFromTemp(
    List<RemoteFileEntry> entries,
    String tempDir,
    String downloadDir,
  ) async {
    // Create a zip archive containing all downloaded items
    final archive = Archive();
    for (final entry in entries) {
      final downloadedPath = p.join(tempDir, entry.name);
      final downloadedEntity = FileSystemEntity.typeSync(downloadedPath);
      if (downloadedEntity == FileSystemEntityType.directory) {
        await _addDirectoryToArchive(
          archive,
          Directory(downloadedPath),
          entry.name,
        );
      } else if (downloadedEntity == FileSystemEntityType.file) {
        final file = File(downloadedPath);
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(entry.name, bytes.length, bytes),
        );
      }
    }

    // Write zip file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    // Use a default name
    final zipFileName = entries.length == 1
        ? '${entries.first.name}.zip'
        : 'download_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(p.join(downloadDir, zipFileName));
    await zipFile.writeAsBytes(zipBytes);
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory directory,
    String archivePath,
  ) async {
    await for (final entity in directory.list(recursive: false)) {
      final name = p.basename(entity.path);
      final entryPath = p.join(archivePath, name).replaceAll('\\', '/');

      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, entryPath);
      }
    }
  }

  /// Handle upload operation
  Future<void> handleUpload({
    required BuildContext context,
    required String targetDirectory,
    required String Function(String, String) joinPath,
    required Future<void> Function() refreshCurrentPath,
  }) async {
    // Prompt user to select files/directories to upload
    FilePickerResult? result;
    // On mobile, file picker works differently - use pickFiles for all platforms
    // On Android, we need to load bytes explicitly
    result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select files to upload',
      withData: Platform.isAndroid, // Load file data on Android
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    // On Android, accept files even if path is null (bytes might be available)
    // On other platforms, require path
    final files = Platform.isAndroid
        ? result.files.where((f) => f.path != null || (f.bytes != null && f.bytes!.isNotEmpty)).toList()
        : result.files.where((f) => f.path != null).toList();
    
    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid files selected')),
        );
      }
      return;
    }

    // Show progress dialog
    if (!context.mounted) return;
    final progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Uploading',
      totalItems: files.length,
    );

    try {
      int successCount = 0;
      int failCount = 0;

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        
        if (!context.mounted) {
          return;
        }

        // Get file name - prefer name from PlatformFile, fallback to path basename
        final fileName = file.name.isNotEmpty 
            ? file.name 
            : (file.path != null ? p.basename(file.path!) : 'file_$i');
        final remotePath = joinPath(targetDirectory, fileName);

        progressController.updateProgress(currentItem: fileName);

        try {
          // On Android, file_picker may return files that aren't directly accessible via path
          // Try to read bytes directly from PlatformFile if available
          List<int>? fileBytes;
          
          // First, try to get bytes from PlatformFile (works on Android)
          if (file.bytes != null && file.bytes!.isNotEmpty) {
            fileBytes = file.bytes;
            AppLogger.d(
              'Using PlatformFile.bytes for $fileName (${fileBytes?.length ?? 0} bytes)',
              tag: 'Explorer',
            );
          } else if (file.path != null && file.path!.isNotEmpty) {
            // Try to read from path if bytes aren't available
            try {
              final localFile = File(file.path!);
              if (await localFile.exists()) {
                final localEntity = FileSystemEntity.typeSync(file.path!);
                final isDirectory = localEntity == FileSystemEntityType.directory;
                if (isDirectory) {
                  // Directories need to use uploadPath
                  await uploadPath(
                    localPath: file.path!,
                    remoteDestination: remotePath,
                    recursive: true,
                  );
                  if (!context.mounted) return;
                  successCount++;
                  progressController.increment();
                  continue;
                } else {
                  fileBytes = await localFile.readAsBytes();
                  AppLogger.d(
                    'Read file from path $fileName (${fileBytes.length} bytes)',
                    tag: 'Explorer',
                  );
                }
              } else {
                throw Exception('File does not exist: ${file.path}');
              }
            } catch (e) {
              AppLogger.w(
                'Failed to read file from path ${file.path}',
                tag: 'Explorer',
                error: e,
              );
              throw Exception('Cannot read file: $e');
            }
          } else {
            throw Exception('File has no accessible path or bytes');
          }

          if (fileBytes != null && fileBytes.isNotEmpty) {
            // Use bytes-based upload (works better on Android)
            if (shellService is BuiltInRemoteShellService) {
              AppLogger.d(
                'Uploading $fileName to $remotePath using uploadBytes (${fileBytes.length} bytes)',
                tag: 'Explorer',
              );
              await runShellWrapper(
                () => (shellService as BuiltInRemoteShellService).uploadBytes(
                  host: host,
                  bytes: fileBytes!,
                  remoteDestination: remotePath,
                ),
              );
              AppLogger.d('Successfully uploaded $fileName', tag: 'Explorer');
            } else {
              // Fallback: write to temp file and upload
              final tempFile = File('${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
              await tempFile.writeAsBytes(fileBytes);
              try {
                await uploadPath(
                  localPath: tempFile.path,
                  remoteDestination: remotePath,
                  recursive: false,
                );
              } finally {
                if (await tempFile.exists()) {
                  await tempFile.delete();
                }
              }
            }
          } else {
            throw Exception('File bytes are empty or null');
          }
          if (!context.mounted) return;
          successCount++;
        } catch (error) {
          if (!context.mounted) return;
          failCount++;
          AppLogger.w('Failed to upload $fileName', tag: 'Explorer', error: error);
          AppLogger.d(
            'File details: path=${file.path}, name=${file.name}, bytes=${file.bytes?.length ?? 0}',
            tag: 'Explorer',
          );
        }

        if (!context.mounted) return;
        progressController.increment();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    }
  }
}
