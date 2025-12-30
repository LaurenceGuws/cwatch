import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../../logging/app_logger.dart';
import '../../settings/settings_path_provider.dart';
import 'builtin_ssh_key_entry.dart';

class BuiltInSshKeyStore {
  BuiltInSshKeyStore({SettingsPathProvider? pathProvider})
    : _pathProvider = pathProvider ?? const SettingsPathProvider();

  final SettingsPathProvider _pathProvider;
  static const _dirName = 'cwatch_builtin_ssh_keys';
  static const _metaExtension = '.json';

  Directory? _cachedDir;

  Future<Directory> _resolveDirectory() async {
    if (_cachedDir != null) {
      return _cachedDir!;
    }
    final base = await _getBaseDirectory();
    final dir = Directory(p.join(base, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  Future<String> _getBaseDirectory() async {
    return await _pathProvider.configDirectory();
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
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to read SSH key metadata from ${entity.path}',
          tag: 'BuiltInSSHKeyStore',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return entries;
  }

  Future<BuiltInSshKeyEntry> addEntry({
    required String label,
    required List<int> keyData,
    String? password,
  }) async {
    final id = _generateId();
    final keyText = utf8.decode(keyData);

    // Try to parse the key to determine if it's encrypted
    bool keyIsEncrypted = false;
    try {
      // Try parsing without passphrase - if it fails, the key is encrypted
      SSHKeyPair.fromPem(keyText);
      keyIsEncrypted = false;
      AppLogger.d(
        'Key "$label" (id=$id) is unencrypted (no passphrase)',
        tag: 'BuiltInSSHKeyStore',
      );
    } on ArgumentError catch (e) {
      if (e.message == 'passphrase is required for encrypted key') {
        keyIsEncrypted = true;
        AppLogger.d(
          'Key "$label" (id=$id) is encrypted (has passphrase)',
          tag: 'BuiltInSSHKeyStore',
        );
      } else {
        rethrow;
      }
    } on StateError catch (e) {
      if (e.message.contains('encrypted')) {
        keyIsEncrypted = true;
        AppLogger.d(
          'Key "$label" (id=$id) is encrypted (has passphrase)',
          tag: 'BuiltInSSHKeyStore',
        );
      } else {
        rethrow;
      }
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to parse SSH key "$label" (id=$id); assuming unencrypted',
        tag: 'BuiltInSSHKeyStore',
        error: error,
        stackTrace: stackTrace,
      );
      keyIsEncrypted = false;
    }

    final entry = await buildEntry(
      id: id,
      label: label,
      keyData: keyData,
      keyIsEncrypted: keyIsEncrypted,
      password: password,
    );
    await writeEntry(entry);
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
    String? password,
  ) async {
    if (!entry.isEncrypted) {
      // Unencrypted entry - return plaintext directly
      if (entry.plaintext == null) {
        throw StateError('Unencrypted entry missing plaintext');
      }
      return Uint8List.fromList(utf8.encode(entry.plaintext!));
    }

    // Encrypted entry - requires password
    if (password == null || password.isEmpty) {
      throw BuiltInSshKeyDecryptException();
    }

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

  Future<void> writeEntry(BuiltInSshKeyEntry entry) async {
    await _writeEntry(entry);
  }

  Future<File> _entryFile(String id) async {
    final dir = await _resolveDirectory();
    return File(p.join(dir.path, '$id$_metaExtension'));
  }

  Future<BuiltInSshKeyEntry> buildEntry({
    required String id,
    required String label,
    required List<int> keyData,
    required bool keyIsEncrypted,
    String? password,
  }) async {
    final fingerprint = await _fingerprint(keyData);
    final createdAt = DateTime.now().toUtc();

    // If key is unencrypted and password is provided, encrypt it
    // If key is unencrypted and no password, store as plaintext
    // If key is encrypted, password is required to encrypt the storage
    final shouldEncryptStorage = password != null && password.isNotEmpty;

    if (shouldEncryptStorage) {
      // Encrypt the key data for storage
      AppLogger.d(
        'Encrypting storage for key "$label" (id=$id). '
        'Key itself is ${keyIsEncrypted ? "encrypted (has passphrase)" : "unencrypted"}.',
        tag: 'BuiltInSSHKeyStore',
      );
      final salt = _randomBytes(16);
      final nonce = _randomBytes(12);
      final secretKey = await _deriveSecretKey(password, salt);
      final algorithm = AesGcm.with256bits();
      final secretBox = await algorithm.encrypt(
        keyData,
        secretKey: secretKey,
        nonce: nonce,
      );
      return BuiltInSshKeyEntry(
        id: id,
        label: label,
        fingerprint: fingerprint,
        createdAt: createdAt,
        isEncrypted: true,
        keyHasPassphrase: keyIsEncrypted,
        salt: base64.encode(salt),
        nonce: base64.encode(nonce),
        ciphertext: base64.encode(secretBox.cipherText),
        mac: base64.encode(secretBox.mac.bytes),
      );
    } else {
      // Store as plaintext (unencrypted)
      AppLogger.d(
        'Storing key "$label" (id=$id) as plaintext (no storage encryption). '
        'Key itself is ${keyIsEncrypted ? "encrypted (has passphrase)" : "unencrypted"}.',
        tag: 'BuiltInSSHKeyStore',
      );
      final keyText = utf8.decode(keyData);
      return BuiltInSshKeyEntry(
        id: id,
        label: label,
        fingerprint: fingerprint,
        createdAt: createdAt,
        isEncrypted: false,
        keyHasPassphrase: keyIsEncrypted,
        plaintext: keyText,
      );
    }
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
