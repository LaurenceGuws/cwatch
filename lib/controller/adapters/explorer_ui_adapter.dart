import 'package:flutter/material.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/controller/adapters/explorer_desktop_drag_source.dart';
import 'package:cwatch/view/shared/widgets/explorer_dialog_builders.dart';
import 'package:cwatch/controller/adapters/explorer_drag_types.dart';
import 'package:cwatch/view/shared/widgets/explorer_merge_conflict_dialog.dart';
import 'package:cwatch/view/shared/widgets/shared_prompt_dialogs.dart';

class ExplorerUiAdapter {
  ExplorerUiAdapter({required this.context});

  final BuildContext context;

  void showSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void showDragNotSupported() {
    showSnackBar('Drag-out not supported on this OS');
  }

  void showNothingToDrag() {
    showSnackBar('Nothing to drag');
  }

  void showDragStarted() {
    showSnackBar('Drag started. Drop to copy/move.');
  }

  Future<DragStartResult> startDesktopDrag({
    required DesktopDragSource source,
    required Offset globalPosition,
    required List<DragLocalItem> items,
  }) {
    return source.startDrag(
      context: context,
      globalPosition: globalPosition,
      items: items,
    );
  }

  Future<T?> showContextMenu<T>({
    required Offset position,
    required List<PopupMenuEntry<T>> items,
    BoxConstraints? constraints,
  }) {
    return showMenuAt<T>(
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
      constraints: constraints,
    );
  }

  Future<T?> showMenuAt<T>({
    required RelativeRect position,
    required List<PopupMenuEntry<T>> items,
    BoxConstraints? constraints,
  }) {
    return showMenu<T>(
      context: context,
      position: position,
      constraints: constraints,
      items: items,
    );
  }

  Future<String?> showRenameDialog(RemoteFileEntry entry) {
    return ExplorerDialogBuilders.showRenameDialog(context, entry);
  }

  Future<String?> showMoveDialog(RemoteFileEntry entry, String currentPath) {
    return ExplorerDialogBuilders.showMoveDialog(context, entry, currentPath);
  }

  Future<bool?> showDeleteDialog(
    RemoteFileEntry entry,
    SshHost host,
    bool deletePermanently,
  ) {
    return ExplorerDialogBuilders.showDeleteDialog(
      context,
      entry,
      host,
      deletePermanently,
    );
  }

  Future<String?> showNavigateToSubdirectoryDialog(
    List<RemoteFileEntry> entries,
  ) {
    return ExplorerDialogBuilders.showNavigateToSubdirectoryDialog(
      context,
      entries,
      showSnackBar,
    );
  }

  Future<String?> showMergeConflictDialog({
    required String remotePath,
    required String local,
    required String remote,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => ExplorerMergeConflictDialog(
        remotePath: remotePath,
        local: local,
        remote: remote,
      ),
    );
  }

  Future<bool?> showMultiDeleteDialog({
    required int count,
    required String hostName,
    required bool deletePermanently,
  }) {
    return showConfirmPromptDialog(
      context: context,
      title: deletePermanently
          ? 'Delete $count items permanently?'
          : 'Move $count items to trash?',
      message: deletePermanently
          ? 'This will permanently delete $count items from $hostName.'
          : 'Backups will be stored locally so you can restore them later.',
      confirmLabel: deletePermanently ? 'Delete' : 'Move to trash',
      destructive: deletePermanently,
    );
  }

  Future<String?> showTextInputDialog({
    required String title,
    required String label,
    String submitLabel = 'Submit',
  }) async {
    final result = await showTextPromptDialog(
      context: context,
      title: title,
      label: label,
      submitLabel: submitLabel,
      obscureText: true,
    );
    return result?.isNotEmpty == true ? result : null;
  }
}
