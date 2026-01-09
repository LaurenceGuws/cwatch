import 'package:flutter/material.dart';

class SshKeyDialogUiAdapter {
  SshKeyDialogUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
