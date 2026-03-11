import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KubernetesUiAdapter {
  KubernetesUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> copyToClipboard(
    String text, {
    String message = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showSnackBar(message);
    }
  }
}
