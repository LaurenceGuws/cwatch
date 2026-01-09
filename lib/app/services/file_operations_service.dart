import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/explorer_context.dart';
import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import '../../services/filesystem/explorer_trash_manager.dart';
import '../../services/logging/app_logger.dart';
import '../../services/settings/app_settings_controller.dart';
import '../../services/ssh/remote_shell_service.dart';
import 'explorer_clipboard.dart';

/// Service for handling file operations (copy, move, delete, download, upload)
class FileOperationsService {
  FileOperationsService({
    required this.shellService,
    required this.host,
    required this.settingsController,
    required this.trashManager,
    required this.runShellWrapper,
    required this.explorerContext,
  }) : assert(explorerContext.host == host);

  final RemoteShellService shellService;
  final SshHost host;
  final AppSettingsController settingsController;
  final ExplorerContext explorerContext;
  final ExplorerTrashManager trashManager;
  final Future<T> Function<T>(Future<T> Function() action) runShellWrapper;
  static const Duration _uploadTimeout = Duration(minutes: 20);

  int get uploadConcurrency =>
      settingsController.settings.fileTransferUploadConcurrency;
  int get downloadConcurrency =>
      settingsController.settings.fileTransferDownloadConcurrency;

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
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await runShellWrapper(
      () => shellService.downloadPath(
        host: host,
        remotePath: remotePath,
        localDestination: localDestination,
        recursive: recursive,
        onBytes: onBytes,
      ),
    );
  }

  /// Upload files/directories
  Future<void> uploadPath({
    required String localPath,
    required String remoteDestination,
    required bool recursive,
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await runShellWrapper(
      () => shellService.uploadPath(
        host: host,
        localPath: localPath,
        remoteDestination: remoteDestination,
        recursive: recursive,
        onBytes: onBytes,
      ),
    );
  }

  Future<DirectoryCountResult> countDirectoryEntries(
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
        AppLogger().warn(
          'Failed to count files in $directory',
          tag: 'Explorer',
          error: error,
        );
      }

      if (!hasFile) {
        emptyDirectories++;
      }
    }

    return DirectoryCountResult(
      fileCount: fileCount,
      emptyDirectories: emptyDirectories,
    );
  }

  Future<List<TransferItem>> buildFileItems(
    List<TransferItemInput> files,
  ) async {
    final items = <TransferItem>[];
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
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to stat file ${file.path}',
            tag: 'Explorer',
            error: error,
            stackTrace: stackTrace,
          );
          size = 0;
        }
      } else if (file.bytes != null) {
        size = file.bytes!.length;
      }
      items.add(TransferItem(label: name, sizeBytes: size));
    }
    return items;
  }

  Future<List<TransferItem>> buildDirectoryItems(
    String directoryPath,
    String directoryName,
  ) async {
    final items = <TransferItem>[];
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
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to stat file ${entity.path}',
            tag: 'Explorer',
            error: error,
            stackTrace: stackTrace,
          );
          size = 0;
        }
        items.add(
          TransferItem(label: '$directoryName/$relativePath', sizeBytes: size),
        );
      }
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to enumerate directory $directoryPath',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!hasFiles) {
      items.add(TransferItem(label: directoryName, sizeBytes: 0));
    }
    return items;
  }

  Future<List<TransferItem>> buildDroppedItems(List<String> paths) async {
    final items = <TransferItem>[];
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      final name = p.basename(path);
      if (type == FileSystemEntityType.directory) {
        items.addAll(await buildDirectoryItems(path, name));
      } else if (type == FileSystemEntityType.file) {
        var size = 0;
        try {
          final stat = await FileStat.stat(path);
          size = stat.size;
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to stat dropped path $path',
            tag: 'Explorer',
            error: error,
            stackTrace: stackTrace,
          );
          size = 0;
        }
        items.add(TransferItem(label: name, sizeBytes: size));
      }
    }
    return items;
  }

  Future<void> ensureRemoteDirectory(
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

  Future<void> runConcurrent({
    required int total,
    required int Function() maxConcurrency,
    required bool Function() isCancelled,
    required Future<void> Function(int index) task,
  }) async {
    var active = 0;
    var nextIndex = 0;
    final completer = Completer<void>();

    void schedule() {
      if (isCancelled()) {
        if (active == 0 && !completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      final limit = maxConcurrency().clamp(1, 15);
      while (active < limit && nextIndex < total && !isCancelled()) {
        final index = nextIndex++;
        active++;
        unawaited(() async {
          try {
            await task(index);
          } finally {
            active--;
            schedule();
          }
        }());
      }
      if (active == 0 && nextIndex >= total && !completer.isCompleted) {
        completer.complete();
      }
    }

    schedule();
    await completer.future;
  }

  Future<List<UploadEntry>> collectDirectoryUploads({
    required String directoryPath,
    required String directoryName,
    required String baseRemotePath,
    required Map<String, int> itemIndexByLabel,
    required String Function(String, String) joinPath,
  }) async {
    final entries = <UploadEntry>[];
    try {
      await for (final entity in Directory(
        directoryPath,
      ).list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = p
            .relative(entity.path, from: directoryPath)
            .replaceAll('\\', '/');
        final remotePath = joinPath(
          baseRemotePath,
          relativePath,
        ).replaceAll('\\', '/');
        final itemLabel = '$directoryName/$relativePath';
        final itemIndex = itemIndexByLabel[itemLabel] ?? -1;
        entries.add(
          UploadEntry(
            localPath: entity.path,
            remotePath: remotePath,
            itemIndex: itemIndex,
          ),
        );
      }
    } catch (error) {
      AppLogger().warn(
        'Failed to read directory $directoryPath',
        tag: 'Explorer',
        error: error,
      );
    }
    return entries;
  }

  Future<List<DownloadEntry>> collectDownloadEntries({
    required List<RemoteFileEntry> entries,
    required String baseRemotePath,
    required String baseLocalDir,
    required String Function(String, String) joinPath,
  }) async {
    final results = <DownloadEntry>[];

    Future<void> walkDirectory({
      required String remotePath,
      required String labelPrefix,
    }) async {
      final children = await listRemoteDirectory(remotePath);
      if (children.isEmpty) {
        results.add(
          DownloadEntry(
            label: labelPrefix,
            remotePath: remotePath,
            localDestination: p.join(baseLocalDir, labelPrefix),
            sizeBytes: 0,
            isDirectory: true,
          ),
        );
        return;
      }
      for (final child in children) {
        final childLabel = labelPrefix.isEmpty
            ? child.name
            : '$labelPrefix/${child.name}';
        final childRemote = joinPath(remotePath, child.name);
        if (child.isDirectory) {
          await walkDirectory(remotePath: childRemote, labelPrefix: childLabel);
        } else {
          results.add(
            DownloadEntry(
              label: childLabel,
              remotePath: childRemote,
              localDestination: p.join(baseLocalDir, p.dirname(childLabel)),
              sizeBytes: child.sizeBytes,
              isDirectory: false,
            ),
          );
        }
      }
    }

    for (final entry in entries) {
      final remotePath = joinPath(baseRemotePath, entry.name);
      if (entry.isDirectory) {
        await walkDirectory(remotePath: remotePath, labelPrefix: entry.name);
      } else {
        results.add(
          DownloadEntry(
            label: entry.name,
            remotePath: remotePath,
            localDestination: baseLocalDir,
            sizeBytes: entry.sizeBytes,
            isDirectory: false,
          ),
        );
      }
    }

    return results;
  }

  Future<List<RemoteFileEntry>> listRemoteDirectory(String remotePath) async {
    try {
      final entries = await runShellWrapper(
        () => shellService.listDirectory(host, remotePath),
      );
      return entries
          .where((entry) => entry.name != '.' && entry.name != '..')
          .toList();
    } catch (error) {
      AppLogger().warn(
        'Failed to list $remotePath',
        tag: 'Explorer',
        error: error,
      );
      return const [];
    }
  }

  Future<void> copyAcrossContexts(
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
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to clean up temp directory ${tempDir.path}',
          tag: 'Explorer',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}

class UploadEntry {
  const UploadEntry({
    required this.localPath,
    required this.remotePath,
    required this.itemIndex,
  });

  final String localPath;
  final String remotePath;
  final int itemIndex;
}

class DownloadEntry {
  const DownloadEntry({
    required this.label,
    required this.remotePath,
    required this.localDestination,
    required this.sizeBytes,
    required this.isDirectory,
  });

  final String label;
  final String remotePath;
  final String localDestination;
  final int sizeBytes;
  final bool isDirectory;
}

class DirectoryCountResult {
  const DirectoryCountResult({
    required this.fileCount,
    required this.emptyDirectories,
  });

  final int fileCount;
  final int emptyDirectories;

  int get totalUnits => fileCount + emptyDirectories;
}

class TransferItem {
  const TransferItem({required this.label, required this.sizeBytes});

  final String label;
  final int sizeBytes;
}

class TransferItemInput {
  const TransferItemInput({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final List<int>? bytes;
}
