import 'dart:typed_data';

class SettingsPickedFile {
  const SettingsPickedFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final Uint8List? bytes;
}

abstract class SettingsKeyUi {
  void showSnackBar(
    String message, {
    bool isError = false,
    Duration? duration,
  });

  Future<String?> promptForPassword({
    required String title,
    String labelText = 'Password',
    String? helperText,
    String confirmLabel = 'Unlock',
    String cancelLabel = 'Cancel',
  });

  Future<String?> promptForKeyPassphrase({required bool isRequired});

  Future<bool> confirmDeleteKeyInUse({required List<String> hostNames});

  Future<SettingsPickedFile?> pickPrivateKeyFile();
}
