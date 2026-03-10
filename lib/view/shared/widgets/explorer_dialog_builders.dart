import 'package:flutter/material.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';

import 'dialog_keyboard_shortcuts.dart';

/// Builders for file explorer dialogs.
class ExplorerDialogBuilders {
  ExplorerDialogBuilders._();

  static Future<String?> showRenameDialog(
    BuildContext context,
    RemoteFileEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.name);
    return showDialog<String>(
      context: context,
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
        child: AlertDialog(
          title: const Text('Rename'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New name'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showMoveDialog(
    BuildContext context,
    RemoteFileEntry entry,
    String currentPath,
  ) async {
    final controller = TextEditingController(
      text: PathUtils.joinPath(currentPath, entry.name),
    );
    return showDialog<String>(
      context: context,
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
        child: AlertDialog(
          title: const Text('Move entry'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Destination path',
              helperText: 'Provide absolute path to new location',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Move'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> showDeleteDialog(
    BuildContext context,
    RemoteFileEntry entry,
    SshHost host,
    bool permanent,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
        child: AlertDialog(
          title: Text(
            permanent
                ? 'Delete ${entry.name} permanently?'
                : 'Move ${entry.name} to trash?',
          ),
          content: Text(
            permanent
                ? 'This will permanently delete ${entry.name} from ${host.name}.'
                : 'A backup will be stored locally so you can restore it later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(permanent ? 'Delete' : 'Move to trash'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showNavigateToSubdirectoryDialog(
    BuildContext context,
    List<RemoteFileEntry> entries,
    ValueChanged<String>? onMessage,
  ) async {
    final directories =
        entries
            .where((entry) => entry.isDirectory)
            .map((entry) => entry.name)
            .toList()
          ..sort();

    if (directories.isEmpty) {
      onMessage?.call('No subdirectories available');
      if (onMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subdirectories available')),
        );
      }
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigate to subdirectory'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: directories.length,
            itemBuilder: (context, index) {
              final dir = directories[index];
              return ListTile(
                leading: Icon(NerdIcon.folder.data),
                title: Text(dir),
                onTap: () => Navigator.of(context).pop(dir),
              );
            },
          ),
        ),
      ),
    );
  }
}
