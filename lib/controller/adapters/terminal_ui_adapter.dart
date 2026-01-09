import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TerminalUiAdapter {
  TerminalUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  Future<void> copyToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  Future<String?> readClipboardText() async {
    final data = await Clipboard.getData('text/plain');
    return data?.text;
  }

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}
