import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cwatch/models/remote_file_entry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../remote_ls_parser.dart';
import '../remote_shell_service.dart';
import 'builtin_ssh_vault.dart';

class BuiltInRemoteShellService extends RemoteShellService {
  BuiltInRemoteShellService({
    required this.vault,
    Map<String, String>? hostKeyBindings,
    this.connectTimeout = const Duration(seconds: 10),
  }) : _hostKeyBindings = Map.unmodifiable(hostKeyBindings ?? const {});

  final BuiltInSshVault vault;
  final Duration connectTimeout;
  final Map<String, String> _hostKeyBindings;
  final Map<String, String> _identityPassphrases = {};
  final Map<String, String> _builtInKeyPassphrases = {};

  @override
  Future<List<RemoteFileEntry>> listDirectory(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final sanitized = _sanitizePath(path);
    final command =
        "cd '${_escapeSingleQuotes(sanitized)}' && ls -al --time-style=+%Y-%m-%dT%H:%M:%S";
    final output = await _runCommand(host, command, timeout: timeout);
    return parseLsOutput(output);
  }

  @override
  Future<String> homeDirectory(
    SshHost host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final output = await _runCommand(host, 'echo \$HOME', timeout: timeout);
    final trimmed = output.trim();
    return trimmed.isEmpty ? '/' : trimmed;
  }

  @override
  Future<String> readFile(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final command = "cat '${_escapeSingleQuotes(normalized)}'";
    return _runCommand(host, command, timeout: timeout);
  }

  @override
  Future<void> writeFile(
    SshHost host,
    String path,
    String contents, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final delimiter = _randomDelimiter();
    final encoded = base64.encode(utf8.encode(contents));
    final command =
        "base64 -d > '${_escapeSingleQuotes(normalized)}' <<'$delimiter'\n$encoded\n$delimiter";
    await _runCommand(host, command, timeout: timeout);
  }

