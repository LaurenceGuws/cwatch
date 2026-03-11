import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/model/services/explorer_clipboard.dart';
import 'package:cwatch/model/shared/services/path_utils.dart';

import 'file_entry_list.dart';
import 'file_explorer_tab_actions.dart';
import 'selection_controller.dart';

class FileExplorerTabEntryInteractions {
  FileExplorerTabEntryInteractions({
    required this.controller,
    required this.selectionController,
    required this.actions,
    required this.listFocusNode,
    required this.scrollController,
    required this.markNeedsBuild,
  });

  final FileExplorerController controller;
  final SelectionController selectionController;
  final FileExplorerTabActions actions;
  final FocusNode listFocusNode;
  final ScrollController scrollController;
  final VoidCallback markNeedsBuild;

  Widget build(BuildContext context) {
    final sortedEntries = controller.currentSortedEntries();
    return FileEntryList(
      entries: sortedEntries,
      currentPath: controller.currentPath,
      selectedPaths: selectionController.selectedPaths,
      syncingPaths: controller.state.syncingPaths,
      refreshingPaths: controller.state.refreshingPaths,
      localEdits: controller.state.localEdits,
      rowHeight: controller.state.rowHeight,
      scrollController: scrollController,
      focusNode: listFocusNode,
      onEntryDoubleTap: actions.handleEntryDoubleTap,
      onEntryPointerDown: (event, entries, index, remotePath) {
        selectionController.handleEntryPointerDown(
          event,
          entries,
          index,
          remotePath,
          () => listFocusNode.requestFocus(),
          markNeedsBuild,
        );
      },
      onDragHover: (event, index, remotePath) {
        selectionController.handleDragHover(
          event,
          index,
          remotePath,
          markNeedsBuild,
        );
      },
      onStopDragSelection: selectionController.stopDragSelection,
      onEntryContextMenu: (entry, position) =>
          actions.showEntryContextMenu(context, entry, position),
      onBackgroundContextMenu: null,
      onKeyEvent: (node, event, entries) =>
          _handleListKeyEvent(node, event, entries),
      onSyncLocalEdit: actions.syncLocalEdit,
      onRefreshCacheFromServer: actions.refreshCacheFromServer,
      onClearCachedCopy: actions.clearCachedCopy,
      onStartOsDrag: (position) async {
        final selected = selectionController.getSelectedEntries(sortedEntries);
        if (selected.isEmpty) return;
        await controller.startOsDrag(
          globalPosition: position,
          entriesToDrag: selected,
        );
      },
      joinPath: PathUtils.joinPath,
    );
  }

  KeyEventResult _handleListKeyEvent(
    FocusNode node,
    KeyEvent event,
    List entries,
  ) {
    return selectionController.handleListKeyEvent(
      node,
      event,
      entries.cast(),
      markNeedsBuild,
      () {
        final selectedEntries = selectionController.getSelectedEntries(
          entries.cast(),
        );
        if (selectedEntries.isNotEmpty) {
          if (selectedEntries.length > 1) {
            unawaited(actions.handleMultiCopy(selectedEntries));
          } else {
            actions.handleClipboardSet(
              selectedEntries.first,
              ExplorerClipboardOperation.copy,
            );
          }
        }
      },
      () {
        final selectedEntries = selectionController.getSelectedEntries(
          entries.cast(),
        );
        if (selectedEntries.isNotEmpty) {
          if (selectedEntries.length > 1) {
            unawaited(actions.handleMultiCut(selectedEntries));
          } else {
            actions.handleClipboardSet(
              selectedEntries.first,
              ExplorerClipboardOperation.cut,
            );
          }
        }
      },
      () => actions.handlePaste(targetDirectory: controller.currentPath),
      () {
        final selectedEntries = selectionController.getSelectedEntries(
          entries.cast(),
        );
        if (selectedEntries.isNotEmpty) {
          if (selectedEntries.length > 1) {
            unawaited(
              actions.confirmMultiDelete(
                selectedEntries,
                permanent: SelectionController.isShiftPressed(),
              ),
            );
          } else {
            unawaited(
              actions.confirmDelete(
                selectedEntries.first,
                permanent: SelectionController.isShiftPressed(),
              ),
            );
          }
        }
      },
      () {
        final entry = selectionController.primarySelectedEntry(entries.cast());
        if (entry != null) {
          unawaited(actions.promptRename(entry));
        }
      },
    );
  }
}
