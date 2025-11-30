import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../models/remote_file_entry.dart';

/// Builder for file explorer context menus
class ContextMenuBuilder {
  ContextMenuBuilder({
    required this.hostName,
    required this.currentPath,
    required this.selectedEntries,
    required this.clipboardAvailable,
    required this.onOpen,
    required this.onCopyPath,
    required this.onOpenLocally,
    required this.onEditFile,
    required this.onRename,
    required this.onCopy,
    required this.onCut,
    required this.onPaste,
    required this.onPasteInto,
    required this.onMove,
    required this.onDelete,
    required this.onDownload,
    required this.onUploadFiles,
    required this.onUploadFolder,
    this.onOpenTerminal,
    required this.joinPath,
  });

  final String hostName;
  final String currentPath;
  final List<RemoteFileEntry> selectedEntries;
  final bool clipboardAvailable;
  final ValueChanged<RemoteFileEntry>? onOpen;
  final ValueChanged<RemoteFileEntry>? onCopyPath;
  final ValueChanged<RemoteFileEntry>? onOpenLocally;
  final ValueChanged<RemoteFileEntry>? onEditFile;
  final ValueChanged<RemoteFileEntry>? onRename;
  final ValueChanged<List<RemoteFileEntry>>? onCopy;
  final ValueChanged<List<RemoteFileEntry>>? onCut;
  final VoidCallback? onPaste;
  final ValueChanged<RemoteFileEntry>? onPasteInto;
  final ValueChanged<RemoteFileEntry>? onMove;
  final ValueChanged<List<RemoteFileEntry>>? onDelete;
  final ValueChanged<List<RemoteFileEntry>>? onDownload;
  final ValueChanged<String>? onUploadFiles;
  final ValueChanged<String>? onUploadFolder;
  final ValueChanged<String>? onOpenTerminal;
  final String Function(String, String) joinPath;

  static const _shortcutCopy = 'Ctrl+C';
  static const _shortcutCut = 'Ctrl+X';
  static const _shortcutPaste = 'Ctrl+V';
  static const _shortcutRename = 'F2';
  static const _shortcutDelete = 'Delete';

  /// Build context menu items for entry context menu
  List<PopupMenuEntry<ExplorerContextAction>> buildEntryMenuItems(
    RemoteFileEntry entry,
  ) {
    final menuItems = <PopupMenuEntry<ExplorerContextAction>>[];
    final isMultiSelect = selectedEntries.length > 1;

    // If nothing is selected, show general menu (paste/upload for current directory)
    if (selectedEntries.isEmpty) {
      if (clipboardAvailable) {
        menuItems.add(
          PopupMenuItem(
            value: ExplorerContextAction.paste,
            enabled: clipboardAvailable,
            child: Text('Paste ($_shortcutPaste)'),
          ),
        );
      }

      menuItems.add(
        const PopupMenuItem(
          value: ExplorerContextAction.openTerminal,
          child: Text('Open terminal here'),
        ),
      );

      menuItems.addAll(const [
        PopupMenuItem(
          value: ExplorerContextAction.uploadFiles,
          child: Text('Upload files here...'),
        ),
        PopupMenuItem(
          value: ExplorerContextAction.uploadFolder,
          child: Text('Upload folder here...'),
        ),
      ]);

      return menuItems;
    }

    // Single selection actions
    if (!isMultiSelect) {
      if (entry.isDirectory) {
        menuItems.add(
          const PopupMenuItem(
            value: ExplorerContextAction.open,
            child: Text('Open'),
          ),
        );
        menuItems.add(
          const PopupMenuItem(
            value: ExplorerContextAction.openTerminal,
            child: Text('Open terminal here'),
          ),
        );
      } else {
        menuItems.addAll([
          const PopupMenuItem(
            value: ExplorerContextAction.openLocally,
            child: Text('Open locally'),
          ),
          const PopupMenuItem(
            value: ExplorerContextAction.editFile,
            child: Text('Edit (text)'),
          ),
        ]);
      }
      menuItems.add(
        const PopupMenuItem(
          value: ExplorerContextAction.copyPath,
          child: Text('Copy path'),
        ),
      );
      menuItems.add(
        PopupMenuItem(
          value: ExplorerContextAction.rename,
          child: Text('Rename ($_shortcutRename)'),
        ),
      );
      menuItems.add(
        const PopupMenuItem(
          value: ExplorerContextAction.move,
          child: Text('Move to...'),
        ),
      );
    }

    // Multi-select compatible actions
    menuItems.addAll([
        PopupMenuItem(
          value: ExplorerContextAction.copy,
        child: Text(
          isMultiSelect
              ? 'Copy (${selectedEntries.length} items) ($_shortcutCopy)'
              : 'Copy ($_shortcutCopy)',
        ),
      ),
        PopupMenuItem(
          value: ExplorerContextAction.cut,
        child: Text(
          isMultiSelect
              ? 'Cut (${selectedEntries.length} items) ($_shortcutCut)'
              : 'Cut ($_shortcutCut)',
        ),
      ),
      PopupMenuItem(
        value: ExplorerContextAction.paste,
        enabled: clipboardAvailable,
        child: Text('Paste ($_shortcutPaste)'),
      ),
    ]);

    // Paste into (only for single directory selection)
    if (!isMultiSelect && entry.isDirectory) {
      menuItems.add(
        PopupMenuItem(
          value: ExplorerContextAction.pasteInto,
          enabled: clipboardAvailable,
          child: Text('Paste into "${entry.name}" ($_shortcutPaste)'),
        ),
      );
    }

    // Download action
    menuItems.add(
        PopupMenuItem(
          value: ExplorerContextAction.download,
        child: Text(
          isMultiSelect
              ? 'Download (${selectedEntries.length} items)'
              : 'Download',
        ),
      ),
    );

    // Upload action (only show on background or directory)
    if (!isMultiSelect && entry.isDirectory) {
      menuItems.addAll(const [
        PopupMenuItem(
          value: ExplorerContextAction.uploadFiles,
          child: Text('Upload files here...'),
        ),
        PopupMenuItem(
          value: ExplorerContextAction.uploadFolder,
          child: Text('Upload folder here...'),
        ),
      ]);
    }

    // Delete action
    menuItems.add(
        PopupMenuItem(
          value: ExplorerContextAction.delete,
        child: Text(
          isMultiSelect
              ? 'Delete (${selectedEntries.length} items) ($_shortcutDelete)'
              : 'Delete ($_shortcutDelete)',
        ),
      ),
    );

    return menuItems;
  }