  @override
  Future<void> movePath(
    SshHost host,
    String source,
    String destination, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalizedSource = _sanitizePath(source);
    final normalizedDest = _sanitizePath(destination);
    await _runRemoteCommand(
      host,
      "mv '${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
  }

  @override
  Future<void> copyPath(
    SshHost host,
    String source,
    String destination, {
    bool recursive = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final normalizedSource = _sanitizePath(source);
    final normalizedDest = _sanitizePath(destination);
    final flag = recursive ? '-R ' : '';
    await _runRemoteCommand(
      host,
      "cp $flag'${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    await _runRemoteCommand(
      host,
      "rm -rf '${_escapeSingleQuotes(normalized)}'",
      timeout: timeout,
    );
  }

  @override
  Future<void> copyBetweenHosts({
    required SshHost sourceHost,
    required String sourcePath,
    required SshHost destinationHost,
    required String destinationPath,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cwatch-ssh-copy-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await downloadPath(
        host: sourceHost,
        remotePath: sourcePath,
        localDestination: tempDir.path,
        recursive: recursive,
        timeout: timeout,
      );
      final localRoot = p.join(tempDir.path, p.basename(sourcePath));
      await uploadPath(
        host: destinationHost,
        localPath: localRoot,
        remoteDestination: destinationPath,
        recursive: recursive,
        timeout: timeout,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  @override
  Future<void> downloadPath({
    required SshHost host,
    required String remotePath,
    required String localDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final sanitized = _sanitizePath(remotePath);
    final destinationDir = Directory(localDestination);
    await destinationDir.create(recursive: true);
    await _withSftp(host, (sftp) async {
      final attrs = await _stat(sftp, sanitized);
      if (attrs.isDirectory) {
        if (!recursive) {
          throw Exception('Remote path is a directory; enable recursion.');
        }
        await _downloadDirectory(sftp, sanitized, destinationDir.path);
        return;
      }
      final localTarget = p.join(destinationDir.path, p.basename(sanitized));
      await _downloadFile(sftp, sanitized, localTarget);
    }).timeout(timeout);
  }

  @override
  Future<void> uploadPath({
    required SshHost host,
    required String localPath,
    required String remoteDestination,
    bool recursive = false,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final normalizedDest = _sanitizePath(remoteDestination);
    final entryType = FileSystemEntity.typeSync(localPath);
    await _withSftp(host, (sftp) async {
      if (entryType == FileSystemEntityType.directory) {
        if (!recursive) {
          throw Exception('Uploading directories requires recursive flag.');
        }
        final remoteDir = _joinPath(normalizedDest, p.basename(localPath));
        await _ensureRemoteDirectory(sftp, _dirname(remoteDir));
        await _uploadDirectory(sftp, Directory(localPath), remoteDir);
        return;
      }
      await _ensureRemoteDirectory(sftp, _dirname(normalizedDest));
      await _uploadFile(sftp, File(localPath), normalizedDest);
    }).timeout(timeout);
  }

  Future<void> _runRemoteCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _runCommand(host, command, timeout: timeout).then((_) => null);
  }

  Future<String> _runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _log('Running command on ${host.name}: $command');
    final bytes = await _withClient(
      host,
      (client) => client.run(command),
    ).timeout(timeout);
    final output = utf8.decode(bytes, allowMalformed: true);
    _log('Command on ${host.name} completed. Output length=${output.length}');
    return output;
  }

  Future<T> _withClient<T>(
    SshHost host,
    Future<T> Function(SSHClient client) action,
  ) async {
    final client = await _openClient(host);
    try {
      return await action(client);
    } finally {
      client.close();
      await client.done;
    }
  }

  Future<T> _withSftp<T>(
    SshHost host,
    Future<T> Function(SftpClient client) action,
  ) async {
    return _withClient(host, (client) async {
      final sftp = await client.sftp();
      try {
        return await action(sftp);
      } finally {
        sftp.close();
      }
    });
  }

  Future<SSHClient> _openClient(SshHost host) async {
    final socket = await SSHSocket.connect(
      host.hostname,
      host.port,
      timeout: connectTimeout,
    );
    final username =
        host.user ??
        Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        'root';
    final identities = await _collectIdentities(host);
    if (identities.isEmpty) {
      socket.destroy();
      throw Exception('No SSH identity available for ${host.name}');
    }
    return SSHClient(
      socket,
      username: username,
      identities: identities,
      disableHostkeyVerification: true,
    );
  }

  Future<List<SSHKeyPair>> _collectIdentities(SshHost host) async {
    _log(
      'Collecting identities for ${host.name} (files=${host.identityFiles.length})',
    );
    final identities = <SSHKeyPair>[];
    for (final identityPath in host.identityFiles) {
      try {
        // NEW: If this identity is a built-in key and already unlocked, use that PEM directly.
        final builtInId = _hostKeyBindings[host.name];
        if (builtInId != null) {
          final unlockedKey = vault.getUnlockedKey(builtInId);
          if (unlockedKey != null) {
            try {
              final pem = utf8.decode(unlockedKey);
              final keyPairs = SSHKeyPair.fromPem(pem);
              identities.addAll(keyPairs);
              _log(
                'Using previously-unlocked built-in key $builtInId for ${host.name}',
              );
              continue; // skip reading file (we already added identity)
            } catch (e, st) {
              _log('Failed loading previously-unlocked key: $e\n$st');
              // fall through to normal identity processing
            }
          }
        }
        final contents = await File(identityPath).readAsString();
        final passphrase = _identityPassphrases[identityPath];

        // Try to parse the key
        identities.addAll(
          passphrase == null
              ? SSHKeyPair.fromPem(contents)
              : SSHKeyPair.fromPem(contents, passphrase),
        );

        _log(
          'Added identity $identityPath for ${host.name} (hasPassphrase=${passphrase != null})',
        );
      } on SSHKeyDecryptError catch (error) {
        throw BuiltInSshIdentityPassphraseRequired(
          hostName: host.name,
          identityPath: identityPath,
          error: error,
        );
      } on UnsupportedError catch (error) {
        // unsupported cipher in identity file
        // (you may want an IdentityUnsupportedCipher error, but since you didn't define one, just skip)
        _log("Unsupported cipher in identity $identityPath: $error");
        continue;
      } on ArgumentError catch (error) {
        // <-- NEW: PEM-encrypted key requires passphrase
        if (error.message == 'passphrase is required for encrypted key') {
          throw BuiltInSshIdentityPassphraseRequired(
            hostName: host.name,
            identityPath: identityPath,
            error: SSHKeyDecryptError(error.toString()),
          );
        }
        rethrow;
      } on StateError catch (error) {
        // dartssh2 sometimes throws StateError for PEM-encrypted keys
        if (error.message.contains('encrypted')) {
          throw BuiltInSshIdentityPassphraseRequired(
            hostName: host.name,
            identityPath: identityPath,
            error: SSHKeyDecryptError(error.toString()),
          );
        }
        rethrow;
      } catch (_) {
        continue;
      }
    }
    final keyId = _hostKeyBindings[host.name];
    if (keyId != null) {
      final unlocked = vault.getUnlockedKey(keyId);
      if (unlocked == null) {
        throw BuiltInSshKeyLockedException(host.name, keyId);
      }
      _log('Using unlocked built-in key $keyId for host ${host.name}');
      final pem = utf8.decode(unlocked, allowMalformed: true);
      final passphrase = _builtInKeyPassphrases[keyId];
      try {
        identities.addAll(
          passphrase == null
              ? SSHKeyPair.fromPem(pem)
              : SSHKeyPair.fromPem(pem, passphrase),
        );
      } on SSHKeyDecryptError catch (error) {
        final label = vault.getUnlockedEntry(keyId)?.label;
        throw BuiltInSshKeyPassphraseRequired(
          hostName: host.name,
          keyId: keyId,
          keyLabel: label,
          error: error,
        );
      } on UnsupportedError catch (error) {
        final label = vault.getUnlockedEntry(keyId)?.label;
        throw BuiltInSshKeyUnsupportedCipher(
          hostName: host.name,
          keyId: keyId,
          keyLabel: label,
          error: error,
        );
      } on ArgumentError catch (error) {
        // <-- NEW: PEM format encrypted key without passphrase
        if (error.message == 'passphrase is required for encrypted key') {
          final label = vault.getUnlockedEntry(keyId)?.label;
          throw BuiltInSshKeyPassphraseRequired(
            hostName: host.name,
            keyId: keyId,
            keyLabel: label,
            error: SSHKeyDecryptError(error.toString()),
          );
        }
        rethrow;
      } on StateError catch (error) {
        // <-- NEW: Some PEM encrypted-key parse failures come as StateError
        if (error.message.contains('encrypted')) {
          final label = vault.getUnlockedEntry(keyId)?.label;
          throw BuiltInSshKeyPassphraseRequired(
            hostName: host.name,
            keyId: keyId,
            keyLabel: label,
            error: SSHKeyDecryptError(error.toString()),
          );
        }
        rethrow;
      }
    }
    return identities;
  }

  void setIdentityPassphrase(String identityPath, String passphrase) {
    _identityPassphrases[identityPath] = passphrase;
  }

  void setBuiltInKeyPassphrase(String keyId, String passphrase) {
    _builtInKeyPassphrases[keyId] = passphrase;
  }

  /// Returns the built-in key ID bound to this host, if any.
  String? getActiveBuiltInKeyId(SshHost host) {
    return _hostKeyBindings[host.name];
  }

  Future<void> _downloadFile(
    SftpClient sftp,
    String remotePath,
    String localPath,
  ) async {
    final file = await sftp.open(remotePath);
    try {
      final contents = await file.readBytes();
      final targetFile = File(localPath);
      await targetFile.create(recursive: true);
      await targetFile.writeAsBytes(contents, flush: true);
    } finally {
      await file.close();
    }
  }

  Future<void> _downloadDirectory(
    SftpClient sftp,
    String remotePath,
    String localDestination,
  ) async {
    final target = p.join(localDestination, p.basename(remotePath));
    final dir = Directory(target);
    await dir.create(recursive: true);
    final entries = await sftp.listdir(remotePath);
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') {
        continue;
      }
      final childRemote = _joinPath(remotePath, entry.filename);
      final childLocal = p.join(target, entry.filename);
      if (entry.attr.isDirectory) {
        await _downloadDirectory(sftp, childRemote, target);
      } else {
        await _downloadFile(sftp, childRemote, childLocal);
      }
    }
  }

  Future<void> _uploadFile(
    SftpClient sftp,
    File localFile,
    String remotePath,
  ) async {
    final contents = await localFile.readAsBytes();
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.writeBytes(contents);
    } finally {
      await file.close();
    }
  }

  Future<void> _uploadDirectory(
    SftpClient sftp,
    Directory localDir,
    String remoteRoot,
  ) async {
    await _ensureRemoteDirectory(sftp, remoteRoot);
    await for (final entity in localDir.list(recursive: false)) {
      final name = p.basename(entity.path);
      final remotePath = _joinPath(remoteRoot, name);
      if (entity is Directory) {
        await _uploadDirectory(sftp, entity, remotePath);
      } else if (entity is File) {
        await _ensureRemoteDirectory(sftp, _dirname(remotePath));
        await _uploadFile(sftp, entity, remotePath);
      }
    }
  }

  Future<void> _ensureRemoteDirectory(SftpClient sftp, String path) async {
    final normalized = _sanitizePath(path);
    if (normalized == '/' || normalized.isEmpty) {
      return;
    }
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    var current = '';
    for (final segment in segments) {
      current = '$current/$segment';
      final exists = await _remotePathExists(sftp, current);
      if (exists) continue;
      try {
        await sftp.mkdir(current);
      } catch (_) {
        // ignore if creation fails
      }
    }
  }

  Future<SftpFileAttrs> _stat(SftpClient sftp, String path) async {
    return await sftp.stat(path);
  }

  Future<bool> _remotePathExists(SftpClient sftp, String path) async {
    try {
      await sftp.stat(path);
      return true;
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) {
        return false;
      }
      rethrow;
    }
  }

  String _sanitizePath(String path) {
    if (path.isEmpty) return '/';
    if (path.startsWith('/')) {
      return path;
    }
    return '/$path';
  }

  String _joinPath(String base, String segment) {
    if (segment.isEmpty) return base;
    final trimmedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    return '$trimmedBase/$segment';
  }

  String _dirname(String path) {
    final normalized = _sanitizePath(path);
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String _escapeSingleQuotes(String input) => input.replaceAll("'", r"'\''");

  String _randomDelimiter() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      12,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}

class BuiltInSshKeyLockedException implements Exception {
  BuiltInSshKeyLockedException(this.hostName, this.keyId);

  final String hostName;
  final String keyId;
}

class BuiltInSshKeyPassphraseRequired implements Exception {
  const BuiltInSshKeyPassphraseRequired({
    required this.hostName,
    required this.keyId,
    this.keyLabel,
    required this.error,
  });

  final String hostName;
  final String keyId;
  final String? keyLabel;
  final SSHKeyDecryptError error;
}

class BuiltInSshKeyUnsupportedCipher implements Exception {
  const BuiltInSshKeyUnsupportedCipher({
    required this.hostName,
    required this.keyId,
    this.keyLabel,
    required this.error,
  });

  final String hostName;
  final String keyId;
  final String? keyLabel;
  final UnsupportedError error;
}

class BuiltInSshIdentityPassphraseRequired implements Exception {
  const BuiltInSshIdentityPassphraseRequired({
    required this.hostName,
    required this.identityPath,
    required this.error,
  });

  final String hostName;
  final String identityPath;
  final SSHKeyDecryptError error;
}

void _log(String message) {
  debugPrint('[BuiltInSSH] $message');
}
