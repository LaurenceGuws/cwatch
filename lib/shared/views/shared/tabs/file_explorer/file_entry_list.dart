import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/nerd_fonts.dart';
import '../../../../widgets/data_table/structured_data_table.dart';
import '../../../../widgets/lists/selectable_list_item.dart';
import 'file_icon_resolver.dart';

/// Local file session model
class LocalFileSession {
  LocalFileSession({
    required this.localPath,
    required this.snapshotPath,
    required this.remotePath,
  });

  final String localPath;
  final String snapshotPath;
  final String remotePath;
  DateTime? lastSynced;
}

/// Widget for displaying the list of file entries
class FileEntryList extends StatefulWidget {
  const FileEntryList({
    super.key,
    required this.entries,
    required this.currentPath,
    required this.selectedPaths,
    required this.syncingPaths,
    required this.refreshingPaths,
    required this.localEdits,
    required this.scrollController,
    required this.focusNode,
    required this.onEntryDoubleTap,
    required this.onEntryPointerDown,
    required this.onDragHover,
    required this.onStopDragSelection,
    required this.onEntryContextMenu,
    this.onBackgroundContextMenu,
    required this.onKeyEvent,
    required this.onSyncLocalEdit,
    required this.onRefreshCacheFromServer,
    required this.onClearCachedCopy,
    this.onStartOsDrag,
    required this.joinPath,
  });

  final List<RemoteFileEntry> entries;
  final String currentPath;
  final Set<String> selectedPaths;
  final Set<String> syncingPaths;
  final Set<String> refreshingPaths;
  final Map<String, LocalFileSession> localEdits;
  final ScrollController scrollController;
  final FocusNode focusNode;
  final ValueChanged<RemoteFileEntry> onEntryDoubleTap;
  final ValueChanged4<PointerDownEvent, List<RemoteFileEntry>, int, String>
  onEntryPointerDown;
  final ValueChanged3<PointerEnterEvent, int, String> onDragHover;
  final VoidCallback onStopDragSelection;
  final ValueChanged2<RemoteFileEntry, Offset> onEntryContextMenu;
  final ValueChanged<Offset>? onBackgroundContextMenu;
  final KeyEventResult Function(FocusNode, KeyEvent, List<RemoteFileEntry>)
  onKeyEvent;
  final ValueChanged<LocalFileSession> onSyncLocalEdit;
  final ValueChanged<LocalFileSession> onRefreshCacheFromServer;
  final ValueChanged<LocalFileSession> onClearCachedCopy;
  final ValueChanged<Offset>? onStartOsDrag;
  final String Function(String, String) joinPath;

  @override
  State<FileEntryList> createState() => _FileEntryListState();
}

class _FileEntryListState extends State<FileEntryList> {
  final Map<int, Offset> _pointerDownPositions = {};
  final Set<int> _draggedPointers = {};

  String _remotePath(RemoteFileEntry entry) {
    return widget.joinPath(widget.currentPath, entry.name);
  }

  bool _isSelected(RemoteFileEntry entry) {
    return widget.selectedPaths.contains(_remotePath(entry));
  }

  LocalFileSession? _sessionFor(RemoteFileEntry entry) {
    return widget.localEdits[_remotePath(entry)];
  }

  String _sizeLabel(RemoteFileEntry entry) {
    if (entry.isDirectory) {
      return '—';
    }
    return '${(entry.sizeBytes / 1024).toStringAsFixed(1)} KB';
  }

  String _secondaryLabel(RemoteFileEntry entry) {
    return entry.isDirectory ? 'Directory' : _sizeLabel(entry);
  }

  String _modifiedLabel(RemoteFileEntry entry) {
    return entry.modified.toLocal().toString();
  }

  void _handleRowPointerDown(
    int index,
    RemoteFileEntry entry,
    PointerDownEvent event,
  ) {
    _pointerDownPositions[event.pointer] = event.position;
    _draggedPointers.remove(event.pointer);
    widget.onEntryPointerDown(event, widget.entries, index, _remotePath(entry));
  }

  void _handleRowPointerMove(
    int index,
    RemoteFileEntry entry,
    PointerMoveEvent event,
  ) {
    if (widget.onStartOsDrag == null) {
      return;
    }
    if (_draggedPointers.contains(event.pointer)) {
      return;
    }
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    final origin = _pointerDownPositions[event.pointer];
    if (origin == null) {
      return;
    }
    final delta = (event.position - origin).distance;
    if (delta <= 6) {
      return;
    }
    _draggedPointers.add(event.pointer);
    widget.onStartOsDrag!(event.position);
  }

  void _handleRowPointerUp(
    int index,
    RemoteFileEntry entry,
    PointerUpEvent event,
  ) {
    _pointerDownPositions.remove(event.pointer);
    _draggedPointers.remove(event.pointer);
    widget.onStopDragSelection();
  }

