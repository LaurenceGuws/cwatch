import 'package:flutter/material.dart';

import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor/file_info_dialog.dart'
    as file_info;

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

  void showFileInfoDialog({
    required String path,
    required String content,
    required String language,
    required String? parserName,
    required String? helperText,
  }) {
    if (!context.mounted) return;
    file_info.showFileInfoDialog(
      context: context,
      path: path,
      content: content,
      language: language,
      parserName: parserName,
      helperText: helperText,
    );
  }
}
