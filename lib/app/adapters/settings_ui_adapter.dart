import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';

class SettingsPickedFile {
  const SettingsPickedFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;
}

class SettingsUiAdapter {
  SettingsUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  void showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  }) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  Future<SettingsPickedFile?> pickSshConfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select ssh_config file',
      allowMultiple: false,
      withData: true,
    );
    final file = (result != null && result.files.isNotEmpty)
        ? result.files.first
        : null;
    if (file == null) return null;
    return SettingsPickedFile(
      name: file.name,
      path: file.path,
      bytes: file.bytes,
    );
  }

  Future<SettingsPickedFile?> pickPrivateKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select private key (PEM)',
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.first;
    if (file == null) return null;
    return SettingsPickedFile(
      name: file.name,
      path: file.path,
      bytes: file.bytes,
    );
  }

  Future<String?> pickKubeconfigFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select kubeconfig file',
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  Future<String?> promptForPassword({
    required String title,
    String labelText = 'Password',
    String? helperText,
    String confirmLabel = 'Unlock',
    String cancelLabel = 'Cancel',
  }) async {
    if (!context.mounted) return null;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(null),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: labelText,
                helperText: helperText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text(cancelLabel),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: Text(confirmLabel),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> promptForKeyPassphrase({required bool isRequired}) async {
    if (!context.mounted) return null;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        final spacing = context.appTheme.spacing;
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(null),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
            title: Text(
              isRequired ? 'Key passphrase required' : 'Key validation needed',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRequired
                      ? 'This key is encrypted with a passphrase. '
                            'Please provide the passphrase to validate the key can be decrypted.'
                      : 'The key could not be parsed. It may be encrypted with a passphrase, '
                            'or it may be unsupported. Please try providing a passphrase if the key is encrypted.',
                ),
                SizedBox(height: spacing.xl),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Key passphrase',
                    helperText: isRequired
                        ? 'This will not be stored, only used for validation.'
                        : 'Leave empty if the key is not encrypted. '
                              'This will not be stored, only used for validation.',
                  ),
                ),
              ],
            ),
            actions: [
              if (!isRequired)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('Try without passphrase'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Validate'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> confirmDeleteKeyInUse({required List<String> hostNames}) async {
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
          child: AlertDialog(
            title: const Text('Key in use'),
            content: Text(
              'This key is currently assigned to ${hostNames.length} '
              'host${hostNames.length == 1 ? '' : 's'}: '
              '${hostNames.join(', ')}.\n\n'
              'Deleting this key will remove it from these hosts. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }
}
