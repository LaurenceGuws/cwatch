import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../../../models/ssh_host.dart';
import '../remote_path_utils.dart';
import '../remote_shell_base.dart';
import 'builtin_ssh_client_manager.dart';
import 'builtin_ssh_logging.dart';

class BuiltInSftpTransfer with RemotePathUtils {
  BuiltInSftpTransfer(this._clientManager);

  final BuiltInSshClientManager _clientManager;

  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    final sanitized = sanitizePath(remotePath);
    final destinationDir = Directory(localDestination);
    await destinationDir.create(recursive: true);
    await _clientManager.withSftp(
      host,
      (sftp) async {
        final attrs = await _stat(sftp, sanitized);
        if (attrs.isDirectory) {
          if (!recursive) {
            throw Exception('Remote path is a directory; enable recursion.');
          }
          await _downloadDirectory(
            sftp,
            sanitized,
            destinationDir.path,
            onBytes: onBytes,
          );
          return;
        }
        final localTarget = p.join(destinationDir.path, p.basename(sanitized));
        await _downloadFile(
          sftp,
          sanitized,
          localTarget,
          onBytes: onBytes,
        );
      },
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  Future<void> downloadPaths({
    required SshHost host,
    required List<RemotePathDownload> downloads,
    Duration timeout = const Duration(minutes: 2),
    void Function(RemotePathDownload download, Object error)? onError,
    RunTimeoutHandler? onTimeout,
  }) async {
    if (downloads.isEmpty) {
      return;
    }
    for (final download in downloads) {
      final destinationDir = Directory(download.localDestination);
      await destinationDir.create(recursive: true);
    }
    await _clientManager.withSftp(
      host,
      (sftp) async {
        for (final download in downloads) {
          try {
            final sanitized = sanitizePath(download.remotePath);
            final destinationDir = Directory(download.localDestination);
            final attrs = await _stat(sftp, sanitized);
            if (attrs.isDirectory) {
              if (!download.recursive) {
                throw Exception(
                  'Remote path is a directory; enable recursion.',
                );
              }
              await _downloadDirectory(
                sftp,
                sanitized,
                destinationDir.path,
                onBytes: download.onBytes,
              );
              continue;
            }
            final localTarget = p.join(
              destinationDir.path,
              p.basename(sanitized),
            );
            await _downloadFile(
              sftp,
              sanitized,
              localTarget,
              onBytes: download.onBytes,
            );
          } catch (error) {
            logBuiltInSshWarning(
              'Failed to download ${download.remotePath} from ${host.name}',
              error: error,
            );
            if (onError == null) {
              rethrow;
            }
            onError(download, error);
          }
        }
      },
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
    void Function(int bytesTransferred)? onBytes,
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedDest = sanitizePath(remoteDestination);
    final entryType = FileSystemEntity.typeSync(localPath);
    final entryTypeLabel = entryType.toString().split('.').last;
    logBuiltInSsh(
      'Upload request to ${host.name} (${host.hostname}:${host.port}) '
      'user=${host.user ?? 'root'} '
      'local=$localPath -> remote=$normalizedDest '
      'type=$entryTypeLabel recursive=$recursive',
    );
    if (entryType == FileSystemEntityType.notFound ||
        entryType == FileSystemEntityType.link) {
      throw Exception(
        'Local path "$localPath" is not found or not a regular file/directory.',
      );
    }
    await _clientManager.withSftp(
      host,
      (sftp) async {
        if (entryType == FileSystemEntityType.directory) {
          if (!recursive) {
            throw Exception('Uploading directories requires recursive flag.');
          }
          final remoteDir = _joinPath(normalizedDest, p.basename(localPath));
          await _ensureRemoteDirectory(sftp, dirnameFromPath(remoteDir));
          await _uploadDirectory(
            sftp,
            Directory(localPath),
            remoteDir,
            onBytes: onBytes,
          );
          return;
        }
        await _ensureRemoteDirectory(sftp, dirnameFromPath(normalizedDest));
        await _uploadFile(
          sftp,
          File(localPath),
          normalizedDest,
          onBytes: onBytes,
        );
      },
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  Future<void> uploadBytes({
    required SshHost host,
    required List<int> bytes,
    required String remoteDestination,
    Duration timeout = const Duration(minutes: 2),
    RunTimeoutHandler? onTimeout,
  }) async {
    final normalizedDest = sanitizePath(remoteDestination);
    await _clientManager.withSftp(
      host,
      (sftp) async {
        await _ensureRemoteDirectory(sftp, dirnameFromPath(normalizedDest));
        await _uploadBytes(sftp, bytes, normalizedDest);
      },
      timeout: timeout,
      onTimeout: onTimeout,
    );
  }

  Future<void> _downloadFile(
    SftpClient sftp,
    String remotePath,
    String localPath, {
    void Function(int bytesTransferred)? onBytes,
  }
  ) async {
    final file = await sftp.open(remotePath);
    final targetFile = File(localPath);
    await targetFile.create(recursive: true);
    final sink = targetFile.openWrite();
    try {
      await for (final chunk in file.read()) {
        if (chunk.isEmpty) continue;
        sink.add(chunk);
        onBytes?.call(chunk.length);
      }
      await sink.flush();
    } finally {
      await sink.close();
      await file.close();
    }
  }

  Future<void> _downloadDirectory(
    SftpClient sftp,
    String remotePath,
    String localDestination, {
    void Function(int bytesTransferred)? onBytes,
  }
  ) async {
    final target = p.join(localDestination, p.basename(remotePath));
    final dir = Directory(target);
    await dir.create(recursive: true);
    final entries = await sftp.listdir(remotePath);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') {
        continue;
      }
      final childRemote = _joinPath(remotePath, entry.filename);
      final childLocal = p.join(target, entry.filename);
      if (entry.attr.isDirectory) {
        await _downloadDirectory(
          sftp,
          childRemote,
          target,
          onBytes: onBytes,
        );
      } else {
        await _downloadFile(
          sftp,
          childRemote,
          childLocal,
          onBytes: onBytes,
        );
      }
    }
  }

  Future<void> _uploadFile(
    SftpClient sftp,
    File localFile,
    String remotePath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      var position = 0;
      await for (final chunk in localFile.openRead()) {
        if (chunk.isEmpty) continue;
        final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        await file.writeBytes(data, offset: position);
        position += data.length;
        onBytes?.call(data.length);
      }
    } catch (e) {
      logBuiltInSshWarning(
        'Error streaming $remotePath',
        error: e,
      );
      rethrow;
    } finally {
      await file.close();
    }
  }

  Future<void> _uploadBytes(
    SftpClient sftp,
    List<int> bytes,
    String remotePath,
  ) async {
    logBuiltInSsh('Uploading ${bytes.length} bytes to $remotePath');
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await file.writeBytes(data, offset: 0);
      logBuiltInSsh('Successfully wrote ${bytes.length} bytes to $remotePath');
    } catch (e) {
      logBuiltInSshWarning(
        'Error writing bytes to $remotePath',
        error: e,
      );
      rethrow;
    } finally {
      await file.close();
    }
  }

