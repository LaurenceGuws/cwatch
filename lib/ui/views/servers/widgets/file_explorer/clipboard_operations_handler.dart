import 'package:flutter/material.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../explorer_clipboard.dart';
import 'path_utils.dart';

/// Handler for clipboard operations (copy, cut)
class ClipboardOperationsHandler {
  ClipboardOperationsHandler({
    required this.host,
    required this.currentPath,
  });

  final SshHost host;
  String currentPath;

  /// Set clipboard entry for a single file/folder
  void setClipboardEntry(
    BuildContext context,
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    final remotePath = PathUtils.joinPath(currentPath, entry.name);
    ExplorerClipboard.setEntry(
      ExplorerClipboardEntry(
        host: host,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: operation,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
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
    BuildContext context,
    List<RemoteFileEntry> entries,
    ExplorerClipboardOperation operation,
  ) {
    if (entries.isEmpty) {
      return;
    }
    final clipboardEntries = entries.map((entry) {
      final remotePath = PathUtils.joinPath(currentPath, entry.name);
      return ExplorerClipboardEntry(
        host: host,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: operation,
      );
    }).toList();
    
    ExplorerClipboard.setEntries(clipboardEntries);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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

