import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'builtin_ssh_key_entry.dart';
import 'builtin_ssh_key_store.dart';
import 'builtin_ssh_vault.dart';
import 'builtin_remote_shell_service.dart';
import '../../logging/app_logger.dart';
import '../remote_command_logging.dart';
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
    bool allowPlaintext = false,
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
    if (effectivePassword == null && !allowPlaintext) {
      return const BuiltInSshKeyAddResult(
        status: BuiltInSshKeyAddStatus.invalid,
        message:
            'Set a storage password to encrypt this key or explicitly allow plaintext storage.',
      );
    }

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
      AppLogger.w(
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

  /// Removes a key from storage and forgets it from the vault.
  Future<void> deleteKey(String id) async {
    await _keyStore.deleteEntry(id);
    _vault.forget(id);
  }

  /// Unlocks a key for this session.
  Future<BuiltInSshKeyUnlockResult> unlock(
    String keyId, {
    String? password,
  }) async {
    final entry = await _keyStore.loadEntry(keyId);
    if (entry == null) {
      return const BuiltInSshKeyUnlockResult(
        status: BuiltInSshKeyUnlockStatus.missing,
        message: 'Key not found',
      );
    }
    if (entry.isEncrypted && (password == null || password.isEmpty)) {
      return const BuiltInSshKeyUnlockResult(
        status: BuiltInSshKeyUnlockStatus.passwordRequired,
      );
    }
    try {
      await _vault.unlock(keyId, password);
      return const BuiltInSshKeyUnlockResult(
        status: BuiltInSshKeyUnlockStatus.unlocked,
      );
    } on BuiltInSshKeyDecryptException {
      return const BuiltInSshKeyUnlockResult(
        status: BuiltInSshKeyUnlockStatus.incorrectPassword,
        message: 'Incorrect password for that key.',
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to unlock built-in SSH key $keyId',
        tag: 'BuiltInSSHKey',
        error: error,
        stackTrace: stackTrace,
      );
      return BuiltInSshKeyUnlockResult(
        status: BuiltInSshKeyUnlockStatus.failed,
        message: error.toString(),
      );
    }
  }

  bool isUnlocked(String keyId) => _vault.isUnlocked(keyId);

  void lock(String keyId) => _vault.forget(keyId);

  void lockAll() => _vault.forgetAll();

  /// Builds a ready-to-use [BuiltInRemoteShellService] wired to this key vault.
  BuiltInRemoteShellService buildShellService({
    required Map<String, String> hostKeyBindings,
    bool debugMode = false,
    RemoteCommandObserver? observer,
    Future<bool> Function(String keyId, String hostName, String? keyLabel)?
    promptUnlock,
    KnownHostsStore? knownHostsStore,
    SshAuthCoordinator? authCoordinator,
  }) {
    return BuiltInRemoteShellService(
      vault: _vault,
      hostKeyBindings: hostKeyBindings,
      debugMode: debugMode,
      observer: observer,
      promptUnlock: promptUnlock,
      knownHostsStore: knownHostsStore,
      authCoordinator: authCoordinator,
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
    await _vault.unlock(keyId, password);
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
      AppLogger.w(
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
      AppLogger.w(
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
      AppLogger.w(
        'Unsupported SSH key format',
        tag: 'BuiltInSSHKey',
        error: error,
      );
      return _KeyValidationResult.invalid(
        'Unsupported key cipher or format: ${error.message}',
      );
    } catch (error, stackTrace) {
      AppLogger.w(
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

enum BuiltInSshKeyUnlockStatus {
  unlocked,
  passwordRequired,
  incorrectPassword,
  missing,
  failed,
}

class BuiltInSshKeyUnlockResult {
  const BuiltInSshKeyUnlockResult({required this.status, this.message});

  final BuiltInSshKeyUnlockStatus status;
  final String? message;

  bool get isUnlocked => status == BuiltInSshKeyUnlockStatus.unlocked;
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
