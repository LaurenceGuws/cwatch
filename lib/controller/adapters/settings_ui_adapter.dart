import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/settings_key_ui.dart';
import 'package:cwatch/view/shared/widgets/shared_prompt_dialogs.dart';

class SettingsUiAdapter implements SettingsKeyUi {
  SettingsUiAdapter({required this.context});

  final BuildContext context;

  bool get mounted => context.mounted;

  @override
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

  @override
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

  @override
  Future<String?> promptForPassword({
    required String title,
    String labelText = 'Password',
    String? helperText,
    String confirmLabel = 'Unlock',
    String cancelLabel = 'Cancel',
  }) async {
    if (!context.mounted) return null;
    return showTextPromptDialog(
      context: context,
      title: title,
      label: labelText,
      helperText: helperText,
      submitLabel: confirmLabel,
      cancelLabel: cancelLabel,
      obscureText: true,
    );
  }

  @override
  Future<String?> promptForKeyPassphrase({required bool isRequired}) async {
    if (!context.mounted) return null;
    return showTextPromptDialog(
      context: context,
      title: isRequired ? 'Key passphrase required' : 'Key validation needed',
      label: 'Key passphrase',
      helperText: isRequired
          ? 'This will not be stored, only used for validation.'
          : 'Leave empty if the key is not encrypted. This will not be stored, only used for validation.',
      submitLabel: 'Validate',
      obscureText: true,
      contentBeforeField: [
        Text(
          isRequired
              ? 'This key is encrypted with a passphrase. Please provide the passphrase to validate the key can be decrypted.'
              : 'The key could not be parsed. It may be encrypted with a passphrase, or it may be unsupported. Please try providing a passphrase if the key is encrypted.',
        ),
      ],
      extraActions: isRequired
          ? const []
          : const [
              PromptDialogAction(
                label: 'Try without passphrase',
                result: '',
              ),
            ],
    );
  }

  @override
  Future<bool> confirmDeleteKeyInUse({required List<String> hostNames}) async {
    if (!context.mounted) return false;
    return showConfirmPromptDialog(
      context: context,
      title: 'Key in use',
      message:
          'This key is currently assigned to ${hostNames.length} host${hostNames.length == 1 ? '' : 's'}: ${hostNames.join(', ')}.\n\nDeleting this key will remove it from these hosts. Continue?',
      confirmLabel: 'Delete',
      destructive: true,
    );
  }
}
