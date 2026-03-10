import 'package:flutter/material.dart';

import 'dialog_keyboard_shortcuts.dart';

Future<String?> showTextPromptDialog({
  required BuildContext context,
  required String title,
  required String label,
  String? initialValue,
  String? hintText,
  String? helperText,
  String submitLabel = 'OK',
  String cancelLabel = 'Cancel',
  bool obscureText = false,
  List<Widget> contentBeforeField = const [],
  List<PromptDialogAction> extraActions = const [],
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => DialogKeyboardShortcuts(
        onCancel: () => Navigator.of(dialogContext).pop(),
        onConfirm: () =>
            Navigator.of(dialogContext).pop(controller.text.trim()),
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...contentBeforeField,
              if (contentBeforeField.isNotEmpty) const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hintText,
                  helperText: helperText,
                ),
                onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
              ),
            ],
          ),
          actions: [
            ...extraActions.map((action) => action.build(dialogContext)),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(submitLabel),
            ),
          ],
        ),
      ),
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}

Future<bool> showConfirmPromptDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => DialogKeyboardShortcuts(
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      child: AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

class PromptDialogAction {
  const PromptDialogAction({
    required this.label,
    required this.result,
  });

  final String label;
  final String result;

  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(result),
      child: Text(label),
    );
  }
}