  void _handleRowPointerCancel(
    int index,
    RemoteFileEntry entry,
    PointerCancelEvent event,
  ) {
    _pointerDownPositions.remove(event.pointer);
    _draggedPointers.remove(event.pointer);
    widget.onStopDragSelection();
  }

  void _handleRowPointerEnter(
    int index,
    RemoteFileEntry entry,
    PointerEnterEvent event,
  ) {
    widget.onDragHover(event, index, _remotePath(entry));
  }

  List<StructuredDataColumn<RemoteFileEntry>> _columns(BuildContext context) {
    return [
      StructuredDataColumn<RemoteFileEntry>(
        label: 'Name',
        autoFitText: (entry) => entry.name,
        cellBuilder: _buildNameCell,
      ),
      StructuredDataColumn<RemoteFileEntry>(
        label: 'Size',
        alignment: Alignment.centerRight,
        autoFitText: _sizeLabel,
        cellBuilder: (context, entry) => Text(_sizeLabel(entry)),
      ),
      StructuredDataColumn<RemoteFileEntry>(
        label: 'Modified',
        autoFitText: _modifiedLabel,
        cellBuilder: (context, entry) => Text(_modifiedLabel(entry)),
      ),
      StructuredDataColumn<RemoteFileEntry>(
        label: 'Actions',
        alignment: Alignment.centerRight,
        minWidth: 140,
        autoFitText: (_) => 'Actions',
        cellBuilder: _buildActionsCell,
      ),
    ];
  }

  Widget _buildNameCell(BuildContext context, RemoteFileEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _isSelected(entry);
    final iconColor = selected
        ? colorScheme.primary
        : FileIconResolver.colorFor(entry, colorScheme);
    final icon = FileIconResolver.iconFor(entry);
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                _secondaryLabel(entry),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCell(BuildContext context, RemoteFileEntry entry) {
    if (entry.isDirectory) {
      return const SizedBox.shrink();
    }
    final session = _sessionFor(entry);
    if (session == null) {
      return const SizedBox.shrink();
    }
    final remotePath = session.remotePath;
    final syncing = widget.syncingPaths.contains(remotePath);
    final refreshing = widget.refreshingPaths.contains(remotePath);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Push local changes to server',
          icon: syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(NerdIcon.cloudUpload.data),
          onPressed: syncing ? null : () => widget.onSyncLocalEdit(session),
        ),
        IconButton(
          tooltip: 'Refresh cache from server',
          icon: refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(NerdIcon.refresh.data),
          onPressed: refreshing
              ? null
              : () => widget.onRefreshCacheFromServer(session),
        ),
        IconButton(
          tooltip: 'Clear cached copy',
          icon: Icon(NerdIcon.delete.data),
          onPressed: () => widget.onClearCachedCopy(session),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) =>
          widget.onKeyEvent(node, event, widget.entries),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => widget.onStopDragSelection(),
        onPointerCancel: (_) => widget.onStopDragSelection(),
        child: StructuredDataTable<RemoteFileEntry>(
          rows: widget.entries,
          columns: _columns(context),
          rowHeight: 64,
          shrinkToContent: false,
          useZebraStripes: false,
          surfaceBackgroundColor: context.appTheme.section.surface.background,
          primaryDoubleClickOpensContextMenu: false,
          verticalController: widget.scrollController,
          rowSelectionEnabled: false,
          enableKeyboardNavigation: false,
          rowSelectionPredicate: _isSelected,
          selectedRowsBuilder: (rows) =>
              rows.where((entry) => _isSelected(entry)).toList(),
          onRowDoubleTap: widget.onEntryDoubleTap,
          onRowContextMenu: (entry, position) =>
              widget.onEntryContextMenu(entry, position ?? Offset.zero),
          onRowPointerDown: _handleRowPointerDown,
          onRowPointerMove: _handleRowPointerMove,
          onRowPointerUp: _handleRowPointerUp,
          onRowPointerCancel: _handleRowPointerCancel,
          onRowPointerEnter: _handleRowPointerEnter,
          onBackgroundContextMenu: widget.onBackgroundContextMenu,
          emptyState: const Center(child: Text('Directory is empty.')),
        ),
      ),
    );
  }
}

/// Widget for a single file entry tile
class FileEntryTile extends StatefulWidget {
  const FileEntryTile({
    super.key,
    required this.stripeIndex,
    required this.entry,
    required this.remotePath,
    required this.selected,
    this.session,
    required this.syncing,
    required this.refreshing,
    required this.onDoubleTap,
    required this.onContextMenu,
    required this.onPointerDown,
    required this.onDragHover,
    required this.onStopDragSelection,
    this.onSyncLocalEdit,
    this.onRefreshCacheFromServer,
    this.onClearCachedCopy,
    this.onStartOsDrag,
  });

