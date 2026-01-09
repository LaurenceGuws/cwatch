import 'package:flutter/material.dart';

import 'package:cwatch/view/shared/widgets/dialog_keyboard_shortcuts.dart';

class WslUiAdapter {
  WslUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  Future<String?> showRenameDialog({required String initialName}) async {
    if (!context.mounted) return null;
    final controller = TextEditingController(text: initialName);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: AlertDialog(
            title: const Text('Rename tab'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tab name'),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }
}
