import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';

class TrashTab extends StatefulWidget {
  const TrashTab({
    super.key,
    required this.manager,
    this.shellService = const ProcessRemoteShellService(),
    this.builtInVault,
  });

  final ExplorerTrashManager manager;
  final RemoteShellService shellService;
  final BuiltInSshVault? builtInVault;

  @override
  State<TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<TrashTab> {
  late Future<List<TrashedEntry>> _entriesFuture;
  late final VoidCallback _changesListener;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.manager.loadEntries();
    _changesListener = () {
      if (!mounted) return;
      setState(() {
        _entriesFuture = widget.manager.loadEntries();
      });
    };
    widget.manager.changes.addListener(_changesListener);
  }

  @override
  void dispose() {
    widget.manager.changes.removeListener(_changesListener);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _entriesFuture = widget.manager.loadEntries();
    });
    await _entriesFuture;
  }

  bool _unlockInProgress = false;
  final Map<String, Future<String?>> _pendingPassphrasePrompts = {};

  Future<T> _runShell<T>(Future<T> Function() action) {
    if (widget.builtInVault == null) {
      return action();
    }
    return _withBuiltinUnlock(action);
  }

  Future<T> _withBuiltinUnlock<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } on BuiltInSshKeyLockedException catch (error) {
        final unlocked = await _promptUnlock(error.keyId);
        if (!unlocked) {
          rethrow;
        }
        continue;
      } on BuiltInSshKeyPassphraseRequired catch (error) {
        final keyLabel = error.keyLabel ?? error.keyId;
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          'built-in key $keyLabel',
        );
        if (passphrase == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Passphrase is required to continue.'),
              ),
            );
          }
          rethrow;
        }
        final service = widget.shellService;
        if (service is BuiltInRemoteShellService) {
          service.setBuiltInKeyPassphrase(error.keyId, passphrase);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Passphrase stored for $keyLabel.'),
            ),
          );
        }
        continue;
      } on BuiltInSshKeyUnsupportedCipher catch (error) {
        final keyLabel = error.keyLabel ?? error.keyId;
        final detail = error.error.message ?? error.error.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Key $keyLabel uses an unsupported cipher ($detail).',
              ),
            ),
          );
        }
        rethrow;
      } on BuiltInSshIdentityPassphraseRequired catch (error) {
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          error.identityPath,
        );
        if (passphrase == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Passphrase is required to continue.'),
              ),
            );
          }
          rethrow;
        }
        final service = widget.shellService;
        if (service is BuiltInRemoteShellService) {
          service.setIdentityPassphrase(error.identityPath, passphrase);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Passphrase stored for ${error.identityPath}.'),
            ),
          );
        }
        continue;
      }
    }
  }

  Future<bool> _promptUnlock(String keyId) async {
    if (_unlockInProgress) {
      return false;
    }
    final vault = widget.builtInVault;
    if (vault == null) {
      return false;
    }
    _unlockInProgress = true;
    debugPrint('[Trash] Prompting unlock for key $keyId');
    try {
      final password = await _showUnlockDialog(keyId);
      if (password == null) {
        debugPrint('[Trash] Unlock cancelled for key $keyId');
        return false;
      }
      await vault.unlock(keyId, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
        debugPrint('[Trash] Unlock succeeded for key $keyId');
      }
      return true;
    } on BuiltInSshKeyDecryptException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password for that key.')),
        );
      }
      debugPrint('[Trash] Unlock failed: bad password for key $keyId');
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
      }
      debugPrint('[Trash] Unlock failed for key $keyId: $error');
      return false;
    } finally {
      _unlockInProgress = false;
      debugPrint('[Trash] Unlock flow completed for key $keyId');
    }
  }

  Future<String?> _showUnlockDialog(String keyId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Unlock key $keyId'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }

  Future<String?> _awaitPassphraseInput(String host, String path) {
    final key = '$host|$path';
    final existing = _pendingPassphrasePrompts[key];
    if (existing != null) {
      debugPrint('[Trash] Awaiting existing passphrase for $key');
      return existing;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        debugPrint('[Trash] Prompting passphrase for $key');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        debugPrint('[Trash] Passphrase prompt completed for $key');
      }
    }();
    return completer.future;
  }

  Future<String?> _promptPassphrase(String host, String path) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Passphrase for $host ($path)'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trash', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<TrashedEntry>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load trash: ${snapshot.error}'),
                  );
                }
                final entries = [...(snapshot.data ?? const <TrashedEntry>[])];
                if (entries.isEmpty) {
                  return const Center(child: Text('Trash is empty.'));
                }
                entries.sort((a, b) => b.trashedAt.compareTo(a.trashedAt));
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          entry.isDirectory
                              ? Icons.folder
                              : Icons.insert_drive_file,
                        ),
                        title: Text(entry.displayName),
                        subtitle: Text(
                          '${entry.hostName} · ${entry.remotePath}\nTrashed ${entry.trashedAt.toLocal()} · ${_formatBytes(entry.sizeBytes)}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              tooltip: 'Restore to ${entry.remotePath}',
                              icon: const Icon(Icons.restore),
                              onPressed: () => _restoreEntry(entry),
                            ),
                            IconButton(
                              tooltip: 'Show in file browser',
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => _revealEntry(entry),
                            ),
                            IconButton(
                              tooltip: 'Delete permanently',
                              icon: const Icon(Icons.delete_forever),
                              onPressed: () => _deleteEntry(entry),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteEntry(TrashedEntry entry) async {
    await widget.manager.deleteEntry(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${entry.displayName} permanently')),
    );
  }

  Future<void> _restoreEntry(TrashedEntry entry) async {
    try {
      await _runShell(
        () => widget.manager.restoreEntry(
          entry: entry,
          shellService: widget.shellService,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${entry.displayName} to ${entry.remotePath}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    }
  }

  Future<void> _revealEntry(TrashedEntry entry) async {
    final path = entry.localPath;
    if (Platform.isMacOS) {
      await Process.start('open', [path]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', ['/select,$path']);
    } else {
      await Process.start('xdg-open', [File(path).parent.path]);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}
