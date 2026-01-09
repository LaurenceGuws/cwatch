import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:cwatch/models/app_settings.dart';
import 'package:cwatch/models/ssh_client_backend.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/app_settings_controller.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';

import '../adapters/settings_ui_adapter.dart';
import '../repositories/settings_repository.dart';

class LoadedKeyFile {
  const LoadedKeyFile({required this.contents, required this.fileName});

  final String contents;
  final String fileName;
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.settingsController,
    required this.keyService,
    required this.hostsFuture,
    required this.uiAdapter,
    SettingsRepository? repository,
  }) : repository = repository ?? SettingsRepository() {
    _settingsListener = notifyListeners;
    settingsController.addListener(_settingsListener);
  }

  final AppSettingsController settingsController;
  final BuiltInSshKeyService keyService;
  final Future<List<SshHost>> hostsFuture;
  final SettingsUiAdapter uiAdapter;
  final SettingsRepository repository;

  late final VoidCallback _settingsListener;

  AppSettings get settings => settingsController.settings;
  bool get isLoaded => settingsController.isLoaded;

  Future<void> update(
    AppSettings Function(AppSettings current) transform,
  ) async {
    await settingsController.update(transform);
  }

  void applyOverrides(AppSettings Function(AppSettings current) transform) {
    settingsController.applyOverrides(transform);
  }

  bool get supportsPlatformSsh {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  Future<void> ensureSupportedSshBackend() async {
    if (supportsPlatformSsh) return;
    if (settings.sshClientBackend == SshClientBackend.builtin) return;
    await update(
      (current) => current.copyWith(sshClientBackend: SshClientBackend.builtin),
    );
  }

  Future<void> setSshClientBackend(SshClientBackend target) async {
    await update((current) => current.copyWith(sshClientBackend: target));
  }

  Future<void> addSshConfigFile() async {
    final picked = await uiAdapter.pickSshConfigFile();
    if (picked == null) return;
    String? path = picked.path;
    if (path == null && picked.bytes != null) {
      path = await repository.persistSshConfig(
        name: picked.name,
        bytes: picked.bytes!,
      );
    }
    if (path == null) {
      uiAdapter.showSnackBar('Unable to read selected file', isError: true);
      return;
    }
    final normalized = p.normalize(path);
    final current = settings.customSshConfigPaths;
    if (current.contains(normalized)) {
      uiAdapter.showSnackBar('Config already added');
      return;
    }
    await update(
      (settings) =>
          settings.copyWith(customSshConfigPaths: [...current, normalized]),
    );
    uiAdapter.showSnackBar('Added SSH config: ${p.basename(normalized)}');
  }

  Future<void> removeSshConfigPath(String path) async {
    final current = settings.customSshConfigPaths;
    final next = [...current]..remove(path);
    await update((settings) => settings.copyWith(customSshConfigPaths: next));
    uiAdapter.showSnackBar('Removed config');
  }

  Future<void> toggleSshConfigPath(
    String path,
    bool enabled,
    Set<String> disabled,
  ) async {
    final next = disabled.toSet();
    if (enabled) {
      next.remove(path);
    } else {
      next.add(path);
    }
    await update(
      (settings) => settings.copyWith(disabledSshConfigPaths: next.toList()),
    );
    uiAdapter.showSnackBar(enabled ? 'Enabled $path' : 'Disabled $path');
  }

  Future<void> addKubeconfigFile() async {
    final path = await uiAdapter.pickKubeconfigFile();
    if (path == null) return;
    final normalized = p.normalize(path);
    final current = settings.kubernetesConfigPaths;
    if (current.contains(normalized)) return;
    await update(
      (settings) =>
          settings.copyWith(kubernetesConfigPaths: [...current, normalized]),
    );
  }

  Future<void> removeKubeconfigPath(String path) async {
    final current = settings.kubernetesConfigPaths;
    final next = [...current]..remove(path);
    await update((settings) => settings.copyWith(kubernetesConfigPaths: next));
  }

  Listenable get keyVaultListenable => keyService.vault;

  bool isKeyUnlocked(String keyId) => keyService.isUnlocked(keyId);

  Future<List<BuiltInSshKeyEntry>> listBuiltInKeys() => keyService.listKeys();

  void unlockPlaintextKeysIfNeeded(List<BuiltInSshKeyEntry> keys) {
    for (final entry in keys) {
      if (!entry.isEncrypted && !keyService.isUnlocked(entry.id)) {
        keyService
            .unlock(entry.id, password: null)
            .catchError(
              (_) => const BuiltInSshKeyUnlockResult(
                status: BuiltInSshKeyUnlockStatus.failed,
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
      uiAdapter.showSnackBar('Provide label and key.', isError: true);
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
        final passphrase = await uiAdapter.promptForKeyPassphrase(
          isRequired: true,
        );
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
          uiAdapter.showSnackBar(
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
        uiAdapter.showSnackBar(
          message,
          isError: true,
          duration: const Duration(seconds: 5),
        );
        return false;
      }

      uiAdapter.showSnackBar('Key added to the vault.');
      return true;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to add built-in SSH key',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to add key: $error', isError: true);
      return false;
    }
  }

  Future<void> unlockBuiltInKey(String keyId) async {
    final entry = await keyService.loadKey(keyId);
    String? password;
    if (entry != null && entry.isEncrypted) {
      password = await uiAdapter.promptForPassword(title: 'Unlock key');
      if (password == null) {
        return;
      }
    }
    AppLogger().debug('Unlocking built-in key $keyId', tag: 'Settings');
    final result = await keyService.unlock(keyId, password: password);
    switch (result.status) {
      case BuiltInSshKeyUnlockStatus.unlocked:
        uiAdapter.showSnackBar('Key unlocked for this session.');
        break;
      case BuiltInSshKeyUnlockStatus.incorrectPassword:
        uiAdapter.showSnackBar(
          result.message ?? 'Incorrect password.',
          isError: true,
        );
        break;
      default:
        uiAdapter.showSnackBar(
          result.message ?? 'Failed to unlock key.',
          isError: true,
        );
        break;
    }
  }

  Future<bool> removeBuiltInKey(String keyId) async {
    final hosts = await hostsFuture;
    final bindings = settings.builtinSshHostKeyBindings;
    final hostsUsingKey = hosts
        .where((host) => bindings[host.name] == keyId)
        .map((host) => host.name)
        .toList();

    if (hostsUsingKey.isNotEmpty) {
      final confirmed = await uiAdapter.confirmDeleteKeyInUse(
        hostNames: hostsUsingKey,
      );
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
      await update(
        (current) =>
            current.copyWith(builtinSshHostKeyBindings: updatedBindings),
      );
    }

    AppLogger().debug('Removing built-in key $keyId', tag: 'Settings');
    await keyService.deleteKey(keyId);
    uiAdapter.showSnackBar('Key removed from vault.');
    return true;
  }

  void clearUnlockedKeys() {
    keyService.lockAll();
    AppLogger().debug(
      'Cleared unlocked built-in keys from memory',
      tag: 'Settings',
    );
    uiAdapter.showSnackBar('Unlocked keys cleared from memory.');
  }

  void updateHostBinding(String hostName, String? keyId) {
    final current = settings.builtinSshHostKeyBindings;
    final updated = Map<String, String>.from(current);
    if (keyId == null) {
      updated.remove(hostName);
    } else {
      updated[hostName] = keyId;
    }
    AppLogger().debug(
      'Host $hostName now uses ${keyId ?? 'platform default'} for SSH.',
      tag: 'Settings',
    );
    update((current) => current.copyWith(builtinSshHostKeyBindings: updated));
  }

  void lockBuiltInKey(String keyId) {
    keyService.lock(keyId);
    uiAdapter.showSnackBar('Key locked.');
  }

  Future<bool> encryptBuiltInKey(String keyId) async {
    final password = await uiAdapter.promptForPassword(
      title: 'Encrypt key',
      confirmLabel: 'Encrypt',
    );
    if (password == null) {
      return false;
    }

    final entry = await keyService.loadKey(keyId);
    if (entry == null || entry.isEncrypted) {
      uiAdapter.showSnackBar(
        'Key not found or already encrypted.',
        isError: true,
      );
      return false;
    }

    try {
      await keyService.encryptStoredKey(keyId: keyId, password: password);
      uiAdapter.showSnackBar('Key encrypted successfully.');
      return true;
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to encrypt stored SSH key $keyId',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to encrypt key: $error', isError: true);
      return false;
    }
  }

  Future<LoadedKeyFile?> loadPrivateKeyContents() async {
    final file = await uiAdapter.pickPrivateKeyFile();
    if (file == null) return null;
    try {
      final bytes =
          file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        uiAdapter.showSnackBar('Unable to read selected file', isError: true);
        return null;
      }
      uiAdapter.showSnackBar('Loaded key from ${file.name}');
      return LoadedKeyFile(
        contents: String.fromCharCodes(bytes),
        fileName: file.name,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to load SSH key file ${file.name}',
        tag: 'Settings',
        error: error,
        stackTrace: stackTrace,
      );
      uiAdapter.showSnackBar('Failed to read key: $error', isError: true);
      return null;
    }
  }

  @override
  void dispose() {
    settingsController.removeListener(_settingsListener);
    super.dispose();
  }
}
