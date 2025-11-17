import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/remote_file_entry.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/remote_editor_cache.dart';
import '../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';
import 'file_icon_resolver.dart';
import 'merge_conflict_dialog.dart';
import 'remote_file_editor_dialog.dart';
import 'explorer_clipboard.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({
    super.key,
    required this.host,
    this.shellService = const RemoteShellService(),
    required this.trashManager,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final ExplorerTrashManager trashManager;

  @override
  State<FileExplorerTab> createState() => _FileExplorerTabState();
}

class _FileExplorerTabState extends State<FileExplorerTab> {
  static const _shortcutCopy = 'Ctrl+C';
  static const _shortcutCut = 'Ctrl+X';
  static const _shortcutPaste = 'Ctrl+V';
  static const _shortcutRename = 'F2';
  static const _shortcutDelete = 'Delete';

  final List<RemoteFileEntry> _entries = [];
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocus = FocusNode();
  final FocusNode _listFocusNode = FocusNode(debugLabel: 'file-explorer-list');
  final RemoteEditorCache _cache = RemoteEditorCache();
  final Map<String, _LocalFileSession> _localEdits = {};
  final Set<String> _syncingPaths = {};
  final Set<String> _refreshingPaths = {};
  Set<String> _pathHistory = {'/'};
  TextEditingController? _pathFieldController;
  final Set<String> _selectedPaths = {};
  int? _selectionAnchorIndex;
  int? _lastSelectedIndex;
  bool _dragSelecting = false;
  bool _dragSelectionAdditive = true;
  late final VoidCallback _clipboardListener;
  late final VoidCallback _cutEventListener;
  late final VoidCallback _trashRestoreListener;

  String _currentPath = '/';
  bool _loading = true;
  String? _error;
  bool _showBreadcrumbs = true;

  @override
  void initState() {
    super.initState();
    _initializeExplorer();
    _clipboardListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    ExplorerClipboard.listenable.addListener(_clipboardListener);
    _cutEventListener = () {
      final event = ExplorerClipboard.cutEvents.value;
      if (event == null || !mounted) {
        return;
      }
      if (event.hostName != widget.host.name) {
        return;
      }
      final parent = _parentDirectory(event.remotePath);
      if (parent == _currentPath) {
        unawaited(_loadPath(_currentPath));
      }
    };
    ExplorerClipboard.cutEvents.addListener(_cutEventListener);
    _trashRestoreListener = () {
      final event = widget.trashManager.restoreEvents.value;
      if (event == null || !mounted) {
        return;
      }
      if (event.hostName != widget.host.name) {
        return;
      }
      if (event.directory == _currentPath) {
        unawaited(_loadPath(_currentPath));
      }
    };
    widget.trashManager.restoreEvents.addListener(_trashRestoreListener);
  }

