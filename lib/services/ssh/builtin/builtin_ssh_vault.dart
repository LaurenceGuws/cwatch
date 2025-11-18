import 'dart:convert';
// import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';

import 'builtin_ssh_key_entry.dart';
import 'builtin_ssh_key_store.dart';

class BuiltInSshVault extends ChangeNotifier {
  BuiltInSshVault({required this.keyStore});

  final BuiltInSshKeyStore keyStore;
  final Map<String, Uint8List> _unlocked = {};
  final Map<String, BuiltInSshKeyEntry> _unlockedEntries = {};

  bool isUnlocked(String keyId) => _unlocked.containsKey(keyId);

  Uint8List? getUnlockedKey(String keyId) => _unlocked[keyId];
  BuiltInSshKeyEntry? getUnlockedEntry(String keyId) =>
      _unlockedEntries[keyId];

  /// Checks if a key requires a password to unlock (i.e., if storage is encrypted).
  Future<bool> needsPassword(String keyId) async {
    final entry = await keyStore.loadEntry(keyId);
    return entry?.isEncrypted ?? false;
  }

  /// Fully decrypts a PEM key into unencrypted PEM so dartssh2 will NOT re-prompt.
  /// For unencrypted storage, password can be null.
  /// For keys with passphrases, the passphrase should be provided separately when needed.
  Future<void> unlock(String keyId, String? password) async {
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
    } on ArgumentError catch (e) {
      if (e.message == 'passphrase is required for encrypted key') {
        // Key has passphrase - store the encrypted PEM as-is
        // The passphrase will be requested when the key is actually used
        _unlocked[keyId] = Uint8List.fromList(utf8.encode(pem));
        _unlockedEntries[keyId] = entry;
        notifyListeners();
        return;
      }
      rethrow;
    } on StateError catch (e) {
      if (e.message.contains('encrypted')) {
        // Key has passphrase - store the encrypted PEM as-is
        _unlocked[keyId] = Uint8List.fromList(utf8.encode(pem));
        _unlockedEntries[keyId] = entry;
        notifyListeners();
        return;
      }
      rethrow;
    }

    // Convert to UNENCRYPTED PEM
    final unencryptedPem = keyPair.toPem();

    // Store unencrypted pem as bytes
    _unlocked[keyId] = Uint8List.fromList(utf8.encode(unencryptedPem));
    _unlockedEntries[keyId] = entry;

    notifyListeners();
  }

  void forget(String keyId) {
    final removedKey = _unlocked.remove(keyId);
    final removedEntry = _unlockedEntries.remove(keyId);
    if (removedKey != null || removedEntry != null) {
      notifyListeners();
    }
  }

  void forgetAll() {
    if (_unlocked.isNotEmpty || _unlockedEntries.isNotEmpty) {
      _unlocked.clear();
      _unlockedEntries.clear();
      notifyListeners();
    }
  }
}

