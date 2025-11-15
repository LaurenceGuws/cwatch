import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/remote_file_entry.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/remote_editor_cache.dart';
import 'merge_conflict_dialog.dart';
import 'remote_file_editor_dialog.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({
    super.key,
    required this.host,
    this.shellService = const RemoteShellService(),
  });

  final SshHost host;
  final RemoteShellService shellService;

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab> {
  final List<RemoteFileEntry> _entries = [];
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocus = FocusNode();
  final Set<String> _pathHistory = {'/'};
  final RemoteEditorCache _cache = RemoteEditorCache();
  final Map<String, _LocalFileSession> _localEdits = {};
  final Set<String> _syncingPaths = {};
  final Set<String> _refreshingPaths = {};
  TextEditingController? _pathFieldController;

  String _currentPath = '/';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPath(_currentPath);
  }

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 12),
          _buildBreadcrumbs(),
          const SizedBox(height: 12),
          _buildPathField(),
          const SizedBox(height: 16),
          _buildCommandBar(),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _buildEntriesList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Explorer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Host: ${widget.host.hostname}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Text(
          'ls $_currentPath',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs() {
    final segments = _currentPath.split('/').where((segment) => segment.isNotEmpty).toList();
    final chips = <Widget>[
      ActionChip(
        label: const Text('/'),
        onPressed: () => _loadPath('/'),
      ),
    ];

    var runningPath = '';
    for (final segment in segments) {
      runningPath += '/$segment';
      chips.add(const Icon(Icons.chevron_right, size: 16));
      chips.add(
        ActionChip(
          label: Text(segment),
          onPressed: () => _loadPath(runningPath),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildPathField() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text;
        if (query.isEmpty) {
          return _pathHistory;
        }
        return _pathHistory.where((path) => path.startsWith(query));
      },
      initialValue: TextEditingValue(text: _currentPath),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _pathFieldController = controller;
        controller.text = _currentPath;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Path',
            prefixIcon: Icon(Icons.folder),
          ),
          onSubmitted: (value) => _loadPath(value),
        );
      },
      onSelected: (value) => _loadPath(value),
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: min(360, MediaQuery.sizeOf(context).width * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (option) => ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommandBar() {
    return TextField(
      controller: _commandController,
      focusNode: _commandFocus,
      decoration: InputDecoration(
        labelText: 'Run command',
        prefixText: 'ssh ${widget.host.name}\$ ',
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          onPressed: _runAdHocCommand,
        ),
      ),
      onSubmitted: (_) => _runAdHocCommand(),
    );
  }

  Widget _buildEntriesList() {
    final sortedEntries = [..._entries]..sort((a, b) {
        if (a.isDirectory == b.isDirectory) {
          return a.name.compareTo(b.name);
        }
        return a.isDirectory ? -1 : 1;
      });

    if (sortedEntries.isEmpty) {
      return const Center(child: Text('Directory is empty.'));
    }

    return ListView.separated(
      itemCount: sortedEntries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final remotePath = _joinPath(_currentPath, entry.name);
        final session = _localEdits[remotePath];
        return InkWell(
          onTap: entry.isDirectory ? () => _loadPath(remotePath) : null,
          onSecondaryTapDown: (details) => _showEntryContextMenu(entry, details.globalPosition),
          child: ListTile(
            leading: Icon(entry.isDirectory ? Icons.folder : Icons.insert_drive_file),
            title: Text(entry.name),
            subtitle: Text(
              entry.isDirectory ? 'Directory' : '${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!entry.isDirectory && session != null) ...[
                  IconButton(
                    tooltip: 'Push local changes to server',
                    icon: _syncingPaths.contains(remotePath)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    onPressed:
                        _syncingPaths.contains(remotePath) ? null : () => _syncLocalEdit(session),
                  ),
                  IconButton(
                    tooltip: 'Refresh cache from server',
                    icon: _refreshingPaths.contains(remotePath)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    onPressed: _refreshingPaths.contains(remotePath)
                        ? null
                        : () => _refreshCacheFromServer(session),
                  ),
                  IconButton(
                    tooltip: 'Clear cached copy',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _clearCachedCopy(session),
                  ),
                ],
                Text(
                  entry.modified.toLocal().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final target = _normalizePath(path);
    try {
      final entries = await widget.shellService.listDirectory(widget.host, target);
      setState(() {
        _entries
          ..clear()
          ..addAll(entries);
        _currentPath = target;
        _pathFieldController?.text = _currentPath;
        _loading = false;
        _pathHistory.add(_currentPath);
        for (final entry in entries) {
          if (entry.isDirectory) {
            _pathHistory.add(_joinPath(_currentPath, entry.name));
          }
        }
      });
      unawaited(_hydrateCachedSessions(entries, target));
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _runAdHocCommand() {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      return;
    }
    final parts = command.split(' ');
    if (parts.first == 'cd' && parts.length > 1) {
      _loadPath(parts[1]);
    } else if (parts.first == 'ls') {
      _loadPath(parts.length > 1 ? parts[1] : _currentPath);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Executed: $command')),
    );
    _commandController.clear();
  }

  Future<void> _showEntryContextMenu(RemoteFileEntry entry, Offset position) async {
    final action = await showMenu<_ExplorerContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          value: _ExplorerContextAction.open,
          enabled: entry.isDirectory,
          child: const Text('Open'),
        ),
        PopupMenuItem(
          value: _ExplorerContextAction.copyPath,
          child: const Text('Copy path'),
        ),
        PopupMenuItem(
          value: _ExplorerContextAction.openLocally,
          enabled: !entry.isDirectory,
          child: const Text('Open locally'),
        ),
        PopupMenuItem(
          value: _ExplorerContextAction.editFile,
          enabled: !entry.isDirectory,
          child: const Text('Edit (text)'),
        ),
        PopupMenuItem(
          value: _ExplorerContextAction.tail,
          enabled: !entry.isDirectory,
          child: const Text('Tail (preview)'),
        ),
      ],
    );

    if (!mounted) {
      return;
    }

    switch (action) {
      case _ExplorerContextAction.open:
        _loadPath(_joinPath(_currentPath, entry.name));
      case _ExplorerContextAction.copyPath:
        final path = _joinPath(_currentPath, entry.name);
        await Clipboard.setData(ClipboardData(text: path));
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $path')));
        break;
      case _ExplorerContextAction.openLocally:
        await _openLocally(entry);
        break;
      case _ExplorerContextAction.editFile:
        await _openEditor(entry);
        break;
      case _ExplorerContextAction.tail:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tail preview not yet implemented for ${entry.name}.')),
        );
        break;
      case null:
        break;
    }
  }

  Future<void> _openEditor(RemoteFileEntry entry) async {
    final path = _joinPath(_currentPath, entry.name);
    try {
      final contents = await widget.shellService.readFile(widget.host, path);
      if (!mounted) {
        return;
      }
      final updated = await showDialog<String>(
        context: context,
        builder: (context) => RemoteFileEditorDialog(
          path: path,
          initialContent: contents,
        ),
      );
      if (updated != null && updated != contents) {
        await widget.shellService.writeFile(widget.host, path, updated);
        final localFile = await _cache.materialize(host: widget.host.name, remotePath: path, contents: updated);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $path · Cached at ${localFile.path}')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit file: $error')),
      );
    }
  }

  Future<void> _openLocally(RemoteFileEntry entry) async {
    final remotePath = _joinPath(_currentPath, entry.name);
    try {
      CachedEditorSession? session = await _cache.loadSession(
        host: widget.host.name,
        remotePath: remotePath,
      );
      if (session == null) {
        final contents = await widget.shellService.readFile(widget.host, remotePath);
        session = await _cache.createSession(
          host: widget.host.name,
          remotePath: remotePath,
          contents: contents,
        );
      }
      await _launchLocalApp(session.workingPath);
      setState(() {
        _localEdits[remotePath] = _LocalFileSession(
          localPath: session!.workingPath,
          snapshotPath: session.snapshotPath,
          remotePath: remotePath,
        );
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opened local copy: ${session.workingPath}. Edit then press Sync.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open locally: $error')),
      );
    }
  }

  Future<void> _syncLocalEdit(_LocalFileSession session) async {
    setState(() {
      _syncingPaths.add(session.remotePath);
    });
    try {
      final workingFile = File(session.localPath);
      final snapshotFile = File(session.snapshotPath);
      final localContents = await workingFile.readAsString();
      final baseContents = await snapshotFile.readAsString();
      final remoteContents = await widget.shellService.readFile(widget.host, session.remotePath);

      if (remoteContents == baseContents) {
        await widget.shellService.writeFile(widget.host, session.remotePath, localContents);
        await snapshotFile.writeAsString(localContents);
        session.lastSynced = DateTime.now();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synced ${session.remotePath} to remote host')),
        );
      } else if (localContents == baseContents) {
        await workingFile.writeAsString(remoteContents);
        await snapshotFile.writeAsString(remoteContents);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Remote changes pulled for ${session.remotePath}')), 
          );
        }
      } else {
        final merged = await _promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged != null) {
          await widget.shellService.writeFile(widget.host, session.remotePath, merged);
          await workingFile.writeAsString(merged);
          await snapshotFile.writeAsString(merged);
          session.lastSynced = DateTime.now();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Merged and synced ${session.remotePath}')),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingPaths.remove(session.remotePath);
        });
      }
    }
  }

  Future<void> _refreshCacheFromServer(_LocalFileSession session) async {
    setState(() {
      _refreshingPaths.add(session.remotePath);
    });
    try {
      final remoteContents = await widget.shellService.readFile(widget.host, session.remotePath);
      final workingFile = File(session.localPath);
      final localContents = await workingFile.readAsString();
      String? nextWorking;
      if (localContents == remoteContents) {
        nextWorking = remoteContents;
      } else {
        final merged = await _promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged == null) {
          await File(session.snapshotPath).writeAsString(remoteContents);
          return;
        }
        nextWorking = merged;
      }
      await workingFile.writeAsString(nextWorking);
      await File(session.snapshotPath).writeAsString(remoteContents);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cache refreshed for ${session.remotePath}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh cache: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshingPaths.remove(session.remotePath);
        });
      }
    }
  }

  Future<void> _clearCachedCopy(_LocalFileSession session) async {
    await _cache.clearSession(host: widget.host.name, remotePath: session.remotePath);
    if (!mounted) {
      return;
    }
    setState(() {
      _localEdits.remove(session.remotePath);
      _syncingPaths.remove(session.remotePath);
      _refreshingPaths.remove(session.remotePath);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleared cached copy for ${session.remotePath}')),
    );
  }

  Future<void> _launchLocalApp(String path) async {
    final preferred = await _resolveEditorCommand();
    if (preferred != null) {
      debugPrint('Launching preferred editor command: $preferred $path');
      await Process.start(preferred.first, [...preferred.sublist(1), path]);
      return;
    }

    if (Platform.isMacOS) {
      debugPrint('Launching open $path');
      await Process.start('open', [path]);
    } else if (Platform.isWindows) {
      debugPrint('Launching cmd /c start $path');
      await Process.start('cmd', ['/c', 'start', '', path]);
    } else {
      debugPrint('Launching xdg-open $path');
      await Process.start('xdg-open', [path]);
    }
  }

  Future<List<String>?> _resolveEditorCommand() async {
    final editor = Platform.environment['EDITOR']?.trim();
    if (editor == null || editor.isEmpty) {
      return null;
    }
    final parts = editor.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return null;
    }
    final executable = await _findExecutable(parts.first);
    if (executable == null) {
      debugPrint('EDITOR command not found: ${parts.first}');
      return null;
    }
    return [executable, ...parts.sublist(1)];
  }

  Future<String?> _findExecutable(String command) async {
    final exists = await File(command).exists();
    if (exists) {
      return command;
    }
    final whichCmd = Platform.isWindows ? 'where' : 'which';
    final result = await Process.run(whichCmd, [command]);
    if (result.exitCode != 0) {
      debugPrint('$whichCmd $command failed: ${result.stderr}');
      return null;
    }
    final output = (result.stdout as String?) ?? '';
    return output.split(RegExp(r'\r?\n')).firstWhere(
      (line) => line.trim().isNotEmpty,
      orElse: () => command,
    );
  }

  String _joinPath(String base, String name) {
    if (base == '/' || base.isEmpty) {
      return '/$name';
    }
    return '$base/$name';
  }

  String _joinWithBase(String base, String name) {
    if (base == '/' || base.isEmpty) {
      return '/$name';
    }
    return '$base/$name';
  }

  Future<void> _hydrateCachedSessions(List<RemoteFileEntry> entries, String basePath) async {
    final updates = <String, _LocalFileSession>{};
    for (final entry in entries) {
      if (entry.isDirectory) {
        continue;
      }
      final remotePath = _joinWithBase(basePath, entry.name);
      if (_localEdits.containsKey(remotePath)) {
        continue;
      }
      final session = await _cache.loadSession(
        host: widget.host.name,
        remotePath: remotePath,
      );
      if (session != null) {
        updates[remotePath] = _LocalFileSession(
          localPath: session.workingPath,
          snapshotPath: session.snapshotPath,
          remotePath: remotePath,
        );
      }
    }
    if (updates.isNotEmpty && mounted) {
      setState(() {
        _localEdits.addAll(updates);
      });
    }
  }

  String _normalizePath(String input) {
    if (input.trim().isEmpty) {
      return _currentPath;
    }
    var path = input.trim();
    if (!path.startsWith('/')) {
      path = _joinPath(_currentPath, path);
    }
    final segments = path.split('/');
    final stack = <String>[];
    for (final segment in segments) {
      if (segment.isEmpty || segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        }
      } else {
        stack.add(segment);
      }
    }
    return '/${stack.join('/')}';
  }

  Future<String?> _promptMergeDialog({
    required String remotePath,
    required String local,
    required String remote,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => MergeConflictDialog(
        remotePath: remotePath,
        local: local,
        remote: remote,
      ),
    );
  }

}

enum _ExplorerContextAction { open, copyPath, openLocally, editFile, tail }

class _LocalFileSession {
  _LocalFileSession({
    required this.localPath,
    required this.snapshotPath,
    required this.remotePath,
  });

  final String localPath;
  final String snapshotPath;
  final String remotePath;
  DateTime? lastSynced;
}
