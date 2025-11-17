import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'builtin_ssh_key_entry.dart';

class BuiltInSshKeyStore {
  BuiltInSshKeyStore();

  static const _dirName = 'cwatch_builtin_ssh_keys';
  static const _metaExtension = '.json';

  Directory? _cachedDir;

  Future<Directory> _resolveDirectory() async {
    if (_cachedDir != null) {
      return _cachedDir!;
    }
    final base = await _getBaseDirectory();
    final dir = Directory(p.join(base.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  Future<Directory> _getBaseDirectory() async {
    Directory temp;
    try {
      temp = await getTemporaryDirectory();
    } on MissingPluginException {
      temp = Directory.systemTemp;
    }
    return Directory(p.join(temp.path, 'cwatch'));
  }

  Future<List<BuiltInSshKeyEntry>> listEntries() async {
    final dir = await _resolveDirectory();
    final entries = <BuiltInSshKeyEntry>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith(_metaExtension)) {
        continue;
      }
      try {
        final contents = await entity.readAsString();
        final jsonMap = jsonDecode(contents);
        if (jsonMap is Map<String, dynamic>) {
          entries.add(BuiltInSshKeyEntry.fromJson(jsonMap));
        }
      } catch (_) {
        continue;
      }
    }
    return entries;
  }

  Future<BuiltInSshKeyEntry> addEntry({
    required String label,
    required List<int> keyData,
    required String password,
  }) async {
    final id = _generateId();
    final entry = await _buildEntry(
      id: id,
      label: label,
      keyData: keyData,
      password: password,
    );
    await _writeEntry(entry);
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final file = await _entryFile(id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<BuiltInSshKeyEntry?> loadEntry(String id) async {
    final file = await _entryFile(id);
    if (!await file.exists()) {
      return null;
    }
    final contents = await file.readAsString();
    final jsonMap = jsonDecode(contents);
    if (jsonMap is! Map<String, dynamic>) {
      return null;
    }
    return BuiltInSshKeyEntry.fromJson(jsonMap);
  }

  Future<Uint8List> decryptEntry(
    BuiltInSshKeyEntry entry,
    String password,
  ) async {
    final key = await _deriveSecretKey(password, entry.saltBytes);
    final algorithm = AesGcm.with256bits();
    final secret = SecretBox(
      entry.ciphertextBytes,
      nonce: entry.nonceBytes,
      mac: Mac(entry.macBytes),
    );
    try {
      final plaintext = await algorithm.decrypt(secret, secretKey: key);
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw BuiltInSshKeyDecryptException();
    }
  }

  Future<void> _writeEntry(BuiltInSshKeyEntry entry) async {
    final file = await _entryFile(entry.id);
    await file.writeAsString(jsonEncode(entry.toJson()));
  }

  Future<File> _entryFile(String id) async {
    final dir = await _resolveDirectory();
    return File(p.join(dir.path, '$id$_metaExtension'));
  }

  Future<BuiltInSshKeyEntry> _buildEntry({
    required String id,
    required String label,
    required List<int> keyData,
    required String password,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveSecretKey(password, salt);
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      keyData,
      secretKey: secretKey,
      nonce: nonce,
    );
    final fingerprint = await _fingerprint(keyData);
    final createdAt = DateTime.now().toUtc();
    return BuiltInSshKeyEntry(
      id: id,
      label: label,
      fingerprint: fingerprint,
      createdAt: createdAt,
      salt: base64.encode(salt),
      nonce: base64.encode(nonce),
      ciphertext: base64.encode(secretBox.cipherText),
      mac: base64.encode(secretBox.mac.bytes),
    );
  }

  Future<SecretKey> _deriveSecretKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 120000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Future<String> _fingerprint(List<int> data) async {
    final digest = await Sha256().hash(data);
    return base64.encode(digest.bytes);
  }

  String _generateId() {
    final buffer = StringBuffer();
    final rand = Random.secure();
    for (var i = 0; i < 16; i++) {
      buffer.write(rand.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rand.nextInt(256);
    }
    return bytes;
  }
}

class BuiltInSshKeyDecryptException implements Exception {
  const BuiltInSshKeyDecryptException();
}
