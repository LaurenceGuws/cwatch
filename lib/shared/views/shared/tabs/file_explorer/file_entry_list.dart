import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../../models/remote_file_entry.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/nerd_fonts.dart';
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
class FileEntryList extends StatelessWidget {
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
  final String Function(String, String) joinPath;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Directory is empty.'));
    }

    final dividerColor = context.appTheme.section.divider;
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) => onKeyEvent(node, event, entries),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapDown: onBackgroundContextMenu == null
            ? null
            : (details) => onBackgroundContextMenu!(details.globalPosition),
        child: Listener(
          onPointerDown: (_) => focusNode.requestFocus(),
          onPointerUp: (_) => onStopDragSelection(),
          onPointerCancel: (_) => onStopDragSelection(),
          child: ListView.separated(
            controller: scrollController,
            itemCount: entries.length,
            separatorBuilder: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Divider(height: 1, thickness: 1, color: dividerColor),
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final remotePath = joinPath(currentPath, entry.name);
              final session = localEdits[remotePath];
              return FileEntryTile(
                entry: entry,
                remotePath: remotePath,
                selected: selectedPaths.contains(remotePath),
                session: session,
                syncing: syncingPaths.contains(remotePath),
                refreshing: refreshingPaths.contains(remotePath),
                onDoubleTap: () => onEntryDoubleTap(entry),
                onContextMenu: (position) =>
                    onEntryContextMenu(entry, position),
                onPointerDown: (event) =>
                    onEntryPointerDown(event, entries, index, remotePath),
                onDragHover: (event) => onDragHover(event, index, remotePath),
                onStopDragSelection: onStopDragSelection,
                onSyncLocalEdit: session != null
                    ? () => onSyncLocalEdit(session)
                    : null,
                onRefreshCacheFromServer: session != null
                    ? () => onRefreshCacheFromServer(session)
                    : null,
                onClearCachedCopy: session != null
                    ? () => onClearCachedCopy(session)
                    : null,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Widget for a single file entry tile
class FileEntryTile extends StatefulWidget {
  const FileEntryTile({
    super.key,
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
  });

  final RemoteFileEntry entry;
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

  @override
  State<FileEntryTile> createState() => _FileEntryTileState();
}

class _FileEntryTileState extends State<FileEntryTile> {
  Offset? _tapDownPosition;
  DateTime? _tapDownTime;
  bool _hasMoved = false;

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
    final highlightColor = widget.selected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;
    final titleStyle = widget.selected
        ? Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.primary)
        : null;
    return MouseRegion(
      onEnter: widget.onDragHover,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          // Handle mouse pointer events immediately for drag selection
          if (event.kind == PointerDeviceKind.mouse) {
            widget.onPointerDown(event);
          } else if (event.kind == PointerDeviceKind.touch) {
            // Track touch down for tap detection
            _tapDownPosition = event.position;
            _tapDownTime = DateTime.now();
            _hasMoved = false;
          }
        },
        onPointerMove: (event) {
          // If pointer moves significantly, it's a scroll, not a tap
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
          // If it was a touch tap without movement, handle it
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
        },
        child: GestureDetector(
          onLongPress: _handleLongPress,
          onDoubleTap: widget.onDoubleTap,
          behavior: HitTestBehavior.translucent,
          child: InkWell(
            onDoubleTap: widget.onDoubleTap,
            onSecondaryTapDown: (details) =>
                widget.onContextMenu(details.globalPosition),
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
                  FileIconResolver.iconFor(widget.entry),
                  color: widget.selected ? colorScheme.primary : null,
                ),
                title: Text(widget.entry.name, style: titleStyle),
                subtitle: Text(
                  widget.entry.isDirectory
                      ? 'Directory'
                      : '${(widget.entry.sizeBytes / 1024).toStringAsFixed(1)} KB',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.entry.isDirectory &&
                        widget.session != null) ...[
                      IconButton(
                        tooltip: 'Push local changes to server',
                        icon: widget.syncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(NerdIcon.cloudUpload.data),
                        onPressed: widget.syncing
                            ? null
                            : widget.onSyncLocalEdit,
                      ),
                      IconButton(
                        tooltip: 'Refresh cache from server',
                        icon: widget.refreshing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper typedefs for callbacks
typedef ValueChanged2<T1, T2> = void Function(T1, T2);
typedef ValueChanged3<T1, T2, T3> = void Function(T1, T2, T3);
typedef ValueChanged4<T1, T2, T3, T4> = void Function(T1, T2, T3, T4);
