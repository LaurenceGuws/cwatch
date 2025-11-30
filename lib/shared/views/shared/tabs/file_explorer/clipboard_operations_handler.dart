import 'package:flutter/material.dart';

import '../../../../../models/explorer_context.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import 'explorer_clipboard.dart';
import 'path_utils.dart';

/// Handler for clipboard operations (copy, cut)
class ClipboardOperationsHandler {
  ClipboardOperationsHandler({
    required this.host,
    required this.currentPath,
    required this.explorerContext,
    required this.shellService,
  });

  final SshHost host;
  String currentPath;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;

  /// Set clipboard entry for a single file/folder
  void setClipboardEntry(
    BuildContext buildContext,
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    final remotePath = PathUtils.joinPath(currentPath, entry.name);
    ExplorerClipboard.setEntry(
      ExplorerClipboardEntry(
        context: explorerContext,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: operation,
        shellService: shellService,
      ),
    );
    ScaffoldMessenger.of(buildContext).showSnackBar(
      SnackBar(
        content: Text(
          operation == ExplorerClipboardOperation.copy
              ? 'Copied ${entry.name}'
              : 'Cut ${entry.name}',
        ),
      ),
    );
  }

  /// Set clipboard entries for multiple files/folders
  void setClipboardEntries(
    BuildContext buildContext,
    List<RemoteFileEntry> entries,
    ExplorerClipboardOperation operation,
  ) {
    if (entries.isEmpty) {
      return;
    }
    final clipboardEntries = entries.map((entry) {
      final remotePath = PathUtils.joinPath(currentPath, entry.name);
      return ExplorerClipboardEntry(
        context: explorerContext,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: operation,
        shellService: shellService,
      );
    }).toList();

    ExplorerClipboard.setEntries(clipboardEntries);
    if (!buildContext.mounted) return;
    ScaffoldMessenger.of(buildContext).showSnackBar(
      SnackBar(
        content: Text(
          operation == ExplorerClipboardOperation.copy
              ? entries.length == 1
                    ? 'Copied ${entries.first.name}'
                    : 'Copied ${entries.length} items'
              : entries.length == 1
              ? 'Cut ${entries.first.name}'
              : 'Cut ${entries.length} items',
        ),
      ),
    );
  }
}