  /// Build context menu items for background context menu
  Future<void> handleAction(
    BuildContext context,
    ExplorerContextAction? action,
    RemoteFileEntry? entry,
  ) async {
    if (action == null) {
      return;
    }

    final isMultiSelect = selectedEntries.length > 1;

    switch (action) {
      case ExplorerContextAction.open:
        if (!isMultiSelect && entry != null) {
          onOpen?.call(entry);
        }
        break;
      case ExplorerContextAction.openTerminal:
        final targetPath = (!isMultiSelect && entry != null && entry.isDirectory)
            ? joinPath(currentPath, entry.name)
            : currentPath;
        onOpenTerminal?.call(targetPath);
        break;
      case ExplorerContextAction.copyPath:
        if (!isMultiSelect && entry != null) {
          onCopyPath?.call(entry);
        } else if (isMultiSelect) {
          final paths = selectedEntries
              .map((e) => joinPath(currentPath, e.name))
              .join('\n');
          await Clipboard.setData(ClipboardData(text: paths));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied ${selectedEntries.length} paths'),
              ),
            );
          }
        }
        break;
      case ExplorerContextAction.openLocally:
        if (!isMultiSelect && entry != null) {
          onOpenLocally?.call(entry);
        }
        break;
      case ExplorerContextAction.editFile:
        if (!isMultiSelect && entry != null) {
          onEditFile?.call(entry);
        }
        break;
      case ExplorerContextAction.rename:
        if (!isMultiSelect && entry != null) {
          onRename?.call(entry);
        }
        break;
      case ExplorerContextAction.copy:
        if (isMultiSelect) {
          onCopy?.call(selectedEntries);
        } else if (entry != null) {
          onCopy?.call([entry]);
        }
        break;
      case ExplorerContextAction.cut:
        if (isMultiSelect) {
          onCut?.call(selectedEntries);
        } else if (entry != null) {
          onCut?.call([entry]);
        }
        break;
      case ExplorerContextAction.paste:
        onPaste?.call();
        break;
      case ExplorerContextAction.pasteInto:
        if (!isMultiSelect && entry != null) {
          onPasteInto?.call(entry);
        }
        break;
      case ExplorerContextAction.move:
        if (!isMultiSelect && entry != null) {
          onMove?.call(entry);
        }
        break;
      case ExplorerContextAction.delete:
        onDelete?.call(selectedEntries);
        break;
      case ExplorerContextAction.download:
        onDownload?.call(selectedEntries);
        break;
      case ExplorerContextAction.uploadFiles:
        if (!isMultiSelect && entry != null && entry.isDirectory) {
          onUploadFiles?.call(joinPath(currentPath, entry.name));
        } else {
          onUploadFiles?.call(currentPath);
        }
        break;
      case ExplorerContextAction.uploadFolder:
        if (!isMultiSelect && entry != null && entry.isDirectory) {
          onUploadFolder?.call(joinPath(currentPath, entry.name));
        } else {
          onUploadFolder?.call(currentPath);
        }
        break;
    }
  }
}

enum ExplorerContextAction {
  open,
  openTerminal,
  copyPath,
  openLocally,
  editFile,
  rename,
  copy,
  cut,
  paste,
  pasteInto,
  delete,
  move,
  download,
  uploadFiles,
  uploadFolder,
}
