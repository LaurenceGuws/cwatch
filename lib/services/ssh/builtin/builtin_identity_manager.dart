import 'dart:convert';
import 'dart:io';

import 'package:cwatch/models/ssh_host.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

import 'builtin_ssh_exceptions.dart';
import 'builtin_ssh_logging.dart';
import 'builtin_ssh_vault.dart';

class BuiltInSshIdentityManager {
  BuiltInSshIdentityManager({
    required this.vault,
    required Map<String, String> hostKeyBindings,
    this.promptUnlock,
  }) : _hostKeyBindings = Map.unmodifiable(hostKeyBindings);

  final BuiltInSshVault vault;
  final Map<String, String> _hostKeyBindings;
  final Future<bool> Function(String keyId, String hostName, String? keyLabel)?
      promptUnlock;

  final Map<String, String> _identityPassphrases = {};
  final Map<String, String> _builtInKeyPassphrases = {};
  static final Map<String, Future<void>> _pendingUnlocks = {};

  String? boundKeyForHost(String hostName) => _hostKeyBindings[hostName];

  void setIdentityPassphrase(String identityPath, String passphrase) {
    _identityPassphrases[identityPath] = passphrase;
  }

  void setBuiltInKeyPassphrase(String keyId, String passphrase) {
    _builtInKeyPassphrases[keyId] = passphrase;
  }

  Future<void> ensureUnlocked(SshHost host) async {
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
        logBuiltInSsh(
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

  Future<List<SSHKeyPair>> loadIdentities(SshHost host) async {
    logBuiltInSsh(
      'Collecting identities for ${host.name} (files=${host.identityFiles.length})',
    );
    final identities = <SSHKeyPair>[];
    final identityFilesToCheck = host.identityFiles.isEmpty
        ? _getDefaultIdentityFiles()
        : host.identityFiles;

    for (final identityPath in identityFilesToCheck) {
      try {
        final identityFile = File(identityPath);
        if (!await identityFile.exists()) {
          continue;
        }
        final contents = await identityFile.readAsString();
        final passphrase = _identityPassphrases[identityPath];
        identities.addAll(
          passphrase == null
              ? SSHKeyPair.fromPem(contents)
              : SSHKeyPair.fromPem(contents, passphrase),
        );
        logBuiltInSsh(
          'Added identity $identityPath for ${host.name} (hasPassphrase=${passphrase != null})',
        );
      } on SSHKeyDecryptError catch (error) {
        throw BuiltInSshIdentityPassphraseRequired(
          hostName: host.name,
          identityPath: identityPath,
          error: error,
        );
      } on UnsupportedError catch (error) {
        logBuiltInSsh('Unsupported cipher in identity $identityPath: $error');
        continue;
      } on ArgumentError catch (error) {
        if (error.message == 'passphrase is required for encrypted key') {
          throw BuiltInSshIdentityPassphraseRequired(
            hostName: host.name,
            identityPath: identityPath,
            error: SSHKeyDecryptError(error.toString()),
          );
        }
        rethrow;
      } on StateError catch (error) {
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
      final entry = await vault.keyStore.loadEntry(keyId);
      if (entry == null) {
        logBuiltInSsh(
          'Key $keyId bound to ${host.name} no longer exists. '
          'This binding should be removed from settings.',
        );
        return identities;
      }

      var unlockedKey = vault.getUnlockedKey(keyId);
      if (unlockedKey == null) {
        final needsPassword = await vault.needsPassword(keyId);
        if (!needsPassword) {
          try {
            await vault.unlock(keyId, null);
          } catch (_) {}
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
        logBuiltInSsh('Unlocked built-in key $keyId for host ${host.name}');
        unlockedKey = vault.getUnlockedKey(keyId);
      }

      if (unlockedKey == null) {
        throw BuiltInSshKeyLockedException(host.name, keyId, entry.label);
      }

      logBuiltInSsh('Using unlocked built-in key $keyId for host ${host.name}');
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
}