  final RemoteFileEntry entry;
  final int stripeIndex;
  final String remotePath;
  final bool selected;
  final LocalFileSession? session;
  final bool syncing;
  final bool refreshing;
  final VoidCallback onDoubleTap;
  final ValueChanged<Offset> onContextMenu;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerEnterEvent> onDragHover;
  final VoidCallback onStopDragSelection;
  final VoidCallback? onSyncLocalEdit;
  final VoidCallback? onRefreshCacheFromServer;
  final VoidCallback? onClearCachedCopy;
  final ValueChanged<Offset>? onStartOsDrag;

  @override
  State<FileEntryTile> createState() => _FileEntryTileState();
}

class _FileEntryTileState extends State<FileEntryTile> {
  Offset? _tapDownPosition;
  DateTime? _tapDownTime;
  bool _hasMoved = false;
  bool _dragStarted = false;

  void _handleLongPress() {
    // Show context menu on long press for touch devices
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final position = _tapDownPosition ?? box.localToGlobal(Offset.zero);
      widget.onContextMenu(position);
    }
    _tapDownPosition = null;
    _tapDownTime = null;
    _hasMoved = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = widget.selected
        ? colorScheme.primary
        : FileIconResolver.colorFor(widget.entry, colorScheme);

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.entry.isDirectory && widget.session != null) ...[
          IconButton(
            tooltip: 'Push local changes to server',
            icon: widget.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(NerdIcon.cloudUpload.data),
            onPressed: widget.syncing ? null : widget.onSyncLocalEdit,
          ),
          IconButton(
            tooltip: 'Refresh cache from server',
            icon: widget.refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(NerdIcon.refresh.data),
            onPressed: widget.refreshing
                ? null
                : widget.onRefreshCacheFromServer,
          ),
          IconButton(
            tooltip: 'Clear cached copy',
            icon: Icon(NerdIcon.delete.data),
            onPressed: widget.onClearCachedCopy,
          ),
        ],
        Text(
          widget.entry.modified.toLocal().toString(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    return MouseRegion(
      onEnter: widget.onDragHover,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          widget.onPointerDown(event);
          _dragStarted = false;
          // Track touch down for tap detection
          if (event.kind == PointerDeviceKind.touch) {
            _tapDownPosition = event.position;
            _tapDownTime = DateTime.now();
            _hasMoved = false;
          } else {
            _tapDownPosition = event.position;
          }
        },
        onPointerMove: (event) {
          final down = _tapDownPosition;
          if (down != null &&
              !_dragStarted &&
              event.kind == PointerDeviceKind.mouse &&
              (event.buttons & kPrimaryMouseButton) != 0) {
            final delta = (event.position - down).distance;
            if (delta > 6 && widget.onStartOsDrag != null) {
              _dragStarted = true;
              widget.onStartOsDrag!(event.position);
            }
          }
          if (event.kind == PointerDeviceKind.touch &&
              _tapDownPosition != null) {
            final delta = (event.position - _tapDownPosition!).distance;
            if (delta > 10) {
              _hasMoved = true;
            }
          }
        },
        onPointerUp: (event) {
          widget.onStopDragSelection();
          _dragStarted = false;
          if (event.kind == PointerDeviceKind.touch &&
              !_hasMoved &&
              _tapDownTime != null &&
              DateTime.now().difference(_tapDownTime!).inMilliseconds < 500) {
            widget.onPointerDown(
              PointerDownEvent(
                position: _tapDownPosition ?? event.position,
                kind: PointerDeviceKind.touch,
                buttons: kPrimaryButton,
              ),
            );
          }
          _tapDownPosition = null;
          _tapDownTime = null;
          _hasMoved = false;
        },
        onPointerCancel: (_) {
          widget.onStopDragSelection();
          _tapDownPosition = null;
          _tapDownTime = null;
          _hasMoved = false;
          _dragStarted = false;
        },
        child: SelectableListItem(
          stripeIndex: widget.stripeIndex,
          title: widget.entry.name,
          subtitle: widget.entry.isDirectory
              ? 'Directory'
              : '${(widget.entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
          leading: Icon(
            FileIconResolver.iconFor(widget.entry),
            color: iconColor,
          ),
          trailing: trailing,
          selected: widget.selected,
          onTap: null,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: _handleLongPress,
          onSecondaryTapDown: (details) =>
              widget.onContextMenu(details.globalPosition),
        ),
      ),
    );
  }
}

// Helper typedefs for callbacks
typedef ValueChanged2<T1, T2> = void Function(T1, T2);
typedef ValueChanged3<T1, T2, T3> = void Function(T1, T2, T3);
typedef ValueChanged4<T1, T2, T3, T4> = void Function(T1, T2, T3, T4);
