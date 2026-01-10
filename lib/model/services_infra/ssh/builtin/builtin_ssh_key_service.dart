import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'builtin_ssh_key_entry.dart';
import 'builtin_ssh_key_store.dart';
import 'builtin_ssh_vault.dart';
import 'builtin_remote_shell_service.dart';
import '../../logging/app_logger.dart';
import '../known_hosts_store.dart';
import '../ssh_auth_coordinator.dart';

/// High-level built-in SSH key manager. Keeps validation and vault status
/// handling inside the built-in service so UI layers don't need to know
/// about dartssh2 parsing or storage details.
class BuiltInSshKeyService {
  BuiltInSshKeyService({BuiltInSshKeyStore? keyStore, BuiltInSshVault? vault})
    : _keyStore = keyStore ?? BuiltInSshKeyStore(),
      _vault =
          vault ?? BuiltInSshVault(keyStore: keyStore ?? BuiltInSshKeyStore());

  final BuiltInSshKeyStore _keyStore;
  final BuiltInSshVault _vault;

  BuiltInSshVault get vault => _vault;

  Future<List<BuiltInSshKeyEntry>> listKeys() => _keyStore.listEntries();

  Future<BuiltInSshKeyEntry?> loadKey(String id) => _keyStore.loadEntry(id);

  /// Adds a key after validating whether a passphrase is required/valid.
  /// If [keyPassphrase] is needed but not provided, status will be
  /// [BuiltInSshKeyAddStatus.needsPassphrase].
  Future<BuiltInSshKeyAddResult> addKey({
    required String label,
    required String keyPem,
    String? storagePassword,
    String? keyPassphrase,
  }) async {
    final validation = _validatePem(keyPem, passphrase: keyPassphrase);
    switch (validation.status) {
      case _KeyValidationStatus.needsPassphrase:
        return BuiltInSshKeyAddResult(
          status: BuiltInSshKeyAddStatus.needsPassphrase,
          message: validation.message,
        );
      case _KeyValidationStatus.invalid:
        return BuiltInSshKeyAddResult(
          status: BuiltInSshKeyAddStatus.invalid,
          message: validation.message,
        );
      case _KeyValidationStatus.valid:
        break;
    }

    final effectivePassword =
        storagePassword != null && storagePassword.isNotEmpty
        ? storagePassword
        : null;

    try {
      final entry = await _keyStore.addEntry(
        label: label,
        keyData: utf8.encode(keyPem),
        password: effectivePassword,
      );

      return BuiltInSshKeyAddResult(
        status: BuiltInSshKeyAddStatus.success,
        entry: entry,
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to add built-in SSH key "$label"',
        tag: 'BuiltInSSHKey',
        error: error,
        stackTrace: stackTrace,
      );
      return BuiltInSshKeyAddResult(
        status: BuiltInSshKeyAddStatus.invalid,
        message: error.toString(),
      );
    }
  }

  /// Removes a key from storage and clears it from the vault.
  Future<void> deleteKey(String id) async {
    await _keyStore.deleteEntry(id);
    _vault.clearDecrypted(id);
  }

  /// Decrypts a key for this session.
  Future<BuiltInSshKeyDecryptResult> decrypt(
    String keyId, {
    String? password,
  }) async {
    final entry = await _keyStore.loadEntry(keyId);
    if (entry == null) {
      return const BuiltInSshKeyDecryptResult(
        status: BuiltInSshKeyDecryptStatus.missing,
        message: 'Key not found',
      );
    }
    if (entry.isEncrypted && (password == null || password.isEmpty)) {
      return const BuiltInSshKeyDecryptResult(
        status: BuiltInSshKeyDecryptStatus.passwordRequired,
      );
    }
    try {
      await _vault.decrypt(keyId, password);
      return const BuiltInSshKeyDecryptResult(
        status: BuiltInSshKeyDecryptStatus.decrypted,
      );
    } on BuiltInSshKeyDecryptException {
      return const BuiltInSshKeyDecryptResult(
        status: BuiltInSshKeyDecryptStatus.incorrectPassword,
        message: 'Incorrect password for that key.',
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to decrypt built-in SSH key $keyId',
        tag: 'BuiltInSSHKey',
        error: error,
        stackTrace: stackTrace,
      );
      return BuiltInSshKeyDecryptResult(
        status: BuiltInSshKeyDecryptStatus.failed,
        message: error.toString(),
      );
    }
  }

  bool isDecrypted(String keyId) => _vault.isDecrypted(keyId);

  void clearDecrypted(String keyId) => _vault.clearDecrypted(keyId);

  void clearAllDecrypted() => _vault.clearAllDecrypted();

