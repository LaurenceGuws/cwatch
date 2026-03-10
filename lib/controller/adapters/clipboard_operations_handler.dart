import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'explorer_ui_adapter.dart';

/// Handler for clipboard operations (copy, cut).
class ClipboardOperationsHandler {
  ClipboardOperationsHandler({
    required this.host,
    required this.currentPath,
    required this.explorerContext,
    required this.shellService,
    required this.uiAdapter,
  });

  final SshHost host;
  String currentPath;
  final ExplorerContext explorerContext;
  final RemoteShellService shellService;
  final ExplorerUiAdapter uiAdapter;

  /// Set clipboard entry for a single file/folder.
  void setClipboardEntry(
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
    uiAdapter.showSnackBar(
      operation == ExplorerClipboardOperation.copy
          ? 'Copied ${entry.name}'
          : 'Cut ${entry.name}',
    );
  }

  /// Set clipboard entries for multiple files/folders.
  void setClipboardEntries(
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
    uiAdapter.showSnackBar(
      operation == ExplorerClipboardOperation.copy
          ? entries.length == 1
                ? 'Copied ${entries.first.name}'
                : 'Copied ${entries.length} items'
          : entries.length == 1
          ? 'Cut ${entries.first.name}'
          : 'Cut ${entries.length} items',
    );
  }
}
