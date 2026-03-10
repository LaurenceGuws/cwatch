import 'package:flutter/material.dart';

import 'package:cwatch/view/shared/widgets/shared_prompt_dialogs.dart';

class WslUiAdapter {
  WslUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  Future<String?> showRenameDialog({required String initialName}) async {
    if (!context.mounted) return null;
    return showTextPromptDialog(
      context: context,
      title: 'Rename tab',
      label: 'Tab name',
      initialValue: initialName,
      submitLabel: 'Save',
    );
  }
}
