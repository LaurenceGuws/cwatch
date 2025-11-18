import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../../models/remote_file_entry.dart';
import '../../../../models/ssh_host.dart';
import '../../../../services/ssh/builtin/builtin_ssh_key_store.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_remote_shell_service.dart';
import '../../../../services/ssh/builtin/builtin_ssh_vault.dart';
import '../../../../services/ssh/remote_editor_cache.dart';
import '../../../../services/filesystem/explorer_trash_manager.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/nerd_fonts.dart';
import 'explorer_clipboard.dart';
import 'file_icon_resolver.dart';
import 'merge_conflict_dialog.dart';
import 'remote_file_editor_dialog.dart';
import '../../../widgets/file_operation_progress_dialog.dart';

class FileExplorerTab extends StatefulWidget {
  const FileExplorerTab({
    super.key,
    required this.host,
    this.shellService = const ProcessRemoteShellService(),
    required this.trashManager,
    this.builtInVault,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final ExplorerTrashManager trashManager;
  final BuiltInSshVault? builtInVault;

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
  final ScrollController _scrollController = ScrollController();
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
  bool _unlockInProgress = false;
  final Map<String, Future<String?>> _pendingPassphrasePrompts = {};
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
        unawaited(_refreshCurrentPath());
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
        unawaited(_refreshCurrentPath());
      }
    };
    widget.trashManager.restoreEvents.addListener(_trashRestoreListener);
  }

  Future<void> _initializeExplorer() async {
    final home = await _runShell(
      () => widget.shellService.homeDirectory(widget.host),
    );
    if (!mounted) {
      return;
    }
    final initialPath = home.isNotEmpty ? home : '/';
    _pathHistory = {initialPath};
    await _loadPath(initialPath);
  }

  @override
  void dispose() {
    _commandController.dispose();
    _commandFocus.dispose();
    _listFocusNode.dispose();
    _scrollController.dispose();
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
      ActionChip(
        label: const Text('/'),
        onPressed: () {
          if (_currentPath != '/') {
            _loadPath('/');
          }
        },
      ),
    ];

    var runningPath = '';
    for (final segment in segments) {
      runningPath += '/$segment';
      final normalizedRunningPath = _normalizePath(runningPath);
      chips.add(Icon(NerdIcon.arrowRight.data, size: 16));
      chips.add(
        ActionChip(
          label: Text(segment),
          onPressed: () {
            // Always navigate when clicking breadcrumb, even if already at that path
            _loadPath(normalizedRunningPath, forceReload: true);
          },
        ),
      );
    }

    // Add "+" button to navigate deeper
    chips.add(Icon(NerdIcon.arrowRight.data, size: 16));
    chips.add(
      IconButton(
        icon: const Icon(Icons.add, size: 18),
        tooltip: 'Navigate to subdirectory',
        onPressed: () => _showNavigateToSubdirectoryDialog(),
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(4),
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );

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
            controller: _scrollController,
            itemCount: sortedEntries.length,
            separatorBuilder: (_, _) => Padding(
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
                  ? Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colorScheme.primary)
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

  Future<void> _loadPath(String path, {bool forceReload = false}) async {
    final target = _normalizePath(path);
    // Skip if already at this path and not loading, unless forced
    if (!forceReload && target == _currentPath && !_loading) {
      return;
    }
    // If forced reload and same path, still reload
    // If already loading the same path and not forced, skip
    if (!forceReload && target == _currentPath && _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _runShell(
        () => widget.shellService.listDirectory(widget.host, target),
      );
      if (!mounted) {
        return;
      }
      // Filter out "." and ".." entries from parsed output
      final filteredEntries = entries.where((e) => e.name != '.' && e.name != '..').toList();
      
      // Add ".." entry at the beginning if not at root (for navigation)
      if (target != '/') {
        filteredEntries.insert(0, RemoteFileEntry(
          name: '..',
          isDirectory: true,
          sizeBytes: 0,
          modified: DateTime.now(),
        ));
      }
      
      setState(() {
        _entries
          ..clear()
          ..addAll(filteredEntries);
        _currentPath = target;
        _pathFieldController?.text = _currentPath;
        _loading = false;
        _pathHistory.add(_currentPath);
        _selectedPaths.clear();
        _selectionAnchorIndex = null;
        _lastSelectedIndex = null;
        for (final entry in filteredEntries) {
          if (entry.isDirectory && entry.name != '..') {
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

  /// Soft refresh: reloads entries without resetting scroll position or selection
  Future<void> _refreshCurrentPath() async {
    if (_currentPath.isEmpty) {
      return;
    }
    try {
      final entries = await _runShell(
        () => widget.shellService.listDirectory(widget.host, _currentPath),
      );
      if (!mounted) {
        return;
      }
      // Filter out "." and ".." entries from parsed output
      final filteredEntries = entries.where((e) => e.name != '.' && e.name != '..').toList();
      
      // Add ".." entry at the beginning if not at root (for navigation)
      if (_currentPath != '/') {
        filteredEntries.insert(0, RemoteFileEntry(
          name: '..',
          isDirectory: true,
          sizeBytes: 0,
          modified: DateTime.now(),
        ));
      }
      
      // Preserve scroll position
      final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
      
      setState(() {
        _entries
          ..clear()
          ..addAll(filteredEntries);
        // Don't clear selection or reset loading state
        // Don't clear selection indices
        // Update path history for new directories
        for (final entry in filteredEntries) {
          if (entry.isDirectory && entry.name != '..') {
            _pathHistory.add(_joinPath(_currentPath, entry.name));
          }
        }
      });
      
      // Restore scroll position after rebuild
      if (_scrollController.hasClients && scrollOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(scrollOffset);
          }
        });
      }
      
      unawaited(_hydrateCachedSessions(entries, _currentPath));
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint('Failed to refresh current path: $error');
      // Don't show error in UI for soft refresh failures
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
    final sortedEntries = _currentSortedEntries();
    final selectedEntries = _getSelectedEntries(sortedEntries);
    final isMultiSelect = selectedEntries.length > 1;
    final menuItems = <PopupMenuEntry<_ExplorerContextAction>>[];
    final clipboardAvailable = ExplorerClipboard.hasEntries;
    
    // If nothing is selected, show general menu (paste/upload for current directory)
    if (selectedEntries.isEmpty) {
      if (clipboardAvailable) {
        menuItems.add(
          PopupMenuItem(
            value: _ExplorerContextAction.paste,
            enabled: clipboardAvailable,
            child: Text('Paste ($_shortcutPaste)'),
          ),
        );
      }
      
      // Upload action - always show for current directory
      menuItems.add(
        const PopupMenuItem(
          value: _ExplorerContextAction.upload,
          child: Text('Upload files here...'),
        ),
      );
      
      // Show the menu
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
      
      if (!mounted) return;
      if (action == _ExplorerContextAction.paste) {
        await _handlePaste(targetDirectory: _currentPath);
      } else if (action == _ExplorerContextAction.upload) {
        await _handleUpload(_currentPath);
      }
      return;
    }

    // Single selection actions
    if (!isMultiSelect) {
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
      menuItems.add(
        PopupMenuItem(
          value: _ExplorerContextAction.rename,
          child: Text('Rename ($_shortcutRename)'),
        ),
      );
      menuItems.add(
        const PopupMenuItem(
          value: _ExplorerContextAction.move,
          child: Text('Move to...'),
        ),
      );
    }

    // Multi-select compatible actions
    menuItems.addAll([
      PopupMenuItem(
        value: _ExplorerContextAction.copy,
        child: Text(
          isMultiSelect
              ? 'Copy (${selectedEntries.length} items) ($_shortcutCopy)'
              : 'Copy ($_shortcutCopy)',
        ),
      ),
      PopupMenuItem(
        value: _ExplorerContextAction.cut,
        child: Text(
          isMultiSelect
              ? 'Cut (${selectedEntries.length} items) ($_shortcutCut)'
              : 'Cut ($_shortcutCut)',
        ),
      ),
      PopupMenuItem(
        value: _ExplorerContextAction.paste,
        enabled: clipboardAvailable,
        child: Text('Paste ($_shortcutPaste)'),
      ),
    ]);

    // Paste into (only for single directory selection)
    if (!isMultiSelect && entry.isDirectory) {
      menuItems.add(
        PopupMenuItem(
          value: _ExplorerContextAction.pasteInto,
          enabled: clipboardAvailable,
          child: Text('Paste into "${entry.name}" ($_shortcutPaste)'),
        ),
      );
    }

    // Download action
    menuItems.add(
      PopupMenuItem(
        value: _ExplorerContextAction.download,
        child: Text(
          isMultiSelect
              ? 'Download (${selectedEntries.length} items)'
              : 'Download',
        ),
      ),
    );

    // Upload action (only show on background or directory)
    if (!isMultiSelect && entry.isDirectory) {
      menuItems.add(
        const PopupMenuItem(
          value: _ExplorerContextAction.upload,
          child: Text('Upload files here...'),
        ),
      );
    }

    // Delete action
    menuItems.add(
      PopupMenuItem(
        value: _ExplorerContextAction.delete,
        child: Text(
          isMultiSelect
              ? 'Delete (${selectedEntries.length} items) ($_shortcutDelete)'
              : 'Delete ($_shortcutDelete)',
        ),
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
        if (!isMultiSelect) {
          _loadPath(_joinPath(_currentPath, entry.name));
        }
        break;
      case _ExplorerContextAction.copyPath:
        if (!isMultiSelect) {
          final path = _joinPath(_currentPath, entry.name);
          await Clipboard.setData(ClipboardData(text: path));
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied $path')));
        } else {
          final paths = selectedEntries
              .map((e) => _joinPath(_currentPath, e.name))
              .join('\n');
          await Clipboard.setData(ClipboardData(text: paths));
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied ${selectedEntries.length} paths'),
            ),
          );
        }
        break;
      case _ExplorerContextAction.openLocally:
        if (!isMultiSelect) {
          await _openLocally(entry);
        }
        break;
      case _ExplorerContextAction.editFile:
        if (!isMultiSelect) {
          await _openEditor(entry);
        }
        break;
      case _ExplorerContextAction.rename:
        if (!isMultiSelect) {
          await _promptRename(entry);
        }
        break;
      case _ExplorerContextAction.copy:
        if (isMultiSelect) {
          await _handleMultiCopy(selectedEntries);
        } else {
          _handleClipboardSet(entry, ExplorerClipboardOperation.copy);
        }
        break;
      case _ExplorerContextAction.cut:
        if (isMultiSelect) {
          await _handleMultiCut(selectedEntries);
        } else {
          _handleClipboardSet(entry, ExplorerClipboardOperation.cut);
        }
        break;
      case _ExplorerContextAction.paste:
        await _handlePaste(targetDirectory: _currentPath);
        break;
      case _ExplorerContextAction.pasteInto:
        if (!isMultiSelect) {
          await _handlePaste(
            targetDirectory: _joinPath(_currentPath, entry.name),
          );
        }
        break;
      case _ExplorerContextAction.move:
        if (!isMultiSelect) {
          await _promptMove(entry);
        }
        break;
      case _ExplorerContextAction.delete:
        if (isMultiSelect) {
          await _confirmMultiDelete(selectedEntries, permanent: _isShiftPressed());
        } else {
          await _confirmDelete(entry, permanent: _isShiftPressed());
        }
        break;
      case _ExplorerContextAction.download:
        await _handleDownload(selectedEntries);
        break;
      case _ExplorerContextAction.upload:
        if (!isMultiSelect && entry.isDirectory) {
          await _handleUpload(_joinPath(_currentPath, entry.name));
        }
        break;
      case null:
        break;
    }
  }

  Future<void> _showBackgroundContextMenu(Offset position) async {
    final clipboardAvailable = ExplorerClipboard.hasEntries;
    final menuItems = <PopupMenuEntry<_ExplorerContextAction>>[];
    
    if (clipboardAvailable) {
      menuItems.add(
        PopupMenuItem(
          value: _ExplorerContextAction.paste,
          enabled: clipboardAvailable,
          child: Text('Paste ($_shortcutPaste)'),
        ),
      );
    }
    
    menuItems.add(
      const PopupMenuItem(
        value: _ExplorerContextAction.upload,
        child: Text('Upload files here...'),
      ),
    );
    
    if (menuItems.isEmpty) {
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
      items: menuItems,
    );
    if (!mounted) {
      return;
    }
    if (action == _ExplorerContextAction.paste) {
      await _handlePaste(targetDirectory: _currentPath);
    } else if (action == _ExplorerContextAction.upload) {
      await _handleUpload(_currentPath);
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
      final contents = await _runShell(
        () => widget.shellService.readFile(widget.host, path),
      );
      if (!mounted) {
        return;
      }
      final updated = await showDialog<String>(
        context: context,
        builder: (context) =>
            RemoteFileEditorDialog(path: path, initialContent: contents),
      );
      if (updated != null && updated != contents) {
        await _runShell(
          () => widget.shellService.writeFile(widget.host, path, updated),
        );
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
        final contents = await _runShell(
          () => widget.shellService.readFile(widget.host, remotePath),
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
      final remoteContents = await _runShell(
        () => widget.shellService.readFile(widget.host, session.remotePath),
      );

      if (remoteContents == baseContents) {
        await _runShell(
          () => widget.shellService.writeFile(
            widget.host,
            session.remotePath,
            localContents,
          ),
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
          await _runShell(
            () => widget.shellService.writeFile(
              widget.host,
              session.remotePath,
              merged,
            ),
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

  Future<T> _runShell<T>(Future<T> Function() action) {
    if (widget.shellService is BuiltInRemoteShellService &&
        widget.builtInVault != null) {
      final service = widget.shellService as BuiltInRemoteShellService;

      final keyId = service.getActiveBuiltInKeyId(widget.host);
      if (keyId != null && widget.builtInVault!.isUnlocked(keyId)) {
        // Key already unlocked → do not repeat unlock flow.
        return action();
      }
    }
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
            SnackBar(content: Text('Passphrase stored for $keyLabel.')),
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
      } on BuiltInSshAuthenticationFailed catch (error) {
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
    final vault = widget.builtInVault;
    if (vault == null) {
      return false;
    }
    _unlockInProgress = true;
    debugPrint('[Explorer] Prompting unlock for key $keyId');
    try {
      // Check if password is needed
      final needsPwd = await vault.needsPassword(keyId);
      String? password;
      if (needsPwd) {
        password = await _showUnlockDialog(keyId);
        if (password == null) {
          debugPrint('[Explorer] Unlock cancelled for key $keyId');
          return false;
        }
      }
      await vault.unlock(keyId, password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key unlocked for this session.')),
        );
        debugPrint('[Explorer] Unlock succeeded for key $keyId');
      }
      return true;
    } on BuiltInSshKeyDecryptException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password for that key.')),
        );
      }
      debugPrint('[Explorer] Unlock failed for key $keyId due to bad password');
      return false;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to unlock key: $error')));
      }
      debugPrint('[Explorer] Unlock failed for key $keyId. error=$error');
      return false;
    } finally {
      _unlockInProgress = false;
      debugPrint('[Explorer] Unlock flow completed for key $keyId');
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
      debugPrint('[Explorer] Awaiting existing passphrase for $key');
      return existing;
    }
    final completer = Completer<String?>();
    _pendingPassphrasePrompts[key] = completer.future;
    () async {
      try {
        debugPrint('[Explorer] Prompting passphrase for $key');
        final result = await _promptPassphrase(host, path);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPassphrasePrompts.remove(key);
        debugPrint('[Explorer] Passphrase prompt completed for $key');
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

  Future<void> _refreshCacheFromServer(_LocalFileSession session) async {
    setState(() {
      _refreshingPaths.add(session.remotePath);
    });
    try {
      final remoteContents = await _runShell(
        () => widget.shellService.readFile(widget.host, session.remotePath),
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
      await _runShell(
        () => widget.shellService.movePath(
          widget.host,
          sourcePath,
          destinationPath,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed ${entry.name} to $trimmed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to rename: $error')));
    }
  }

  Future<void> _promptMove(RemoteFileEntry entry) async {
    final controller = TextEditingController(
      text: _joinPath(_currentPath, entry.name),
    );
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
      await _runShell(
        () => widget.shellService.movePath(
          widget.host,
          _joinPath(_currentPath, entry.name),
          normalized,
        ),
      );
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${entry.name} to $normalized')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to move: $error')));
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
      await _runShell(() => widget.shellService.deletePath(widget.host, path));
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${entry.name} permanently')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $error')));
    }
  }

  Future<void> _moveEntryToTrash(RemoteFileEntry entry) async {
    final path = _joinPath(_currentPath, entry.name);
    TrashedEntry? recorded;
    try {
      recorded = await _runShell(
        () => widget.trashManager.moveToTrash(
          shellService: widget.shellService,
          host: widget.host,
          remotePath: path,
          isDirectory: entry.isDirectory,
          notify: false,
        ),
      );
      await _runShell(() => widget.shellService.deletePath(widget.host, path));
      widget.trashManager.notifyListeners();
      await _refreshCurrentPath();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Moved ${entry.name} to trash')));
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
    final clipboardEntries = ExplorerClipboard.entries;
    if (clipboardEntries.isEmpty) {
      return;
    }
    final destinationDir = _normalizePath(targetDirectory);
    final refreshCurrent = destinationDir == _currentPath;
    
    // Show progress dialog for multiple items
    FileOperationProgressController? progressController;
    if (clipboardEntries.length > 1) {
      if (!mounted) return;
      progressController = FileOperationProgressDialog.show(
        context,
        operation: clipboardEntries.first.operation == ExplorerClipboardOperation.copy
            ? 'Copying'
            : 'Moving',
        totalItems: clipboardEntries.length,
      );
    }
    
    int successCount = 0;
    int failCount = 0;
    final cutEntries = <ExplorerClipboardEntry>[];
    
    for (var i = 0; i < clipboardEntries.length; i++) {
      final clipboard = clipboardEntries[i];
      final destinationPath = _joinPath(destinationDir, clipboard.displayName);
      
      // Skip if pasting to same location
      if (clipboard.host.name == widget.host.name &&
          clipboard.remotePath == destinationPath) {
        if (progressController != null) {
          progressController.increment();
        }
        continue;
      }
      
      // Update progress
      if (progressController != null) {
        progressController.updateProgress(currentItem: clipboard.displayName);
      }
      
      try {
        if (clipboard.host.name == widget.host.name) {
          if (clipboard.operation == ExplorerClipboardOperation.copy) {
            await _runShell(
              () => widget.shellService.copyPath(
                widget.host,
                clipboard.remotePath,
                destinationPath,
                recursive: clipboard.isDirectory,
              ),
            );
            successCount++;
          } else {
            await _runShell(
              () => widget.shellService.movePath(
                widget.host,
                clipboard.remotePath,
                destinationPath,
              ),
            );
            cutEntries.add(clipboard);
            successCount++;
          }
        } else {
          await _runShell(
            () => widget.shellService.copyBetweenHosts(
              sourceHost: clipboard.host,
              sourcePath: clipboard.remotePath,
              destinationHost: widget.host,
              destinationPath: destinationPath,
              recursive: clipboard.isDirectory,
            ),
          );
          if (clipboard.operation == ExplorerClipboardOperation.cut) {
            await _runShell(
              () => widget.shellService.deletePath(
                clipboard.host,
                clipboard.remotePath,
              ),
            );
            cutEntries.add(clipboard);
          }
          successCount++;
        }
        if (progressController != null) {
          progressController.increment();
        }
      } catch (error) {
        failCount++;
        debugPrint('Failed to paste ${clipboard.displayName}: $error');
        if (progressController != null) {
          progressController.increment();
        }
      }
    }
    
    // Close progress dialog if shown
    if (progressController != null && mounted) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    
    // Notify cut completion for all cut entries
    if (cutEntries.isNotEmpty) {
      ExplorerClipboard.notifyCutsCompleted(cutEntries);
    }
    
    if (refreshCurrent) {
      await _refreshCurrentPath();
    }
    if (!mounted) return;
    
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successCount == 1
                ? 'Pasted ${clipboardEntries.first.displayName}'
                : 'Pasted $successCount item${successCount > 1 ? 's' : ''}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pasted $successCount item${successCount > 1 ? 's' : ''}. $failCount failed.',
          ),
        ),
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
      // Don't select on right-click - just show context menu
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

  void _handleDragHover(PointerEnterEvent event, int index, String remotePath) {
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
        final selectedEntries = _getSelectedEntries(entries);
        if (selectedEntries.isNotEmpty) {
          if (selectedEntries.length > 1) {
            unawaited(_handleMultiCopy(selectedEntries));
          } else {
            _handleClipboardSet(selectedEntries.first, ExplorerClipboardOperation.copy);
          }
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        final selectedEntries = _getSelectedEntries(entries);
        if (selectedEntries.isNotEmpty) {
          if (selectedEntries.length > 1) {
            unawaited(_handleMultiCut(selectedEntries));
          } else {
            _handleClipboardSet(selectedEntries.first, ExplorerClipboardOperation.cut);
          }
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        unawaited(_handlePaste(targetDirectory: _currentPath));
        return KeyEventResult.handled;
      }
    }
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.delete) {
      final selectedEntries = _getSelectedEntries(entries);
      if (selectedEntries.isNotEmpty) {
        if (selectedEntries.length > 1) {
          unawaited(_confirmMultiDelete(selectedEntries, permanent: shift));
        } else {
          unawaited(_confirmDelete(selectedEntries.first, permanent: shift));
        }
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

  List<RemoteFileEntry> _getSelectedEntries(List<RemoteFileEntry> entries) {
    return entries
        .where((entry) =>
            _selectedPaths.contains(_joinPath(_currentPath, entry.name)))
        .toList();
  }

  Future<void> _handleMultiCopy(List<RemoteFileEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }
    final clipboardEntries = entries.map((entry) {
      final remotePath = _joinPath(_currentPath, entry.name);
      return ExplorerClipboardEntry(
        host: widget.host,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: ExplorerClipboardOperation.copy,
      );
    }).toList();
    
    ExplorerClipboard.setEntries(clipboardEntries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entries.length == 1
              ? 'Copied ${entries.first.name}'
              : 'Copied ${entries.length} items',
        ),
      ),
    );
  }

  Future<void> _handleMultiCut(List<RemoteFileEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }
    final clipboardEntries = entries.map((entry) {
      final remotePath = _joinPath(_currentPath, entry.name);
      return ExplorerClipboardEntry(
        host: widget.host,
        remotePath: remotePath,
        displayName: entry.name,
        isDirectory: entry.isDirectory,
        operation: ExplorerClipboardOperation.cut,
      );
    }).toList();
    
    ExplorerClipboard.setEntries(clipboardEntries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          entries.length == 1
              ? 'Cut ${entries.first.name}'
              : 'Cut ${entries.length} items',
        ),
      ),
    );
  }

  Future<void> _confirmMultiDelete(
    List<RemoteFileEntry> entries, {
    bool permanent = false,
  }) async {
    if (entries.isEmpty) {
      return;
    }
    final deletePermanently = permanent || _isShiftPressed();
    final count = entries.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          deletePermanently
              ? 'Delete $count items permanently?'
              : 'Move $count items to trash?',
        ),
        content: Text(
          deletePermanently
              ? 'This will permanently delete $count items from ${widget.host.name}.'
              : 'Backups will be stored locally so you can restore them later.',
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
      await _deleteMultiplePermanently(entries);
    } else {
      await _moveMultipleToTrash(entries);
    }
  }

  Future<void> _deleteMultiplePermanently(List<RemoteFileEntry> entries) async {
    int successCount = 0;
    int failCount = 0;
    for (final entry in entries) {
      try {
        final path = _joinPath(_currentPath, entry.name);
        await _runShell(() => widget.shellService.deletePath(widget.host, path));
        successCount++;
      } catch (error) {
        failCount++;
        debugPrint('Failed to delete ${entry.name}: $error');
      }
    }
    await _loadPath(_currentPath);
    if (!mounted) return;
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $successCount items permanently')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted $successCount items. $failCount failed.',
          ),
        ),
      );
    }
  }

  Future<void> _moveMultipleToTrash(List<RemoteFileEntry> entries) async {
    int successCount = 0;
    int failCount = 0;
    for (final entry in entries) {
      try {
        final path = _joinPath(_currentPath, entry.name);
        await _runShell(
          () => widget.trashManager.moveToTrash(
            shellService: widget.shellService,
            host: widget.host,
            remotePath: path,
            isDirectory: entry.isDirectory,
            notify: false,
          ),
        );
        await _runShell(() => widget.shellService.deletePath(widget.host, path));
        successCount++;
      } catch (error) {
        failCount++;
        debugPrint('Failed to move ${entry.name} to trash: $error');
      }
    }
    widget.trashManager.notifyListeners();
    await _loadPath(_currentPath);
    if (!mounted) return;
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $successCount items to trash')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved $successCount items to trash. $failCount failed.'),
        ),
      );
    }
  }

  Future<void> _handleDownload(List<RemoteFileEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }

    // Prompt user to select download directory
    String? selectedDirectory;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select download location',
      );
    }

    if (selectedDirectory == null) {
      return;
    }

    final downloadDir = Directory(selectedDirectory);
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    // Show progress dialog
    if (!mounted) return;
    final progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Downloading',
      totalItems: entries.length,
    );

    try {
      if (entries.length == 1) {
        // Single file/directory download
        progressController.updateProgress(currentItem: entries.first.name);
        await _downloadSingleEntry(entries.first, downloadDir.path);
        progressController.increment();
      } else {
        // Multiple files/directories download - download to temp then zip
        final tempDir = await Directory.systemTemp.createTemp(
          'cwatch-download-${DateTime.now().microsecondsSinceEpoch}',
        );
        try {
          // Download all entries to temp directory
          for (var i = 0; i < entries.length; i++) {
            final entry = entries[i];
            if (!mounted) return;
            
            progressController.updateProgress(currentItem: entry.name);
            final remotePath = _joinPath(_currentPath, entry.name);
            await _runShell(
              () => widget.shellService.downloadPath(
                host: widget.host,
                remotePath: remotePath,
                localDestination: tempDir.path,
                recursive: entry.isDirectory,
              ),
            );
            if (!mounted) return;
            progressController.increment();
          }
          
          // Create zip archive for multiple items
          if (!mounted) return;
          progressController.updateProgress(
            currentItem: 'Creating archive...',
          );
          await _createZipArchiveFromTemp(entries, tempDir.path, downloadDir.path);
          if (!mounted) return;
        } finally {
          await tempDir.delete(recursive: true);
        }
      }

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded ${entries.length} item${entries.length > 1 ? 's' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _downloadSingleEntry(
    RemoteFileEntry entry,
    String downloadDir,
  ) async {
    final remotePath = _joinPath(_currentPath, entry.name);

    if (entry.isDirectory) {
      // Download directory to temp first, then compress
      final tempDir = await Directory.systemTemp.createTemp(
        'cwatch-download-${DateTime.now().microsecondsSinceEpoch}',
      );
      try {
        // Download to temp directory first
        await _runShell(
          () => widget.shellService.downloadPath(
            host: widget.host,
            remotePath: remotePath,
            localDestination: tempDir.path,
            recursive: true,
          ),
        );

        // Find the downloaded directory
        final downloadedPath = p.join(tempDir.path, entry.name);
        final downloadedDir = Directory(downloadedPath);
        if (!await downloadedDir.exists()) {
          throw Exception('Downloaded directory not found');
        }

        // Create zip archive
        final archive = Archive();
        await _addDirectoryToArchive(archive, downloadedDir, entry.name);

        // Write zip file
        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        final zipFile = File(p.join(downloadDir, '${entry.name}.zip'));
        await zipFile.writeAsBytes(zipBytes);
      } finally {
        await tempDir.delete(recursive: true);
      }
    } else {
      // Download single file
      await _runShell(
        () => widget.shellService.downloadPath(
          host: widget.host,
          remotePath: remotePath,
          localDestination: downloadDir,
          recursive: false,
        ),
      );
    }
  }

  Future<void> _createZipArchiveFromTemp(
    List<RemoteFileEntry> entries,
    String tempDir,
    String downloadDir,
  ) async {
    // Create a zip archive containing all downloaded items
    final archive = Archive();
    for (final entry in entries) {
      final downloadedPath = p.join(tempDir, entry.name);
      final downloadedEntity = FileSystemEntity.typeSync(downloadedPath);
      if (downloadedEntity == FileSystemEntityType.directory) {
        await _addDirectoryToArchive(
          archive,
          Directory(downloadedPath),
          entry.name,
        );
      } else if (downloadedEntity == FileSystemEntityType.file) {
        final file = File(downloadedPath);
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile(entry.name, bytes.length, bytes),
        );
      }
    }

    // Write zip file
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    // Use a default name
    final zipFileName = entries.length == 1
        ? '${entries.first.name}.zip'
        : 'download_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File(p.join(downloadDir, zipFileName));
    await zipFile.writeAsBytes(zipBytes);
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory directory,
    String archivePath,
  ) async {
    await for (final entity in directory.list(recursive: false)) {
      final name = p.basename(entity.path);
      final entryPath = p.join(archivePath, name).replaceAll('\\', '/');

      if (entity is File) {
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(entryPath, bytes.length, bytes));
      } else if (entity is Directory) {
        await _addDirectoryToArchive(archive, entity, entryPath);
      }
    }
  }

  Future<void> _handleUpload(String targetDirectory) async {
    // Prompt user to select files/directories to upload
    FilePickerResult? result;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        dialogTitle: 'Select files to upload',
      );
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) {
      return;
    }

    // Show progress dialog
    if (!mounted) return;
    final progressController = FileOperationProgressDialog.show(
      context,
      operation: 'Uploading',
      totalItems: files.length,
    );

    try {
      int successCount = 0;
      int failCount = 0;

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        if (file.path == null) continue;

        if (!mounted) {
          return;
        }

        final localPath = file.path!;
        final fileName = p.basename(localPath);
        final remotePath = _joinPath(targetDirectory, fileName);

        progressController.updateProgress(currentItem: fileName);

        try {
          final localEntity = FileSystemEntity.typeSync(localPath);
          final isDirectory = localEntity == FileSystemEntityType.directory;

          await _runShell(
            () => widget.shellService.uploadPath(
              host: widget.host,
              localPath: localPath,
              remoteDestination: remotePath,
              recursive: isDirectory,
            ),
          );
          if (!mounted) return;
          successCount++;
        } catch (error) {
          if (!mounted) return;
          failCount++;
          debugPrint('Failed to upload $fileName: $error');
        }

        if (!mounted) return;
        progressController.increment();
      }

      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _refreshCurrentPath();

      if (!mounted) return;
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount item${successCount > 1 ? 's' : ''}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded $successCount item${successCount > 1 ? 's' : ''}. $failCount failed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    }
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

  Future<void> _showNavigateToSubdirectoryDialog() async {
    // Get list of directories in current path
    final directories = _entries
        .where((entry) => entry.isDirectory)
        .map((entry) => entry.name)
        .toList()
      ..sort();

    if (directories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subdirectories available')),
      );
      return;
    }

    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Navigate to subdirectory'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: directories.length,
            itemBuilder: (context, index) {
              final dir = directories[index];
              return ListTile(
                leading: Icon(NerdIcon.folder.data),
                title: Text(dir),
                onTap: () => Navigator.of(context).pop(dir),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      final targetPath = _joinPath(_currentPath, selected);
      _loadPath(targetPath);
    }
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
  download,
  upload,
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