  Future<void> _uploadDirectory(
    SftpClient sftp,
    Directory localDir,
    String remoteRoot, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await _ensureRemoteDirectory(sftp, remoteRoot);
    await for (final entity in localDir.list(recursive: false)) {
      final name = p.basename(entity.path);
      final remotePath = _joinPath(remoteRoot, name);
      if (entity is Directory) {
        await _uploadDirectory(sftp, entity, remotePath, onBytes: onBytes);
      } else if (entity is File) {
        await _ensureRemoteDirectory(sftp, dirnameFromPath(remotePath));
        await _uploadFile(sftp, entity, remotePath, onBytes: onBytes);
      }
    }
  }

  Future<void> _ensureRemoteDirectory(SftpClient sftp, String path) async {
    final normalized = sanitizePath(path);
    if (normalized == '/' || normalized.isEmpty) {
      return;
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    var current = '';
    for (final segment in segments) {
      current = '$current/$segment';
      final exists = await _remotePathExists(sftp, current);
      if (exists) continue;
      try {
        await sftp.mkdir(current);
      } catch (error) {
        logBuiltInSshWarning(
          'Failed to create remote directory $current',
          error: error,
        );
      }
    }
  }

  Future<SftpFileAttrs> _stat(SftpClient sftp, String path) async {
    return await sftp.stat(path);
  }

  Future<bool> _remotePathExists(SftpClient sftp, String path) async {
    try {
      await sftp.stat(path);
      return true;
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return false;
      }
      logBuiltInSshWarning(
        'Failed to stat remote path $path',
        error: error,
      );
      rethrow;
    }
  }

  String _joinPath(String base, String segment) {
    if (segment.isEmpty) return base;
    final trimmedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmedBase/$segment';
  }
}
