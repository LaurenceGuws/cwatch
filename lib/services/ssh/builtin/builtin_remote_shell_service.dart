import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cwatch/models/remote_file_entry.dart';
import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import '../../logging/app_logger.dart';
import '../remote_shell_service.dart';
import '../terminal_session.dart';
import 'builtin_ssh_vault.dart';

class BuiltInRemoteShellService extends RemoteShellService {
  BuiltInRemoteShellService({
    required this.vault,
    Map<String, String>? hostKeyBindings,
    this.connectTimeout = const Duration(seconds: 10),
    super.debugMode = false,
    super.observer,
    this.promptUnlock,
  }) : _hostKeyBindings = Map.unmodifiable(hostKeyBindings ?? const {});

  final BuiltInSshVault vault;
  final Duration connectTimeout;
  final Map<String, String> _hostKeyBindings;
  final Future<bool> Function(String keyId, String hostName, String? keyLabel)?
  promptUnlock;
  final Map<String, String> _identityPassphrases = {};
  final Map<String, String> _builtInKeyPassphrases = {};
  static final Map<String, Future<void>> _pendingUnlocks = {};

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
    _log(
      'listDirectory output for ${host.name}:$path (length=${output.length})',
    );
    _log(
      'First 500 chars: ${output.length > 500 ? output.substring(0, 500) : output}',
    );
    final entries = parseLsOutput(output);
    _log('Parsed ${entries.length} entries from output');
    return entries;
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
    final output = await _runCommand(host, command, timeout: timeout);
    return output;
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
    final output = await _runCommand(host, command, timeout: timeout);
    final verification = await _verifyRemotePath(
      host,
      normalized,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'writeFile',
      command: command,
      output: output,
      verification: verification,
    );
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
    final run = await _runRemoteCommand(
      host,
      "mv '${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
    final verification = await _verifyRemotePath(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    final sourceGone = await _verifyRemotePath(
      host,
      normalizedSource,
      shouldExist: false,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'movePath',
      command: run.command,
      output: run.stdout,
      verification: verification?.combine(sourceGone),
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
    final run = await _runRemoteCommand(
      host,
      "cp $flag'${_escapeSingleQuotes(normalizedSource)}' '${_escapeSingleQuotes(normalizedDest)}'",
      timeout: timeout,
    );
    final verification = await _verifyRemotePath(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'copyPath',
      command: run.command,
      output: run.stdout,
      verification: verification,
    );
  }

  @override
  Future<void> deletePath(
    SshHost host,
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalized = _sanitizePath(path);
    final run = await _runRemoteCommand(
      host,
      "rm -rf '${_escapeSingleQuotes(normalized)}'",
      timeout: timeout,
    );
    final verification = await _verifyRemotePath(
      host,
      normalized,
      shouldExist: false,
      timeout: timeout,
    );
    emitDebugEvent(
      host: host,
      operation: 'deletePath',
      command: run.command,
      output: run.stdout,
      verification: verification,
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
    final verification = await _verifyRemotePath(
      destinationHost,
      _sanitizePath(destinationPath),
      shouldExist: true,
      timeout: const Duration(seconds: 10),
    );
    emitDebugEvent(
      host: destinationHost,
      operation: 'copyBetweenHosts',
      command:
          'sftp copy ${sourceHost.name}:$sourcePath -> ${destinationHost.name}:$destinationPath',
      output: 'completed',
      verification: verification,
    );
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
    void Function(int bytesTransferred)? onBytes,
  }) async {
    final normalizedDest = _sanitizePath(remoteDestination);
    final entryType = FileSystemEntity.typeSync(localPath);
    _log(
      'Upload request to ${host.name} (${host.hostname}:${host.port}) '
      'user=${host.user ?? 'root'} '
      'local=$localPath -> remote=$normalizedDest '
      'type=${entryType.name} recursive=$recursive',
    );
    if (entryType == FileSystemEntityType.notFound ||
        entryType == FileSystemEntityType.link) {
      throw Exception(
        'Local path "$localPath" is not found or not a regular file/directory.',
      );
    }
    await _withSftp(host, (sftp) async {
      if (entryType == FileSystemEntityType.directory) {
        if (!recursive) {
          throw Exception('Uploading directories requires recursive flag.');
        }
        final remoteDir = _joinPath(normalizedDest, p.basename(localPath));
        await _ensureRemoteDirectory(sftp, _dirname(remoteDir));
        await _uploadDirectory(
          sftp,
          Directory(localPath),
          remoteDir,
          onBytes: onBytes,
        );
        return;
      }
      await _ensureRemoteDirectory(sftp, _dirname(normalizedDest));
      await _uploadFile(
        sftp,
        File(localPath),
        normalizedDest,
        onBytes: onBytes,
      );
    }).timeout(timeout);
    final verification = await _verifyRemotePath(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: const Duration(seconds: 10),
    );
    emitDebugEvent(
      host: host,
      operation: 'uploadPath',
      command:
          'sftp upload user=${host.user ?? 'root'} $localPath -> $normalizedDest',
      output: 'completed',
      verification: verification,
    );
  }

  /// Upload file bytes directly (useful for Android where file paths may not be accessible)
  Future<void> uploadBytes({
    required SshHost host,
    required List<int> bytes,
    required String remoteDestination,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final normalizedDest = _sanitizePath(remoteDestination);
    await _withSftp(host, (sftp) async {
      await _ensureRemoteDirectory(sftp, _dirname(normalizedDest));
      await _uploadBytes(sftp, bytes, normalizedDest);
    }).timeout(timeout);
    final verification = await _verifyRemotePath(
      host,
      normalizedDest,
      shouldExist: true,
      timeout: const Duration(seconds: 10),
    );
    emitDebugEvent(
      host: host,
      operation: 'uploadBytes',
      command: 'sftp upload <bytes> -> $normalizedDest',
      output: 'completed',
      verification: verification,
    );
  }

  Future<RunResult> _runRemoteCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _log('Running remote command on ${host.name}: $command');
    // Run command and check exit code by appending ; echo $?
    final checkCommand = '$command; echo "EXIT_CODE:\$?"';
    final output = await _runCommand(host, checkCommand, timeout: timeout);

    // Check for exit code in output
    final exitCodeMatch = RegExp(r'EXIT_CODE:(\d+)').firstMatch(output);
    if (exitCodeMatch != null) {
      final exitCode = int.tryParse(exitCodeMatch.group(1) ?? '') ?? -1;
      if (exitCode != 0) {
        _log('Command failed on ${host.name} with exit code: $exitCode');
        throw Exception('Command failed with exit code $exitCode');
      }
      _log('Command on ${host.name} completed successfully');
    } else {
      // Fallback: if we can't parse exit code, assume success for backward compatibility
      // but log a warning
      _log('Warning: Could not parse exit code for command on ${host.name}');
    }
    return RunResult(command: command, stdout: output, stderr: '');
  }

  Future<String> _runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _log('Running command on ${host.name}: $command');
    final bytes = await _withClient(
      host,
      (client) => client.run(command).timeout(timeout),
    );
    final output = utf8.decode(bytes, allowMalformed: true);
    _log('Command on ${host.name} completed. Output length=${output.length}');
    return output;
  }

  Future<T> _withClient<T>(
    SshHost host,
    Future<T> Function(SSHClient client) action,
  ) async {
    SSHClient? client;
    try {
      await _ensureBuiltInKeyUnlocked(host);
      client = await _openClient(host);
      return await action(client);
    } on SSHAuthFailError catch (error) {
      _log('Authentication failed for ${host.name}: $error');
      throw BuiltInSshAuthenticationFailed(
        hostName: host.name,
        message: error.toString(),
      );
    } catch (e) {
      // Re-throw custom exceptions as-is
      if (e is BuiltInSshKeyLockedException ||
          e is BuiltInSshKeyPassphraseRequired ||
          e is BuiltInSshKeyUnsupportedCipher ||
          e is BuiltInSshIdentityPassphraseRequired ||
          e is BuiltInSshAuthenticationFailed) {
        rethrow;
      }
      // Wrap other errors
      _log('Error in SSH operation for ${host.name}: $e');
      throw Exception('SSH operation failed for ${host.name}: $e');
    } finally {
      client?.close();
      try {
        await client?.done;
      } catch (_) {
        // Ignore errors during cleanup
      }
    }
  }

  Future<void> _ensureBuiltInKeyUnlocked(SshHost host) async {
    final keyId = _hostKeyBindings[host.name];
    if (keyId == null) {
      return;
    }
    final pending = _pendingUnlocks[keyId];
    if (pending != null) {
      return pending;
    }
    final unlockFuture = () async {
      if (vault.isUnlocked(keyId)) {
        return;
      }
      final entry = await vault.keyStore.loadEntry(keyId);
      if (entry == null) {
        _log(
          'Key $keyId bound to ${host.name} no longer exists. '
          'Skipping unlock and continuing.',
        );
        return;
      }
      final needsPassword = await vault.needsPassword(keyId);
      if (!needsPassword) {
        try {
          await vault.unlock(keyId, null);
          return;
        } catch (_) {
          // Fall through to prompt
        }
      }
      if (promptUnlock != null) {
        final unlocked = await promptUnlock!(keyId, host.name, entry.label);
        if (unlocked && vault.isUnlocked(keyId)) {
          return;
        }
      }
      throw BuiltInSshKeyLockedException(host.name, keyId, entry.label);
    }();
    _pendingUnlocks[keyId] = unlockFuture;
    try {
      await unlockFuture;
    } finally {
      _pendingUnlocks.remove(keyId);
    }
  }

  @override
  Future<String> runCommand(
    SshHost host,
    String command, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _runCommand(host, command, timeout: timeout);
  }

  @override
  Future<TerminalSession> createTerminalSession(
    SshHost host, {
    required TerminalSessionOptions options,
  }) async {
    SSHClient? client;
    try {
      await _ensureBuiltInKeyUnlocked(host);
      client = await _openClient(host);
      final config = SSHPtyConfig(
        width: options.columns > 0 ? options.columns : 80,
        height: options.rows > 0 ? options.rows : 25,
        pixelWidth: options.pixelWidth,
        pixelHeight: options.pixelHeight,
      );
      final session = await client.shell(pty: config);
      return BuiltInTerminalSession(
        client: client,
        session: session,
        rows: options.rows > 0 ? options.rows : 25,
        columns: options.columns > 0 ? options.columns : 80,
      );
    } catch (error) {
      client?.close();
      rethrow;
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
    _log(
      'Opening SSH client to ${host.name}@${host.hostname}:${host.port} '
      'with ${identities.length} identities '
      'boundKey=${_hostKeyBindings[host.name] ?? 'none'}',
    );
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

    // If no identity files specified, use default SSH identity files
    final identityFilesToCheck = host.identityFiles.isEmpty
        ? _getDefaultIdentityFiles()
        : host.identityFiles;

    for (final identityPath in identityFilesToCheck) {
      try {
        // Skip non-existent files (especially for default identity files)
        final identityFile = File(identityPath);
        if (!await identityFile.exists()) {
          continue;
        }

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
        final contents = await identityFile.readAsString();
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
      // Check if the key entry exists
      final entry = await vault.keyStore.loadEntry(keyId);
      if (entry == null) {
        _log(
          'Key $keyId bound to ${host.name} no longer exists. '
          'This binding should be removed from settings.',
        );
        // Don't throw - just skip this key and continue with other identities
        // The binding will be cleaned up when settings are next saved
        return identities;
      }

      final unlocked = vault.getUnlockedKey(keyId);
      if (unlocked == null) {
        // Attempt auto-unlock for unencrypted storage
        final needsPassword = await vault.needsPassword(keyId);
        if (!needsPassword) {
          try {
            await vault.unlock(keyId, null);
          } catch (_) {
            // ignore and fall through to prompt/exception
          }
        }
        if (!vault.isUnlocked(keyId) && promptUnlock != null) {
          final unlockedViaPrompt = await promptUnlock!(
            keyId,
            host.name,
            entry.label,
          );
          if (!unlockedViaPrompt) {
            throw BuiltInSshKeyLockedException(host.name, keyId, entry.label);
          }
        }
        if (!vault.isUnlocked(keyId)) {
          throw BuiltInSshKeyLockedException(host.name, keyId, entry.label);
        }
        _log('Unlocked built-in key $keyId for host ${host.name}');
      }
      final unlockedKey = vault.getUnlockedKey(keyId);
      if (unlockedKey == null) {
        throw BuiltInSshKeyLockedException(host.name, keyId, entry.label);
      }
      _log('Using unlocked built-in key $keyId for host ${host.name}');
      final pem = utf8.decode(unlockedKey, allowMalformed: true);
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

  /// Returns the default SSH identity file paths that SSH would use
  /// when no IdentityFile is specified in the config.
  List<String> _getDefaultIdentityFiles() {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (homeDir.isEmpty) {
      return [];
    }
    final sshDir = p.join(homeDir, '.ssh');
    return [
      p.join(sshDir, 'id_rsa'),
      p.join(sshDir, 'id_ecdsa'),
      p.join(sshDir, 'id_ecdsa_sk'),
      p.join(sshDir, 'id_ed25519'),
      p.join(sshDir, 'id_ed25519_sk'),
      p.join(sshDir, 'id_dsa'),
      p.join(sshDir, 'id_xmss'),
    ];
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
    String remotePath, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      var position = 0;
      await for (final chunk in localFile.openRead()) {
        if (chunk.isEmpty) continue;
        final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        await file.writeBytes(data, offset: position);
        position += data.length;
        onBytes?.call(data.length);
      }
    } catch (e) {
      _log('Error streaming $remotePath: $e');
      rethrow;
    } finally {
      await file.close();
    }
  }

  Future<void> _uploadBytes(
    SftpClient sftp,
    List<int> bytes,
    String remotePath,
  ) async {
    _log('Uploading ${bytes.length} bytes to $remotePath');
    final file = await sftp.open(
      remotePath,
      mode:
          SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    try {
      final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      await file.writeBytes(data, offset: 0);
      _log('Successfully wrote ${bytes.length} bytes to $remotePath');
    } catch (e) {
      _log('Error writing bytes to $remotePath: $e');
      rethrow;
    } finally {
      await file.close();
    }
  }

  Future<void> _uploadDirectory(
    SftpClient sftp,
    Directory localDir,
    String remoteRoot, {
    void Function(int bytesTransferred)? onBytes,
  }) async {
    await _ensureRemoteDirectory(sftp, remoteRoot);
    await for (final entity in localDir.list(recursive: false)) {
      final name = p.basename(entity.path);
      final remotePath = _joinPath(remoteRoot, name);
      if (entity is Directory) {
        await _uploadDirectory(sftp, entity, remotePath, onBytes: onBytes);
      } else if (entity is File) {
        await _ensureRemoteDirectory(sftp, _dirname(remotePath));
        await _uploadFile(sftp, entity, remotePath, onBytes: onBytes);
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

  Future<VerificationResult?> _verifyRemotePath(
    SshHost host,
    String path, {
    required bool shouldExist,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!debugMode) {
      return null;
    }
    final command =
        "[ -e '${_escapeSingleQuotes(path)}' ] && echo 'EXISTS' || echo 'MISSING'";
    final output = await _runCommand(host, command, timeout: timeout);
    final exists = output.trim() == 'EXISTS';
    return VerificationResult(
      command: command,
      output: output,
      passed: shouldExist ? exists : !exists,
    );
  }
}

extension on FileSystemEntityType {
  Null get name => null;
}

class BuiltInTerminalSession implements TerminalSession {
  BuiltInTerminalSession({
    required this.client,
    required this.session,
    required this.rows,
    required this.columns,
  }) {
    _stdoutSubscription = session.stdout.listen(
      _handleOutput,
      onError: (_) => _cleanup(),
      onDone: _cleanup,
    );
    _stderrSubscription = session.stderr.listen(
      _handleOutput,
      onError: (_) => _cleanup(),
      onDone: _cleanup,
    );
    session.done.then((_) => _cleanup());
  }

  final SSHClient client;
  final SSHSession session;
  final int rows;
  final int columns;
  final _outputController = StreamController<Uint8List>.broadcast();

  late final StreamSubscription<Uint8List> _stdoutSubscription;
  late final StreamSubscription<Uint8List> _stderrSubscription;
  bool _closed = false;

  void _handleOutput(Uint8List data) {
    if (data.isEmpty || _closed) {
      return;
    }
    _outputController.add(data);
  }

  void _cleanup() {
    if (_closed) {
      return;
    }
    _closed = true;
    _stdoutSubscription.cancel();
    _stderrSubscription.cancel();
    _outputController.close();
    session.close();
    client.close();
  }

  @override
  Stream<Uint8List> get output => _outputController.stream;

  @override
  Future<int> get exitCode async {
    await session.done;
    return 0;
  }

  @override
  void write(Uint8List data) {
    if (_closed) {
      return;
    }
    session.write(data);
  }

  @override
  void resize(int rows, int cols) {
    if (_closed) {
      return;
    }
    // SSH expects width (columns) first, then height (rows).
    session.resizeTerminal(cols, rows);
  }

  @override
  void kill() {
    if (_closed) {
      return;
    }
    session.kill(_mapSignal(ProcessSignal.sigterm));
    _cleanup();
  }

  SSHSignal _mapSignal(ProcessSignal signal) {
    switch (signal) {
      case ProcessSignal.sigint:
        return SSHSignal.INT;
      case ProcessSignal.sigkill:
        return SSHSignal.KILL;
      case ProcessSignal.sigterm:
        return SSHSignal.TERM;
      default:
        return SSHSignal.TERM;
    }
  }
}

class BuiltInSshKeyLockedException implements Exception {
  BuiltInSshKeyLockedException(this.hostName, this.keyId, [this.keyLabel]);

  final String hostName;
  final String keyId;
  final String? keyLabel;
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

class BuiltInSshAuthenticationFailed implements Exception {
  const BuiltInSshAuthenticationFailed({
    required this.hostName,
    required this.message,
  });

  final String hostName;
  final String message;

  @override
  String toString() => 'SSH authentication failed for $hostName: $message';
}

void _log(String message) {
  AppLogger.d(message, tag: 'BuiltInSSH');
}
