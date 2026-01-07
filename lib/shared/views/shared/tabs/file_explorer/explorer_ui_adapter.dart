import 'package:flutter/material.dart';

import '../../../../../models/remote_file_entry.dart';
import '../../../../../models/ssh_host.dart';
import '../../../../../shared/widgets/dialog_keyboard_shortcuts.dart';
import 'dialog_builders.dart';
import 'merge_conflict_dialog.dart';

class ExplorerUiAdapter {
  ExplorerUiAdapter({required this.context});

  final BuildContext context;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void showDragNotSupported() {
    showSnackBar('Drag-out not supported on this OS');
  }

  void showNothingToDrag() {
    showSnackBar('Nothing to drag');
  }

  void showDragStarted() {
    showSnackBar('Drag started. Drop to copy/move.');
  }

  Future<T?> showContextMenu<T>({
    required Offset position,
    required List<PopupMenuEntry<T>> items,
    BoxConstraints? constraints,
  }) {
    return showMenuAt<T>(
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
      constraints: constraints,
    );
  }

  Future<T?> showMenuAt<T>({
    required RelativeRect position,
    required List<PopupMenuEntry<T>> items,
    BoxConstraints? constraints,
  }) {
    return showMenu<T>(
      context: context,
      position: position,
      constraints: constraints,
      items: items,
    );
  }

  Future<String?> showRenameDialog(RemoteFileEntry entry) {
    return DialogBuilders.showRenameDialog(context, entry);
  }

  Future<String?> showMoveDialog(RemoteFileEntry entry, String currentPath) {
    return DialogBuilders.showMoveDialog(context, entry, currentPath);
  }

  Future<bool?> showDeleteDialog(
    RemoteFileEntry entry,
    SshHost host,
    bool deletePermanently,
  ) {
    return DialogBuilders.showDeleteDialog(
      context,
      entry,
      host,
      deletePermanently,
    );
  }

  Future<String?> showNavigateToSubdirectoryDialog(
    List<RemoteFileEntry> entries,
  ) {
    return DialogBuilders.showNavigateToSubdirectoryDialog(
      context,
      entries,
      showSnackBar,
    );
  }

  Future<String?> showMergeConflictDialog({
    required String remotePath,
    required String local,
    required String remote,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => MergeConflictDialog(
        remotePath: remotePath,
        local: local,
        remote: remote,
      ),
    );
  }

  Future<bool?> showMultiDeleteDialog({
    required int count,
    required String hostName,
    required bool deletePermanently,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
        child: AlertDialog(
          title: Text(
            deletePermanently
                ? 'Delete $count items permanently?'
                : 'Move $count items to trash?',
          ),
          content: Text(
            deletePermanently
                ? 'This will permanently delete $count items from $hostName.'
                : 'Backups will be stored locally so you can restore them later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(deletePermanently ? 'Delete' : 'Move to trash'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> showTextInputDialog({
    required String title,
    required String label,
    String submitLabel = 'Submit',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(null),
        onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
        child: AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(labelText: label),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }
}
