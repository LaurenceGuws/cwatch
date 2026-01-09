import 'package:flutter/material.dart';

import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor/file_info_dialog_content.dart';

class RemoteFileEditorUiAdapter {
  RemoteFileEditorUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> showFileInfoDialog({
    required String path,
    required String content,
    required String language,
    required String? parserName,
    required String? helperText,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('File Information'),
        content: RemoteFileInfoDialogContent(
          path: path,
          content: content,
          language: language,
          parserName: parserName,
          helperText: helperText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
