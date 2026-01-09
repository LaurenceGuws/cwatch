import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../models/remote_file_entry.dart';
import '../../models/ssh_host.dart';
import '../../services/logging/app_logger.dart';
import '../../services/ssh/remote_shell_base.dart';
import '../../services/ssh/remote_shell_service.dart';
import '../../shared/views/shared/tabs/file_explorer/desktop_drag_source.dart';
import '../../shared/views/shared/tabs/file_explorer/drag_types.dart';
import '../../shared/views/shared/tabs/file_explorer/path_utils.dart';
import 'explorer_ui_adapter.dart';

/// Owns OS drag state + staging logic.
class ExplorerOsDragManager {
  ExplorerOsDragManager({
    required this.host,
    required this.shellService,
    required this.uiAdapter,
    required this.runShell,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final ExplorerUiAdapter uiAdapter;
  final Future<T> Function<T>(Future<T> Function() action) runShell;

  bool _osDragActive = false;
  String? _activeDragTempDir;
  String? _activeDragSourcePath;
  String? _lastDragTempDir;
  String? _lastDragSourcePath;
  DateTime? _lastDragExpiresAt;

  bool get isOsDragActive => _osDragActive;

  bool isSelfDragDrop({
    required List<String> paths,
    required String targetDirectory,
  }) {
    final now = DateTime.now();
    final expiry = _lastDragExpiresAt;
    if (expiry != null && now.isAfter(expiry)) {
      _lastDragTempDir = null;
      _lastDragSourcePath = null;
      _lastDragExpiresAt = null;
    }
    final tempDir = _activeDragTempDir ?? _lastDragTempDir;
    final sourcePath = _activeDragSourcePath ?? _lastDragSourcePath;
    if (tempDir == null || sourcePath == null) {
      return false;
    }
    if (targetDirectory != sourcePath) {
      return false;
    }
    return paths.isNotEmpty &&
        paths.every((path) => p.isWithin(tempDir, path) || path == tempDir);
  }

  bool isSelfDragTarget(String targetDirectory) {
    final now = DateTime.now();
    final expiry = _lastDragExpiresAt;
    if (expiry != null && now.isAfter(expiry)) {
      _lastDragTempDir = null;
      _lastDragSourcePath = null;
      _lastDragExpiresAt = null;
    }
    final sourcePath = _activeDragSourcePath ?? _lastDragSourcePath;
    if (sourcePath == null) {
      return false;
    }
    return targetDirectory == sourcePath;
  }

  Future<void> startOsDrag({
    required DesktopDragSource? dragSource,
    required Offset globalPosition,
    required List<RemoteFileEntry> entriesToDrag,
    required String currentPath,
  }) async {
    final source = dragSource;
    if (source == null || !source.isSupported) {
      uiAdapter.showDragNotSupported();
      return;
    }
    if (entriesToDrag.isEmpty) {
      uiAdapter.showNothingToDrag();
      return;
    }

    _osDragActive = true;
    final tempDir = await Directory.systemTemp.createTemp('cwatch-drag-');
    _activeDragTempDir = tempDir.path;
    _activeDragSourcePath = currentPath;
    _lastDragTempDir = tempDir.path;
    _lastDragSourcePath = currentPath;
    _lastDragExpiresAt = DateTime.now().add(const Duration(minutes: 2));

    try {
      final staged = <DragLocalItem>[];
      final downloads = <RemotePathDownload>[];
      for (final entry in entriesToDrag) {
        final remotePath = PathUtils.joinPath(currentPath, entry.name);
        final localTarget = p.join(tempDir.path, entry.name);
        downloads.add(
          RemotePathDownload(
            remotePath: remotePath,
            localDestination: tempDir.path,
            recursive: entry.isDirectory,
          ),
        );
        staged.add(
          DragLocalItem(
            localPath: localTarget,
            displayName: entry.name,
            isDirectory: entry.isDirectory,
            remotePath: remotePath,
          ),
        );
      }

      await runShell(
        () => shellService.downloadPaths(
          host: host,
          downloads: downloads,
          onError: (download, error) {
            AppLogger().warn(
              'Failed to stage ${download.remotePath} for drag',
              tag: 'Explorer',
              error: error,
            );
          },
        ),
      );

      staged.removeWhere((item) {
        if (item.isDirectory) {
          return !Directory(item.localPath).existsSync();
        }
        return !File(item.localPath).existsSync();
      });

      if (staged.isEmpty) {
        uiAdapter.showNothingToDrag();
        return;
      }

      final result = await uiAdapter.startDesktopDrag(
        source: source,
        globalPosition: globalPosition,
        items: staged,
      );

      if (result.started) {
        uiAdapter.showDragStarted();
      } else if (result.error != null) {
        uiAdapter.showSnackBar(result.error!);
      }
    } finally {
      _osDragActive = false;
      _activeDragTempDir = null;
      _activeDragSourcePath = null;

      // Cleanup temp dir later.
      Future<void>.delayed(const Duration(minutes: 2), () async {
        try {
          await tempDir.delete(recursive: true);
        } catch (error, stackTrace) {
          AppLogger().warn(
            'Failed to delete temp drag directory ${tempDir.path}',
            tag: 'Explorer',
            error: error,
            stackTrace: stackTrace,
          );
        }
        if (_lastDragTempDir == tempDir.path) {
          _lastDragTempDir = null;
          _lastDragSourcePath = null;
          _lastDragExpiresAt = null;
        }
      });
    }
  }
}