  /// Builds a ready-to-use [BuiltInRemoteShellService] wired to this key vault.
  BuiltInRemoteShellService buildShellService({
    required Map<String, String> hostKeyBindings,
    bool debugMode = false,
    RemoteCommandObserver? observer,
    Future<bool> Function(String keyId, String hostName, String? keyLabel)?
    promptDecrypt,
    KnownHostsStore? knownHostsStore,
    SshAuthCoordinator? authCoordinator,
    Duration? connectTimeout,
  }) {
    return BuiltInRemoteShellService(
      vault: _vault,
      hostKeyBindings: hostKeyBindings,
      debugMode: debugMode,
      observer: observer,
      promptDecrypt: promptDecrypt,
      knownHostsStore: knownHostsStore,
      authCoordinator: authCoordinator,
      connectTimeout: connectTimeout ?? const Duration(seconds: 10),
    );
  }

  /// Encrypts a plaintext-stored key using the provided password.
  Future<BuiltInSshKeyEntry> encryptStoredKey({
    required String keyId,
    required String password,
  }) async {
    final entry = await _keyStore.loadEntry(keyId);
    if (entry == null) {
      throw StateError('Key not found');
    }
    if (entry.isEncrypted) {
      return entry;
    }
    final keyData = utf8.encode(entry.plaintext!);
    final newEntry = await _keyStore.buildEntry(
      id: keyId,
      label: entry.label,
      keyData: keyData,
      keyIsEncrypted: entry.keyHasPassphrase,
      password: password,
    );
    await _keyStore.writeEntry(newEntry);
    await _vault.decrypt(keyId, password);
    return newEntry;
  }

  _KeyValidationResult _validatePem(String pem, {String? passphrase}) {
    final trimmedPassphrase = passphrase != null && passphrase.isNotEmpty
        ? passphrase
        : null;
    try {
      SSHKeyPair.fromPem(pem, trimmedPassphrase);
      return const _KeyValidationResult.valid();
    } on ArgumentError catch (error) {
      AppLogger().warn(
        'Error validating SSH key PEM',
        tag: 'BuiltInSSHKey',
        error: error,
      );
      if (error.message == 'passphrase is required for encrypted key') {
        if (trimmedPassphrase == null) {
          return const _KeyValidationResult.needsPassphrase(
            'Passphrase required to import this key.',
          );
        }
        return const _KeyValidationResult.invalid(
          'Provided passphrase was rejected.',
        );
      }
      return _KeyValidationResult.invalid(error.toString());
    } on StateError catch (error) {
      AppLogger().warn(
        'Error validating SSH key PEM',
        tag: 'BuiltInSSHKey',
        error: error,
      );
      if (error.message.contains('encrypted')) {
        if (trimmedPassphrase == null) {
          return const _KeyValidationResult.needsPassphrase(
            'Passphrase required to import this key.',
          );
        }
        return const _KeyValidationResult.invalid(
          'Provided passphrase was rejected.',
        );
      }
      return _KeyValidationResult.invalid(error.toString());
    } on SSHKeyDecryptError {
      return const _KeyValidationResult.invalid('Invalid passphrase.');
    } on UnsupportedError catch (error) {
      AppLogger().warn(
        'Unsupported SSH key format',
        tag: 'BuiltInSSHKey',
        error: error,
      );
      return _KeyValidationResult.invalid(
        'Unsupported key cipher or format: ${error.message}',
      );
    } catch (error, stackTrace) {
      AppLogger().warn(
        'Failed to validate SSH key PEM',
        tag: 'BuiltInSSHKey',
        error: error,
        stackTrace: stackTrace,
      );
      return _KeyValidationResult.invalid(error.toString());
    }
  }
}

enum BuiltInSshKeyAddStatus { success, needsPassphrase, invalid }

class BuiltInSshKeyAddResult {
  const BuiltInSshKeyAddResult({
    required this.status,
    this.entry,
    this.message,
  });

  final BuiltInSshKeyAddStatus status;
  final BuiltInSshKeyEntry? entry;
  final String? message;

  bool get isSuccess => status == BuiltInSshKeyAddStatus.success;
}

enum BuiltInSshKeyDecryptStatus {
  decrypted,
  passwordRequired,
  incorrectPassword,
  missing,
  failed,
}

class BuiltInSshKeyDecryptResult {
  const BuiltInSshKeyDecryptResult({required this.status, this.message});

  final BuiltInSshKeyDecryptStatus status;
  final String? message;

  bool get isDecrypted => status == BuiltInSshKeyDecryptStatus.decrypted;
}

class _KeyValidationResult {
  const _KeyValidationResult._(this.status, this.message);

  const _KeyValidationResult.valid() : this._(_KeyValidationStatus.valid, null);

  const _KeyValidationResult.needsPassphrase([String? message])
    : this._(_KeyValidationStatus.needsPassphrase, message);

  const _KeyValidationResult.invalid([String? message])
    : this._(_KeyValidationStatus.invalid, message);

  final _KeyValidationStatus status;
  final String? message;
}

enum _KeyValidationStatus { valid, needsPassphrase, invalid }
