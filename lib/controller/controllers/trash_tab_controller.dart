import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/explorer_context.dart';
import 'package:cwatch/model/services_infra/filesystem/explorer_trash_manager.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_remote_shell_service.dart';
import 'package:cwatch/model/services_infra/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/model/services_infra/ssh/remote_shell_service.dart';
import 'package:cwatch/controller/adapters/explorer_ui_adapter.dart';

class SshDecryptCancelled implements Exception {
  const SshDecryptCancelled();

  @override
  String toString() => 'SshDecryptCancelled';
}

class TrashTabController extends ChangeNotifier {
  TrashTabController({
    required this.manager,
    required this.shellService,
    required this.uiAdapter,
    this.keyService,
    this.context,
  });

  final ExplorerTrashManager manager;
  final RemoteShellService shellService;
  final ExplorerUiAdapter uiAdapter;
  final BuiltInSshKeyService? keyService;
  final ExplorerContext? context;

  bool _decryptInProgress = false;
  final Map<String, Future<String?>> _pendingPassphrasePrompts = {};

  Future<T> runShell<T>(Future<T> Function() action) async {
    if (keyService == null) {
      return action();
    }
    try {
      return await _withBuiltinDecrypt(action);
    } on SshDecryptCancelled {
      rethrow;
    }
  }

  Future<T> _withBuiltinDecrypt<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } on BuiltInSshKeyDecryptionRequired catch (error) {
        AppLogger().warn(
          'Built-in key requires decryption for ${error.hostName}',
          tag: 'Trash',
          error: error,
        );
        final decrypted = await _promptDecrypt(error.keyId);
        if (!decrypted) {
          throw const SshDecryptCancelled();
        }
        continue;
      } on BuiltInSshKeyPassphraseRequired catch (error) {
        AppLogger().warn(
          'Passphrase required for built-in key ${error.keyId}',
          tag: 'Trash',
          error: error,
        );
        final keyLabel = error.keyLabel ?? error.keyId;
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          'built-in key $keyLabel',
        );
        if (passphrase == null) {
          throw const SshDecryptCancelled();
        }
        final service = shellService;
        if (service is BuiltInRemoteShellService) {
          service.setBuiltInKeyPassphrase(error.keyId, passphrase);
        }
        uiAdapter.showSnackBar('Passphrase stored for $keyLabel.');
        continue;
      } on BuiltInSshKeyUnsupportedCipher catch (error) {
        AppLogger().warn(
          'Unsupported cipher for built-in key ${error.keyId}',
          tag: 'Trash',
          error: error,
        );
        final keyLabel = error.keyLabel ?? error.keyId;
        final detail = error.error.message ?? error.error.toString();
        uiAdapter.showSnackBar(
          'Key $keyLabel uses an unsupported cipher ($detail).',
        );
        rethrow;
      } on BuiltInSshIdentityPassphraseRequired catch (error) {
        AppLogger().warn(
          'Passphrase required for identity ${error.identityPath}',
          tag: 'Trash',
          error: error,
        );
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          error.identityPath,
        );
        if (passphrase == null) {
          throw const SshDecryptCancelled();
        }
        final service = shellService;
        if (service is BuiltInRemoteShellService) {
          service.setIdentityPassphrase(error.identityPath, passphrase);
        }
        uiAdapter.showSnackBar('Passphrase stored for ${error.identityPath}.');
        continue;
      } on BuiltInSshAuthenticationFailed catch (error) {
        AppLogger().warn(
          'SSH authentication failed for ${error.hostName}',
          tag: 'Trash',
          error: error,
        );
        uiAdapter.showSnackBar(
          'SSH authentication failed for ${error.hostName}. '
          'Check your key configuration in settings.',
        );
        rethrow;
      }
    }
  }

  Future<bool> _promptDecrypt(String keyId) async {
    if (_decryptInProgress) {
      return false;
    }
    final service = keyService;
    if (service == null) {
      return false;
    }
    _decryptInProgress = true;
    AppLogger().debug('Prompting decryption for key $keyId', tag: 'Trash');
    try {
      final initial = await service.decrypt(keyId, password: null);
      if (initial.status == BuiltInSshKeyDecryptStatus.decrypted) {
        uiAdapter.showSnackBar('Key decrypted for this session.');
        AppLogger().debug('Decryption succeeded for key $keyId', tag: 'Trash');
        return true;
      }
      String? password;
      password = await _showDecryptDialog(keyId);
      if (password == null) {
        AppLogger().debug('Decryption cancelled for key $keyId', tag: 'Trash');
        return false;
      }
      final result = await service.decrypt(keyId, password: password);
      if (result.status == BuiltInSshKeyDecryptStatus.decrypted) {
        uiAdapter.showSnackBar('Key decrypted for this session.');
        AppLogger().debug('Decryption succeeded for key $keyId', tag: 'Trash');
        return true;
      }
      final message = result.message ?? 'Incorrect password for that key.';
      uiAdapter.showSnackBar(message);
      AppLogger().warn(
        'Decryption failed for key $keyId: $message',
        tag: 'Trash',
      );
      return false;
    } catch (error) {
      uiAdapter.showSnackBar('Failed to decrypt key: $error');
      AppLogger().warn(
        'Decryption failed for key $keyId',
        tag: 'Trash',
        error: error,
      );
      return false;
    } finally {
      _decryptInProgress = false;
      AppLogger().debug(
        'Decryption flow completed for key $keyId',
        tag: 'Trash',
      );
    }
  }

  Future<String?> _showDecryptDialog(String keyId) async {
    return uiAdapter.showTextInputDialog(
      title: 'Decrypt key $keyId',
      label: 'Password',
      submitLabel: 'Decrypt',
    );
  }

  Future<String?> _awaitPassphraseInput(String host, String path) {
    final key = '$host|$path';
    final existing = _pendingPassphrasePrompts[key];
    if (existing != null) {
      AppLogger().debug('Awaiting existing passphrase for $key', tag: 'Trash');
      return existing;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        AppLogger().debug('Prompting passphrase for $key', tag: 'Trash');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to prompt passphrase for $key',
          tag: 'Trash',
          error: error,
          stackTrace: stackTrace,
        );
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        AppLogger().debug('Passphrase prompt completed for $key', tag: 'Trash');
      }
    }();
    return completer.future;
  }

  Future<String?> _promptPassphrase(String host, String path) async {
    return uiAdapter.showTextInputDialog(
      title: 'Passphrase for $host ($path)',
      label: 'Passphrase',
      submitLabel: 'Submit',
    );
  }
}
