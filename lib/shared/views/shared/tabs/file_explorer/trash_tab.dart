import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/controllers/trash_tab_controller.dart';
import '../../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../../services/logging/app_logger.dart';
import '../../../../../shared/theme/app_theme.dart';

class TrashTab extends StatefulWidget {
  const TrashTab({super.key, required this.controller});

  final TrashTabController controller;

  @override
  State<TrashTab> createState() => _TrashTabState();
}

class _TrashTabState extends State<TrashTab> {
  late TrashTabController _controller;
  late Future<List<TrashedEntry>> _entriesFuture;
  late final VoidCallback _changesListener;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _entriesFuture = _controller.manager.loadEntries(
      contextId: _controller.context?.id,
    );
    _changesListener = () {
      if (!mounted) return;
      setState(() {
        _entriesFuture = _controller.manager.loadEntries(
          contextId: _controller.context?.id,
        );
      });
    };
    _controller.manager.changes.addListener(_changesListener);
  }

  @override
  void didUpdateWidget(covariant TrashTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.context?.id != widget.controller.context?.id) {
      _entriesFuture = _controller.manager.loadEntries(
        contextId: widget.controller.context?.id,
      );
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.manager.changes.removeListener(_changesListener);
      _controller = widget.controller;
      _controller.manager.changes.addListener(_changesListener);
    }
  }

  @override
  void dispose() {
    _controller.manager.changes.removeListener(_changesListener);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _entriesFuture = _controller.manager.loadEntries(
        contextId: _controller.context?.id,
      );
    });
    await _entriesFuture;
  }

  Future<T> _runShell<T>(Future<T> Function() action) async {
    try {
      return await _controller.runShell(action);
    } on SshUnlockCancelled {
      throw const CancelledTrashOperation();
    }
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
    await _controller.manager.deleteEntry(entry);
    if (!mounted) return;
    _controller.uiAdapter.showSnackBar(
      'Deleted ${entry.displayName} permanently',
    );
  }

  Future<void> _restoreEntry(TrashedEntry entry) async {
    AppLogger().debug(
      'Trash restore requested for ${entry.remotePath} on host ${entry.host.name}',
      tag: 'Trash',
    );
    try {
      await _runShell(() async {
        final exists = await File(entry.localPath).exists();
        if (!exists) {
          throw Exception('Local trash payload missing at ${entry.localPath}');
        }
        return _controller.manager.restoreEntry(
          entry: entry,
          shellService: _controller.shellService,
          hostOverride: _controller.context?.host,
        );
      });
      AppLogger().debug(
        'Trash restore succeeded for ${entry.remotePath} on host ${entry.host.name}',
        tag: 'Trash',
      );
      if (!mounted) return;
      _controller.uiAdapter.showSnackBar(
        'Restored ${entry.displayName} to ${entry.remotePath}',
      );
    } catch (error) {
      if (error is CancelledTrashOperation) return;
      AppLogger().warn(
        'Trash restore failed for ${entry.remotePath} on host ${entry.host.name}',
        tag: 'Trash',
        error: error,
      );
      if (!mounted) return;
      _controller.uiAdapter.showSnackBar('Restore failed: $error');
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