  Future<void> _initializeExplorer() async {
    final home = await widget.shellService.homeDirectory(widget.host);
    if (!mounted) {
      return;
    }
    _currentPath = home.isNotEmpty ? home : '/';
    _pathHistory = {_currentPath};
    await _loadPath(_currentPath);
  }

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocus.dispose();
    _listFocusNode.dispose();
    ExplorerClipboard.listenable.removeListener(_clipboardListener);
    ExplorerClipboard.cutEvents.removeListener(_cutEventListener);
    widget.trashManager.restoreEvents.removeListener(_trashRestoreListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPathNavigator(context),
        const SizedBox(height: 12),
        _buildCommandBar(),
        const SizedBox(height: 12),
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
    );
  }

  Widget _buildPathNavigator(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _showBreadcrumbs ? 'Breadcrumbs' : 'Path input',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            ToggleButtons(
              isSelected: [_showBreadcrumbs, !_showBreadcrumbs],
              onPressed: (index) {
                setState(() => _showBreadcrumbs = index == 0);
              },
              borderRadius: BorderRadius.circular(10),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
              children: const [
                Icon(Icons.alt_route, size: 16),
                Icon(Icons.text_fields, size: 16),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showBreadcrumbs) _buildBreadcrumbs() else _buildPathField(),
      ],
    );
  }

  Widget _buildBreadcrumbs() {
    final segments = _currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final chips = <Widget>[
      ActionChip(label: const Text('/'), onPressed: () => _loadPath('/')),
    ];

    var runningPath = '';
    for (final segment in segments) {
      runningPath += '/$segment';
      chips.add(Icon(NerdIcon.arrowRight.data, size: 16));
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
          decoration: InputDecoration(
            labelText: 'Path',
            prefixIcon: Icon(NerdIcon.folder.data),
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
          icon: Icon(NerdIcon.terminal.data),
          onPressed: _runAdHocCommand,
        ),
      ),
      onSubmitted: (_) => _runAdHocCommand(),
    );
  }

  Widget _buildEntriesList() {
    final sortedEntries = _currentSortedEntries();

    if (sortedEntries.isEmpty) {
      return const Center(child: Text('Directory is empty.'));
    }

    final dividerColor = context.appTheme.section.divider;
    return Focus(
      focusNode: _listFocusNode,
      onKeyEvent: (node, event) =>
          _handleListKeyEvent(node, event, sortedEntries),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapDown: (details) =>
            _showBackgroundContextMenu(details.globalPosition),
        child: Listener(
          onPointerDown: (_) => _listFocusNode.requestFocus(),
          onPointerUp: (_) => _stopDragSelection(),
          onPointerCancel: (_) => _stopDragSelection(),
          child: ListView.separated(
          itemCount: sortedEntries.length,
          separatorBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Divider(height: 1, thickness: 1, color: dividerColor),
          ),
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];
            final remotePath = _joinPath(_currentPath, entry.name);
            final session = _localEdits[remotePath];
            final selected = _selectedPaths.contains(remotePath);
            final colorScheme = Theme.of(context).colorScheme;
            final highlightColor = selected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent;
            final titleStyle = selected
                ? Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.primary)
                : null;
            return MouseRegion(
              onEnter: (event) => _handleDragHover(event, index, remotePath),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _handleEntryPointerDown(
                  event,
                  sortedEntries,
                  index,
                  remotePath,
                ),
                onPointerUp: (_) => _stopDragSelection(),
                onPointerCancel: (_) => _stopDragSelection(),
                child: InkWell(
                  onDoubleTap: () => _handleEntryDoubleTap(entry),
                  onSecondaryTapDown: (details) =>
                      _showEntryContextMenu(entry, details.globalPosition),
                  splashFactory: NoSplash.splashFactory,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 110),
                    curve: Curves.easeOutCubic,
                    color: highlightColor,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      leading: Icon(
                        FileIconResolver.iconFor(entry),
                        color: selected ? colorScheme.primary : null,
                      ),
                      title: Text(entry.name, style: titleStyle),
                      subtitle: Text(
                        entry.isDirectory
                            ? 'Directory'
                            : '${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(NerdIcon.cloudUpload.data),
                              onPressed: _syncingPaths.contains(remotePath)
                                  ? null
                                  : () => _syncLocalEdit(session),
                            ),
                            IconButton(
                              tooltip: 'Refresh cache from server',
                              icon: _refreshingPaths.contains(remotePath)
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(NerdIcon.refresh.data),
                              onPressed: _refreshingPaths.contains(remotePath)
                                  ? null
                                  : () => _refreshCacheFromServer(session),
                            ),
                            IconButton(
                              tooltip: 'Clear cached copy',
                              icon: Icon(NerdIcon.delete.data),
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
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final target = _normalizePath(path);
    try {
      final entries = await widget.shellService.listDirectory(
        widget.host,
        target,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries
          ..clear()
          ..addAll(entries);
        _currentPath = target;
        _pathFieldController?.text = _currentPath;
        _loading = false;
        _pathHistory.add(_currentPath);
        _selectedPaths.clear();
        _selectionAnchorIndex = null;
        _lastSelectedIndex = null;
        for (final entry in entries) {
          if (entry.isDirectory) {
            _pathHistory.add(_joinPath(_currentPath, entry.name));
          }
        }
      });
      unawaited(_hydrateCachedSessions(entries, target));
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Executed: $command')));
    _commandController.clear();
  }

  Future<void> _showEntryContextMenu(
    RemoteFileEntry entry,
    Offset position,
  ) async {
    final menuItems = <PopupMenuEntry<_ExplorerContextAction>>[];
    final clipboardAvailable = ExplorerClipboard.entry != null;
    if (entry.isDirectory) {
      menuItems.add(
        const PopupMenuItem(
          value: _ExplorerContextAction.open,
          child: Text('Open'),
        ),
      );
    } else {
      menuItems.addAll([
        const PopupMenuItem(
          value: _ExplorerContextAction.openLocally,
          child: Text('Open locally'),
        ),
        const PopupMenuItem(
          value: _ExplorerContextAction.editFile,
          child: Text('Edit (text)'),
        ),
      ]);
    }
    menuItems.add(
      const PopupMenuItem(
        value: _ExplorerContextAction.copyPath,
        child: Text('Copy path'),
      ),
    );
    menuItems.addAll([
      PopupMenuItem(
        value: _ExplorerContextAction.rename,
        child: Text('Rename ($_shortcutRename)'),
      ),
      const PopupMenuItem(
        value: _ExplorerContextAction.move,
        child: Text('Move to...'),
      ),
      PopupMenuItem(
        value: _ExplorerContextAction.copy,
        child: Text('Copy ($_shortcutCopy)'),
      ),
      PopupMenuItem(
        value: _ExplorerContextAction.cut,
        child: Text('Cut ($_shortcutCut)'),
      ),
      PopupMenuItem(
        value: _ExplorerContextAction.paste,
        enabled: clipboardAvailable,
        child: Text('Paste ($_shortcutPaste)'),
      ),
    ]);
    if (entry.isDirectory) {
      menuItems.add(
        PopupMenuItem(
          value: _ExplorerContextAction.pasteInto,
          enabled: clipboardAvailable,
          child: Text('Paste into "${entry.name}" ($_shortcutPaste)'),
        ),
      );
    }
    menuItems.add(
      PopupMenuItem(
        value: _ExplorerContextAction.delete,
        child: Text('Delete ($_shortcutDelete)'),
      ),
    );

    final action = await showMenu<_ExplorerContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: menuItems,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Copied $path')));
        break;
      case _ExplorerContextAction.openLocally:
        await _openLocally(entry);
        break;
      case _ExplorerContextAction.editFile:
        await _openEditor(entry);
        break;
      case _ExplorerContextAction.rename:
        await _promptRename(entry);
        break;
      case _ExplorerContextAction.copy:
        _handleClipboardSet(entry, ExplorerClipboardOperation.copy);
        break;
      case _ExplorerContextAction.cut:
        _handleClipboardSet(entry, ExplorerClipboardOperation.cut);
        break;
      case _ExplorerContextAction.paste:
        await _handlePaste(targetDirectory: _currentPath);
        break;
      case _ExplorerContextAction.pasteInto:
        await _handlePaste(
          targetDirectory: _joinPath(_currentPath, entry.name),
        );
        break;
      case _ExplorerContextAction.move:
        await _promptMove(entry);
        break;
      case _ExplorerContextAction.delete:
        await _confirmDelete(entry, permanent: _isShiftPressed());
        break;
      case null:
        break;
    }
  }

  Future<void> _showBackgroundContextMenu(Offset position) async {
    final clipboardAvailable = ExplorerClipboard.entry != null;
    if (!clipboardAvailable) {
      return;
    }
    final action = await showMenu<_ExplorerContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _ExplorerContextAction.paste,
          enabled: clipboardAvailable,
          child: Text('Paste ($_shortcutPaste)'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (action == _ExplorerContextAction.paste) {
      await _handlePaste(targetDirectory: _currentPath);
    }
  }

  void _handleEntryDoubleTap(RemoteFileEntry entry) {
    final targetPath = _joinPath(_currentPath, entry.name);
    if (entry.isDirectory) {
      _loadPath(targetPath);
    } else {
      unawaited(_openLocally(entry));
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
        builder: (context) =>
            RemoteFileEditorDialog(path: path, initialContent: contents),
      );
      if (updated != null && updated != contents) {
        await widget.shellService.writeFile(widget.host, path, updated);
        final localFile = await _cache.materialize(
          host: widget.host.name,
          remotePath: path,
          contents: updated,
        );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit file: $error')));
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
        final contents = await widget.shellService.readFile(
          widget.host,
          remotePath,
        );
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
        SnackBar(
          content: Text(
            'Opened local copy: ${session.workingPath}. Edit then press Sync.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open locally: $error')));
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
      final remoteContents = await widget.shellService.readFile(
        widget.host,
        session.remotePath,
      );

      if (remoteContents == baseContents) {
        await widget.shellService.writeFile(
          widget.host,
          session.remotePath,
          localContents,
        );
        await snapshotFile.writeAsString(localContents);
        session.lastSynced = DateTime.now();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${session.remotePath} to remote host'),
          ),
        );
      } else if (localContents == baseContents) {
        await workingFile.writeAsString(remoteContents);
        await snapshotFile.writeAsString(remoteContents);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Remote changes pulled for ${session.remotePath}'),
            ),
          );
        }
      } else {
        final merged = await _promptMergeDialog(
          remotePath: session.remotePath,
          local: localContents,
          remote: remoteContents,
        );
        if (merged != null) {
          await widget.shellService.writeFile(
            widget.host,
            session.remotePath,
            merged,
          );
          await workingFile.writeAsString(merged);
          await snapshotFile.writeAsString(merged);
          session.lastSynced = DateTime.now();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Merged and synced ${session.remotePath}'),
              ),
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sync: $error')));
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
      final remoteContents = await widget.shellService.readFile(
        widget.host,
        session.remotePath,
      );
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
    await _cache.clearSession(
      host: widget.host.name,
      remotePath: session.remotePath,
    );
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

  void _handleClipboardSet(
    RemoteFileEntry entry,
    ExplorerClipboardOperation operation,
  ) {
    final remotePath = _joinPath(_currentPath, entry.name);
    ExplorerClipboard.setEntry(
      ExplorerClipboardEntry(
        host: widget.host,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: operation,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          operation == ExplorerClipboardOperation.copy
              ? 'Copied ${entry.name}'
              : 'Cut ${entry.name}',
        ),
      ),
    );
  }

  Future<void> _promptRename(RemoteFileEntry entry) async {
    final controller = TextEditingController(text: entry.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null) {
      return;
    }
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == entry.name) {
      return;
    }
    final sourcePath = _joinPath(_currentPath, entry.name);
    final destinationPath = _joinPath(_currentPath, trimmed);
    try {
      await widget.shellService.movePath(
        widget.host,
        sourcePath,
        destinationPath,
      );
      await _loadPath(_currentPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed ${entry.name} to $trimmed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $error')),
      );
    }
  }

  Future<void> _promptMove(RemoteFileEntry entry) async {
    final controller =
        TextEditingController(text: _joinPath(_currentPath, entry.name));
    final target = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move entry'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Destination path',
            helperText: 'Provide absolute path to new location',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (target == null || target.trim().isEmpty) {
      return;
    }
    final normalized = _normalizePath(target);
    if (normalized == _joinPath(_currentPath, entry.name)) {
      return;
    }
    try {
      await widget.shellService.movePath(
        widget.host,
        _joinPath(_currentPath, entry.name),
        normalized,
      );
      await _loadPath(_currentPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${entry.name} to $normalized')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move: $error')),
      );
    }
  }

  Future<void> _confirmDelete(
    RemoteFileEntry entry, {
    bool permanent = false,
  }) async {
    final deletePermanently = permanent || _isShiftPressed();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          deletePermanently
              ? 'Delete ${entry.name} permanently?'
              : 'Move ${entry.name} to trash?',
        ),
        content: Text(
          deletePermanently
              ? 'This will permanently delete ${entry.name} from ${widget.host.name}.'
              : 'A backup will be stored locally so you can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(deletePermanently ? 'Delete' : 'Move to trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (deletePermanently) {
      await _deletePermanently(entry);
    } else {
      await _moveEntryToTrash(entry);
    }
  }

  Future<void> _deletePermanently(RemoteFileEntry entry) async {
    final path = _joinPath(_currentPath, entry.name);
    try {
      await widget.shellService.deletePath(widget.host, path);
      await _loadPath(_currentPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${entry.name} permanently')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $error')),
      );
    }
  }

  Future<void> _moveEntryToTrash(RemoteFileEntry entry) async {
    final path = _joinPath(_currentPath, entry.name);
    TrashedEntry? recorded;
    try {
      recorded = await widget.trashManager.moveToTrash(
        shellService: widget.shellService,
        host: widget.host,
        remotePath: path,
        isDirectory: entry.isDirectory,
        notify: false,
      );
      await widget.shellService.deletePath(widget.host, path);
      widget.trashManager.notifyListeners();
      await _loadPath(_currentPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${entry.name} to trash')),
      );
    } catch (error) {
      if (recorded != null) {
        await widget.trashManager.deleteEntry(recorded, notify: false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move to trash: $error')),
      );
    }
  }

  Future<void> _handlePaste({required String targetDirectory}) async {
    final clipboard = ExplorerClipboard.entry;
    if (clipboard == null) {
      return;
    }
    final destinationDir = _normalizePath(targetDirectory);
    final destinationPath =
        _joinPath(destinationDir, clipboard.displayName);
    final refreshCurrent = destinationDir == _currentPath;
    if (clipboard.host.name == widget.host.name &&
        clipboard.remotePath == destinationPath) {
      return;
    }
    try {
      if (clipboard.host.name == widget.host.name) {
        if (clipboard.operation == ExplorerClipboardOperation.copy) {
          await widget.shellService.copyPath(
            widget.host,
            clipboard.remotePath,
            destinationPath,
            recursive: clipboard.isDirectory,
          );
        } else {
          await widget.shellService.movePath(
            widget.host,
            clipboard.remotePath,
            destinationPath,
          );
          ExplorerClipboard.notifyCutCompleted(clipboard);
        }
      } else {
        await widget.shellService.copyBetweenHosts(
          sourceHost: clipboard.host,
          sourcePath: clipboard.remotePath,
          destinationHost: widget.host,
          destinationPath: destinationPath,
          recursive: clipboard.isDirectory,
        );
        if (clipboard.operation == ExplorerClipboardOperation.cut) {
          await widget.shellService.deletePath(
            clipboard.host,
            clipboard.remotePath,
          );
          ExplorerClipboard.notifyCutCompleted(clipboard);
        }
      }
      if (refreshCurrent) {
        await _loadPath(_currentPath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clipboard.operation == ExplorerClipboardOperation.copy
                ? 'Pasted ${clipboard.displayName}'
                : 'Moved ${clipboard.displayName}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paste failed: $error')),
      );
    }
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
    final parts = editor
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
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
    return output
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => command);
  }

  String _joinPath(String base, String name) {
    if (base == '/' || base.isEmpty) {
      return '/$name';
    }
    return '$base/$name';
  }

  String _parentDirectory(String path) {
    final normalized = _normalizePath(path);
    if (normalized == '/' || !normalized.contains('/')) {
      return '/';
    }
    final index = normalized.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return normalized.substring(0, index);
  }

  String _joinWithBase(String base, String name) {
    if (base == '/' || base.isEmpty) {
      return '/$name';
    }
    return '$base/$name';
  }

  Future<void> _hydrateCachedSessions(
    List<RemoteFileEntry> entries,
    String basePath,
  ) async {
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

  List<RemoteFileEntry> _currentSortedEntries() {
    final sorted = [..._entries];
    sorted.sort((a, b) {
      if (a.isDirectory == b.isDirectory) {
        return a.name.compareTo(b.name);
      }
      return a.isDirectory ? -1 : 1;
    });
    return sorted;
  }

  void _handleEntryPointerDown(
    PointerDownEvent event,
    List<RemoteFileEntry> entries,
    int index,
    String remotePath,
  ) {
    _listFocusNode.requestFocus();
    final shift = _isShiftPressed();
    final multi = _isMultiSelectModifierPressed();
    final isMouse = event.kind == PointerDeviceKind.mouse;
    final isSecondaryClick =
        isMouse && (event.buttons & kSecondaryMouseButton) != 0;

    if (isSecondaryClick) {
      if (!_selectedPaths.contains(remotePath)) {
        _applySelection(entries, index, shift: false, multi: false);
      }
      _dragSelecting = false;
      return;
    }

    _applySelection(entries, index, shift: shift, multi: multi);

    if (isMouse && (event.buttons & kPrimaryMouseButton) != 0) {
      _dragSelecting = true;
      _dragSelectionAdditive = true;
    } else {
      _dragSelecting = false;
    }
  }

  void _handleDragHover(
    PointerEnterEvent event,
    int index,
    String remotePath,
  ) {
    if (!_dragSelecting || event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    setState(() {
      if (_dragSelectionAdditive) {
        _selectedPaths.add(remotePath);
      } else {
        _selectedPaths.remove(remotePath);
      }
      _lastSelectedIndex = index;
    });
  }

  void _stopDragSelection() {
    _dragSelecting = false;
  }

  KeyEventResult _handleListKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<RemoteFileEntry> entries,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (entries.isEmpty) {
      return KeyEventResult.handled;
    }

    final hardware = HardwareKeyboard.instance;
    final shift = hardware.isShiftPressed;
    final control = hardware.isControlPressed;
    final meta = hardware.isMetaPressed;
    final multi = control || meta;
    final isCtrl = control || meta;
    if (isCtrl) {
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        final entry = _primarySelectedEntry(entries);
        if (entry != null) {
          _handleClipboardSet(entry, ExplorerClipboardOperation.copy);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        final entry = _primarySelectedEntry(entries);
        if (entry != null) {
          _handleClipboardSet(entry, ExplorerClipboardOperation.cut);
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        unawaited(_handlePaste(targetDirectory: _currentPath));
        return KeyEventResult.handled;
      }
    }
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.delete) {
      final entry = _primarySelectedEntry(entries);
      if (entry != null) {
        unawaited(
          _confirmDelete(entry, permanent: shift),
        );
      }
      return KeyEventResult.handled;
    }
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.f2) {
      final entry = _primarySelectedEntry(entries);
      if (entry != null) {
        unawaited(_promptRename(entry));
      }
      return KeyEventResult.handled;
    }
    final currentIndex = _resolveFocusedIndex(entries);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        final next = (currentIndex + 1).clamp(0, entries.length - 1);
        if (next == currentIndex) {
          return KeyEventResult.handled;
        }
        _handleKeyboardNavigation(entries, next, shift: shift, multi: multi);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final next = (currentIndex - 1).clamp(0, entries.length - 1);
        if (next == currentIndex) {
          return KeyEventResult.handled;
        }
        _handleKeyboardNavigation(entries, next, shift: shift, multi: multi);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _handleKeyboardNavigation(entries, 0, shift: shift, multi: multi);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _handleKeyboardNavigation(
          entries,
          entries.length - 1,
          shift: shift,
          multi: multi,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        if (shift) {
          _selectRange(entries, currentIndex, additive: true);
        } else {
          _toggleSelection(entries, currentIndex);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyA:
        if (multi) {
          _selectAll(entries);
          return KeyEventResult.handled;
        }
        break;
      default:
        break;
    }
    return KeyEventResult.ignored;
  }

  void _handleKeyboardNavigation(
    List<RemoteFileEntry> entries,
    int targetIndex, {
    required bool shift,
    required bool multi,
  }) {
    if (entries.isEmpty) {
      return;
    }
    if (shift) {
      _selectRange(entries, targetIndex, additive: multi);
      return;
    }
    if (multi) {
      setState(() {
        _lastSelectedIndex = targetIndex;
        _selectionAnchorIndex = targetIndex;
      });
      return;
    }
    _selectExclusive(entries, targetIndex);
  }

  void _applySelection(
    List<RemoteFileEntry> entries,
    int index, {
    required bool shift,
    required bool multi,
  }) {
    if (entries.isEmpty || index < 0 || index >= entries.length) {
      return;
    }
    if (shift) {
      _selectRange(entries, index, additive: multi);
      return;
    }
    if (multi) {
      _toggleSelection(entries, index);
      return;
    }
    _selectExclusive(entries, index);
  }

  void _selectExclusive(List<RemoteFileEntry> entries, int index) {
    final path = _joinPath(_currentPath, entries[index].name);
    setState(() {
      _selectedPaths
        ..clear()
        ..add(path);
      _selectionAnchorIndex = index;
      _lastSelectedIndex = index;
    });
  }

  void _selectRange(
    List<RemoteFileEntry> entries,
    int index, {
    required bool additive,
  }) {
    if (entries.isEmpty) {
      return;
    }
    final anchor = _resolveAnchorIndex(entries, index);
    final start = min(anchor, index);
    final end = max(anchor, index);
    final nextSelection = additive ? {..._selectedPaths} : <String>{};
    for (var i = start; i <= end; i += 1) {
      nextSelection.add(_joinPath(_currentPath, entries[i].name));
    }
    setState(() {
      _selectedPaths
        ..clear()
        ..addAll(nextSelection);
      _lastSelectedIndex = index;
    });
  }

  void _toggleSelection(List<RemoteFileEntry> entries, int index) {
    final path = _joinPath(_currentPath, entries[index].name);
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
      _selectionAnchorIndex = index;
      _lastSelectedIndex = index;
    });
  }

  void _selectAll(List<RemoteFileEntry> entries) {
    setState(() {
      _selectedPaths
        ..clear()
        ..addAll(entries.map((entry) => _joinPath(_currentPath, entry.name)));
      _selectionAnchorIndex = entries.isEmpty ? null : 0;
      _lastSelectedIndex = entries.isEmpty ? null : entries.length - 1;
    });
  }

  RemoteFileEntry? _primarySelectedEntry(List<RemoteFileEntry> entries) {
    if (_selectedPaths.isEmpty) {
      return null;
    }
    return _entryForRemotePath(entries, _selectedPaths.first);
  }

  RemoteFileEntry? _entryForRemotePath(
    List<RemoteFileEntry> entries,
    String remotePath,
  ) {
    for (final entry in entries) {
      if (_joinPath(_currentPath, entry.name) == remotePath) {
        return entry;
      }
    }
    return null;
  }

  int _resolveAnchorIndex(List<RemoteFileEntry> entries, int fallback) {
    final anchor = _selectionAnchorIndex ?? _lastSelectedIndex ?? fallback;
    if (entries.isEmpty) {
      return 0;
    }
    return anchor.clamp(0, entries.length - 1);
  }

  int _resolveFocusedIndex(List<RemoteFileEntry> entries) {
    final last = _lastSelectedIndex;
    if (last != null && last >= 0 && last < entries.length) {
      return last;
    }
    for (var i = 0; i < entries.length; i += 1) {
      final path = _joinPath(_currentPath, entries[i].name);
      if (_selectedPaths.contains(path)) {
        return i;
      }
    }
    return 0;
  }

  bool _isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  bool _isMultiSelectModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
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

enum _ExplorerContextAction {
  open,
  copyPath,
  openLocally,
  editFile,
  rename,
  copy,
  cut,
  paste,
  pasteInto,
  delete,
  move,
}

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
