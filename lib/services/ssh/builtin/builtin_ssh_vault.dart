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

  /// Fully decrypts a PEM key into unencrypted PEM so dartssh2 will NOT re-prompt.
  Future<void> unlock(String keyId, String password) async {
    final entry = await keyStore.loadEntry(keyId);
    if (entry == null) {
      throw StateError('Key $keyId does not exist');
    }

    // Encrypted key bytes from the entry
    final encryptedPemBytes = await keyStore.decryptEntry(entry, password);

    // Convert encrypted file to string
    final encryptedPem = utf8.decode(encryptedPemBytes);

    // Parse using passphrase → get fully decrypted keypair(s)
    final keyPairs = SSHKeyPair.fromPem(encryptedPem, password);

    // Convert first keypair to UNENCRYPTED PEM
    final unencryptedPem = keyPairs.first.toPem();

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

