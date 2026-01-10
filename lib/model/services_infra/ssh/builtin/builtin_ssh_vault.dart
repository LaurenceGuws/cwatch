import 'dart:convert';
// import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';

import 'builtin_ssh_key_entry.dart';
import 'builtin_ssh_key_store.dart';
import '../../logging/app_logger.dart';

class BuiltInSshVault extends ChangeNotifier {
  BuiltInSshVault({required this.keyStore});

  final BuiltInSshKeyStore keyStore;
  final Map<String, Uint8List> _decrypted = {};
  final Map<String, BuiltInSshKeyEntry> _decryptedEntries = {};

  bool isDecrypted(String keyId) => _decrypted.containsKey(keyId);

  Uint8List? getDecryptedKey(String keyId) => _decrypted[keyId];
  BuiltInSshKeyEntry? getDecryptedEntry(String keyId) =>
      _decryptedEntries[keyId];

  /// Checks if a key requires a password to decrypt (i.e., if storage is encrypted).
  Future<bool> isEncrypted(String keyId) async {
    final entry = await keyStore.loadEntry(keyId);
    return entry?.isEncrypted ?? false;
  }

  /// Fully decrypts a PEM key into unencrypted PEM so dartssh2 will NOT re-prompt.
  /// For unencrypted storage, password can be null.
  /// For keys with passphrases, the passphrase should be provided separately when needed.
  Future<void> decrypt(String keyId, String? password) async {
    final entry = await keyStore.loadEntry(keyId);
    if (entry == null) {
      throw StateError('Key $keyId does not exist');
    }

    // If storage is encrypted, password is required
    if (entry.isEncrypted && (password == null || password.isEmpty)) {
      throw BuiltInSshKeyDecryptException();
    }

    // Get key bytes from the entry (decrypts storage if encrypted, returns plaintext if not)
    final pemBytes = await keyStore.decryptEntry(entry, password);

    // Convert to string
    final pem = utf8.decode(pemBytes);

    // Parse the key - if the key itself has a passphrase, we'll handle that separately
    // when the key is actually used (via BuiltInSshKeyPassphraseRequired exception)
    // For now, try parsing without passphrase - if it fails, that's okay, we'll handle it later
    SSHKeyPair keyPair;
    try {
      keyPair = SSHKeyPair.fromPem(pem).first;
    } on ArgumentError catch (e, stackTrace) {
      AppLogger().warn(
        'Error parsing SSH key $keyId',
        tag: 'BuiltInSSHVault',
        error: e,
        stackTrace: stackTrace,
      );
      if (e.message == 'passphrase is required for encrypted key') {
        // Key has passphrase - store the encrypted PEM as-is
        // The passphrase will be requested when the key is actually used
        _decrypted[keyId] = Uint8List.fromList(utf8.encode(pem));
        _decryptedEntries[keyId] = entry;
        notifyListeners();
        return;
      }
      rethrow;
    } on StateError catch (e, stackTrace) {
      AppLogger().warn(
        'Error parsing SSH key $keyId',
        tag: 'BuiltInSSHVault',
        error: e,
        stackTrace: stackTrace,
      );
      if (e.message.contains('encrypted')) {
        // Key has passphrase - store the encrypted PEM as-is
        _decrypted[keyId] = Uint8List.fromList(utf8.encode(pem));
        _decryptedEntries[keyId] = entry;
        notifyListeners();
        return;
      }
      rethrow;
    }

    // Convert to decrypted PEM
    final decryptedPem = keyPair.toPem();

    // Store decrypted pem as bytes
    _decrypted[keyId] = Uint8List.fromList(utf8.encode(decryptedPem));
    _decryptedEntries[keyId] = entry;

    notifyListeners();
  }

  void clearDecrypted(String keyId) {
    final removedKey = _decrypted.remove(keyId);
    final removedEntry = _decryptedEntries.remove(keyId);
    if (removedKey != null || removedEntry != null) {
      notifyListeners();
    }
  }

  void clearAllDecrypted() {
    if (_decrypted.isNotEmpty || _decryptedEntries.isNotEmpty) {
      _decrypted.clear();
      _decryptedEntries.clear();
      notifyListeners();
    }
  }
}
