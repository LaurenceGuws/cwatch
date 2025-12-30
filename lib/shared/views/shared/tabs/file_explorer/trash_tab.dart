import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../models/explorer_context.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../../services/ssh/builtin/builtin_ssh_key_service.dart';
import '../../../../../shared/theme/app_theme.dart';
import '../../../../../shared/widgets/dialog_keyboard_shortcuts.dart';
import 'ssh_auth_handler.dart';

class TrashTab extends StatefulWidget {
  const TrashTab({
    super.key,
    required this.manager,
    required this.shellService,
    this.keyService,
    this.context,
  });

  final ExplorerTrashManager manager;
  final RemoteShellService shellService;
  final BuiltInSshKeyService? keyService;
  final ExplorerContext? context;

  @override
  State<TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<TrashTab> {
  late Future<List<TrashedEntry>> _entriesFuture;
  late final VoidCallback _changesListener;

  @override
  void initState() {
    super.initState();
    _entriesFuture = widget.manager.loadEntries(contextId: widget.context?.id);
    _changesListener = () {
      if (!mounted) return;
      setState(() {
        _entriesFuture = widget.manager.loadEntries(
          contextId: widget.context?.id,
        );
      });
    };
    widget.manager.changes.addListener(_changesListener);
  }

  @override
  void didUpdateWidget(covariant TrashTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.context?.id != widget.context?.id) {
      _entriesFuture = widget.manager.loadEntries(
        contextId: widget.context?.id,
      );
    }
  }

