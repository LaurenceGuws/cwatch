import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/controller/adapters/settings_key_ui.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';

class LoadedKeyFile {
  const LoadedKeyFile({required this.contents, required this.fileName});

  final String contents;
  final String fileName;
}

class BuiltInSshKeyController {
  BuiltInSshKeyController({
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    required this.ui,
    required this.updateSettings,
  });

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final SettingsKeyUi ui;
  final Future<void> Function(AppSettings Function(AppSettings current) transform)
  updateSettings;

  Listenable get keyVaultListenable => keyService.vault;

  bool isKeyDecrypted(String keyId) => keyService.isDecrypted(keyId);

  Future<List<BuiltInSshKeyEntry>> listBuiltInKeys() => keyService.listKeys();

  void decryptPlaintextKeysIfNeeded(List<BuiltInSshKeyEntry> keys) {
    for (final entry in keys) {
      if (!entry.isEncrypted && !keyService.isDecrypted(entry.id)) {
        keyService
            .decrypt(entry.id, password: null)
            .catchError(
              (_) => const BuiltInSshKeyDecryptResult(
                status: BuiltInSshKeyDecryptStatus.failed,
              ),
            );
      }
    }
  }

  Future<bool> addBuiltInKey({
    required String label,
    required String keyText,
    String? password,
  }) async {
    final trimmedLabel = label.trim();
    final trimmedKey = keyText.trim();
    final trimmedPassword = password?.trim() ?? '';
    if (trimmedLabel.isEmpty || trimmedKey.isEmpty) {
      ui.showSnackBar('Provide label and key.', isError: true);
      return false;
    }

    AppLogger().debug('Adding built-in key "$trimmedLabel"', tag: 'Settings');
    try {
      final addResult = await keyService.addKey(
        label: trimmedLabel,
        keyPem: trimmedKey,
        storagePassword: trimmedPassword.isEmpty ? null : trimmedPassword,
        keyPassphrase: null,
      );
      if (addResult.status == BuiltInSshKeyAddStatus.needsPassphrase) {
        final passphrase = await ui.promptForKeyPassphrase(isRequired: true);
        if (passphrase == null || passphrase.isEmpty) {
          return false;
        }
        final retry = await keyService.addKey(
          label: trimmedLabel,
          keyPem: trimmedKey,
          storagePassword: trimmedPassword.isEmpty ? null : trimmedPassword,
          keyPassphrase: passphrase,
        );
        if (retry.status != BuiltInSshKeyAddStatus.success) {
          final message =
              retry.message ??
              'Unable to import key. Please check the passphrase or format.';
          ui.showSnackBar(
            message,
            isError: true,
            duration: const Duration(seconds: 5),
          );
          return false;
        }
      } else if (addResult.status != BuiltInSshKeyAddStatus.success) {
        final message =
            addResult.message ??
            'Key cannot be parsed. It may be encrypted, unsupported, or malformed.';
        ui.showSnackBar(
          message,
          isError: true,
          duration: const Duration(seconds: 5),
        );
        return false;
      }

      ui.showSnackBar('Key added to the vault.');
      return true;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to add built-in SSH key',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Failed to add key: $error', isError: true);
      return false;
    }
  }

  Future<void> decryptBuiltInKey(String keyId) async {
    final entry = await keyService.loadKey(keyId);
    String? password;
    if (entry != null && entry.isEncrypted) {
      password = await ui.promptForPassword(title: 'Decrypt key');
      if (password == null) {
        return;
      }
    }
    AppLogger().debug('Decrypting built-in key $keyId', tag: 'Settings');
    final result = await keyService.decrypt(keyId, password: password);
    switch (result.status) {
      case BuiltInSshKeyDecryptStatus.decrypted:
        ui.showSnackBar('Key decrypted for this session.');
        break;
      case BuiltInSshKeyDecryptStatus.incorrectPassword:
        ui.showSnackBar(
          result.message ?? 'Incorrect password.',
          isError: true,
        );
        break;
      default:
        ui.showSnackBar(
          result.message ?? 'Failed to decrypt key.',
          isError: true,
        );
        break;
    }
  }

  Future<bool> removeBuiltInKey(String keyId) async {
    final hosts = await hostsFuture;
    final bindings = settingsController.settings.sshPreferences.builtinHostKeyBindings;
    final hostsUsingKey = hosts
        .where((host) => bindings[host.name] == keyId)
        .map((host) => host.name)
        .toList();

    if (hostsUsingKey.isNotEmpty) {
      final confirmed = await ui.confirmDeleteKeyInUse(hostNames: hostsUsingKey);
      if (!confirmed) {
        return false;
      }

      final updatedBindings = Map<String, String>.from(bindings);
      for (final hostName in hostsUsingKey) {
        updatedBindings.remove(hostName);
        AppLogger().debug(
          'Removed key binding for host $hostName',
          tag: 'Settings',
        );
      }
      await updateSettings(
        (current) => current.copyWith(
          sshPreferences: current.sshPreferences.copyWith(
            builtinHostKeyBindings: updatedBindings,
          ),
        ),
      );
    }

    AppLogger().debug('Removing built-in key $keyId', tag: 'Settings');
    await keyService.deleteKey(keyId);
    ui.showSnackBar('Key removed from vault.');
    return true;
  }

  void clearDecryptedKeys() {
    keyService.clearAllDecrypted();
    AppLogger().debug(
      'Cleared decrypted built-in keys from memory',
      tag: 'Settings',
    );
    ui.showSnackBar('Decrypted keys cleared from memory.');
  }

  void clearDecryptedKey(String keyId) {
    keyService.clearDecrypted(keyId);
    ui.showSnackBar('Key cleared from memory.');
  }

  Future<bool> encryptBuiltInKey(String keyId) async {
    final password = await ui.promptForPassword(
      title: 'Encrypt key',
      confirmLabel: 'Encrypt',
    );
    if (password == null) {
      return false;
    }

    final entry = await keyService.loadKey(keyId);
    if (entry == null || entry.isEncrypted) {
      ui.showSnackBar(
        'Key not found or already encrypted.',
        isError: true,
      );
      return false;
    }

    try {
      await keyService.encryptStoredKey(keyId: keyId, password: password);
      ui.showSnackBar('Key encrypted successfully.');
      return true;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to encrypt stored SSH key $keyId',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Failed to encrypt key: $error', isError: true);
      return false;
    }
  }

  Future<LoadedKeyFile?> loadPrivateKeyContents() async {
    final file = await ui.pickPrivateKeyFile();
    if (file == null) return null;
    try {
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        ui.showSnackBar('Unable to read selected file', isError: true);
        return null;
      }
      ui.showSnackBar('Loaded key from ${file.name}');
      return LoadedKeyFile(
        contents: String.fromCharCodes(bytes),
        fileName: p.basename(file.name),
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH key file ${file.name}',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      ui.showSnackBar('Failed to read key: $error', isError: true);
      return null;
    }
  }
}
