import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../../services/ssh/remote_shell_service.dart';

class TrashTab extends StatefulWidget {
  const TrashTab({
    super.key,
    required this.manager,
    this.shellService = const RemoteShellService(),
  });

  final ExplorerTrashManager manager;
  final RemoteShellService shellService;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trash',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
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
                entries.sort(
                  (a, b) => b.trashedAt.compareTo(a.trashedAt),
                );
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      await widget.manager.restoreEntry(
        entry: entry,
        shellService: widget.shellService,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${entry.displayName} to ${entry.remotePath}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $error')),
      );
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