  @override
  void dispose() {
    widget.manager.changes.removeListener(_changesListener);
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _entriesFuture = widget.manager.loadEntries(
        contextId: widget.context?.id,
      );
    });
    await _entriesFuture;
  }

  bool _unlockInProgress = false;
  final Map<String, Future<String?>> _pendingPassphrasePrompts = {};

  Future<T> _runShell<T>(Future<T> Function() action) async {
    if (widget.keyService == null) {
      return action();
    }
    try {
      return await _withBuiltinUnlock(action);
    } on SshUnlockCancelled {
      throw const CancelledTrashOperation();
    }
  }

  Future<T> _withBuiltinUnlock<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } on BuiltInSshKeyLockedException catch (error) {
        AppLogger.w(
          'Built-in key locked for ${error.hostName}',
          tag: 'Trash',
          error: error,
        );
        final unlocked = await _promptUnlock(error.keyId);
        if (!unlocked) {
          throw const SshUnlockCancelled();
        }
        continue;
      } on BuiltInSshKeyPassphraseRequired catch (error) {
        AppLogger.w(
          'Passphrase required for built-in key ${error.keyId}',
          tag: 'Trash',
          error: error,
        );
        final keyLabel = error.keyLabel ?? error.keyId;
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          'built-in key $keyLabel',
        );
        if (passphrase == null) {
          throw const SshUnlockCancelled();
        }
        final service = widget.shellService;
        if (service is BuiltInRemoteShellService) {
          service.setBuiltInKeyPassphrase(error.keyId, passphrase);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Passphrase stored for $keyLabel.')),
          );
        }
        continue;
      } on BuiltInSshKeyUnsupportedCipher catch (error) {
        AppLogger.w(
          'Unsupported cipher for built-in key ${error.keyId}',
          tag: 'Trash',
          error: error,
        );
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
        AppLogger.w(
          'Passphrase required for identity ${error.identityPath}',
          tag: 'Trash',
          error: error,
        );
        final passphrase = await _awaitPassphraseInput(
          error.hostName,
          error.identityPath,
        );
        if (passphrase == null) {
          throw const SshUnlockCancelled();
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
      } on BuiltInSshAuthenticationFailed catch (error) {
        AppLogger.w(
          'SSH authentication failed for ${error.hostName}',
          tag: 'Trash',
          error: error,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'SSH authentication failed for ${error.hostName}. '
                'Check your key configuration in settings.',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        rethrow;
      }
    }
  }

  Future<bool> _promptUnlock(String keyId) async {
    if (_unlockInProgress) {
      return false;
    }
    final service = widget.keyService;
    if (service == null) {
      return false;
    }
    _unlockInProgress = true;
    AppLogger.d('Prompting unlock for key $keyId', tag: 'Trash');
    try {
      final initial = await service.unlock(keyId, password: null);
      if (initial.status == BuiltInSshKeyUnlockStatus.unlocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key unlocked for this session.')),
          );
          AppLogger.d('Unlock succeeded for key $keyId', tag: 'Trash');
        }
        return true;
      }
      String? password;
      password = await _showUnlockDialog(keyId);
      if (password == null) {
        AppLogger.d('Unlock cancelled for key $keyId', tag: 'Trash');
        return false;
      }
      final result = await service.unlock(keyId, password: password);
      if (result.status == BuiltInSshKeyUnlockStatus.unlocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key unlocked for this session.')),
          );
          AppLogger.d('Unlock succeeded for key $keyId', tag: 'Trash');
        }
        return true;
      }
      final message = result.message ?? 'Incorrect password for that key.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      AppLogger.w('Unlock failed for key $keyId: $message', tag: 'Trash');
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
      }
      AppLogger.w('Unlock failed for key $keyId', tag: 'Trash', error: error);
      return false;
    } finally {
      _unlockInProgress = false;
      AppLogger.d('Unlock flow completed for key $keyId', tag: 'Trash');
    }
  }

  Future<String?> _showUnlockDialog(String keyId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(null),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
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
          ),
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
      AppLogger.d('Awaiting existing passphrase for $key', tag: 'Trash');
      return existing;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        AppLogger.d('Prompting passphrase for $key', tag: 'Trash');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        AppLogger.w(
          'Failed to prompt passphrase for $key',
          tag: 'Trash',
          error: error,
          stackTrace: stackTrace,
        );
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        AppLogger.d('Passphrase prompt completed for $key', tag: 'Trash');
      }
    }();
    return completer.future;
  }

  Future<String?> _promptPassphrase(String host, String path) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return DialogKeyboardShortcuts(
          onCancel: () => Navigator.of(context).pop(null),
          onConfirm: () => Navigator.of(context).pop(controller.text.trim()),
          child: AlertDialog(
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
          ),
        );
      },
    );
    controller.dispose();
    return result?.isNotEmpty == true ? result : null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trash', style: Theme.of(context).textTheme.headlineSmall),
        SizedBox(height: spacing.lg),
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
                  separatorBuilder: (_, _) => SizedBox(height: spacing.md),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final contextDetails = entry.contextLabel != entry.hostName
                        ? '${entry.contextLabel} · ${entry.hostName}'
                        : entry.hostName;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          entry.isDirectory
                              ? Icons.folder
                              : Icons.insert_drive_file,
                        ),
                        title: Text(entry.displayName),
                        subtitle: Text(
                          '$contextDetails · ${entry.remotePath}\n'
                          'Trashed ${entry.trashedAt.toLocal()} · ${_formatBytes(entry.sizeBytes)}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: spacing.md,
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
    AppLogger.d(
      'Trash restore requested for ${entry.remotePath} on host ${entry.host.name}',
      tag: 'Trash',
    );
    try {
      await _runShell(() async {
        final exists = await File(entry.localPath).exists();
        if (!exists) {
          throw Exception('Local trash payload missing at ${entry.localPath}');
        }
        return widget.manager.restoreEntry(
          entry: entry,
          shellService: widget.shellService,
          hostOverride: widget.context?.host,
        );
      });
      AppLogger.d(
        'Trash restore succeeded for ${entry.remotePath} on host ${entry.host.name}',
        tag: 'Trash',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${entry.displayName} to ${entry.remotePath}'),
        ),
      );
    } catch (error) {
      if (error is CancelledTrashOperation) return;
      AppLogger.w(
        'Trash restore failed for ${entry.remotePath} on host ${entry.host.name}',
        tag: 'Trash',
        error: error,
      );
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

class CancelledTrashOperation implements Exception {
  const CancelledTrashOperation();

  @override
  String toString() => 'CancelledTrashOperation';
}
