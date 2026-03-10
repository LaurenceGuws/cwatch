import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:cwatch/model/models/remote_file_entry.dart';

/// Non-UI selection state and selection operations for the file explorer.
class ExplorerSelectionState {
  ExplorerSelectionState({required this.currentPath, required this.joinPath});

  String currentPath;
  final String Function(String, String) joinPath;

  final Set<String> selectedPaths = {};
  int? selectionAnchorIndex;
  int? lastSelectedIndex;
  bool dragSelecting = false;
  bool dragSelectionAdditive = true;

  void clearSelection() {
    selectedPaths.clear();
    selectionAnchorIndex = null;
    lastSelectedIndex = null;
  }

  void applySelection(
    List<RemoteFileEntry> entries,
    int index, {
    required bool shift,
    required bool multi,
    required VoidCallback setState,
  }) {
    if (entries.isEmpty || index < 0 || index >= entries.length) {
      return;
    }
    final path = joinPath(currentPath, entries[index].name);
    if (!shift && !multi && selectedPaths.contains(path)) {
      selectionAnchorIndex = index;
      lastSelectedIndex = index;
      setState();
      return;
    }
    if (shift) {
      selectRange(entries, index, additive: multi, setState: setState);
      return;
    }
    if (multi) {
      toggleSelection(entries, index, setState: setState);
      return;
    }
    selectExclusive(entries, index, setState: setState);
  }

  void handleKeyboardNavigation(
    List<RemoteFileEntry> entries,
    int targetIndex, {
    required bool shift,
    required bool multi,
    required VoidCallback setState,
  }) {
    if (entries.isEmpty) {
      return;
    }
    if (shift) {
      selectRange(entries, targetIndex, additive: multi, setState: setState);
      return;
    }
    if (multi) {
      lastSelectedIndex = targetIndex;
      selectionAnchorIndex = targetIndex;
      setState();
      return;
    }
    selectExclusive(entries, targetIndex, setState: setState);
  }

  void selectExclusive(
    List<RemoteFileEntry> entries,
    int index, {
    required VoidCallback setState,
  }) {
    final path = joinPath(currentPath, entries[index].name);
    selectedPaths
      ..clear()
      ..add(path);
    selectionAnchorIndex = index;
    lastSelectedIndex = index;
    setState();
  }

  void selectRange(
    List<RemoteFileEntry> entries,
    int index, {
    required bool additive,
    required VoidCallback setState,
  }) {
    if (entries.isEmpty) {
      return;
    }
    final anchor = resolveAnchorIndex(entries, index);
    final start = min(anchor, index);
    final end = max(anchor, index);
    final nextSelection = additive ? {...selectedPaths} : <String>{};
    for (var i = start; i <= end; i += 1) {
      nextSelection.add(joinPath(currentPath, entries[i].name));
    }
    selectedPaths
      ..clear()
      ..addAll(nextSelection);
    lastSelectedIndex = index;
    setState();
  }

  void toggleSelection(
    List<RemoteFileEntry> entries,
    int index, {
    required VoidCallback setState,
  }) {
    final path = joinPath(currentPath, entries[index].name);
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
    } else {
      selectedPaths.add(path);
    }
    selectionAnchorIndex = index;
    lastSelectedIndex = index;
    setState();
  }

  void selectAll(
    List<RemoteFileEntry> entries, {
    required VoidCallback setState,
  }) {
    selectedPaths
      ..clear()
      ..addAll(entries.map((entry) => joinPath(currentPath, entry.name)));
    selectionAnchorIndex = entries.isEmpty ? null : 0;
    lastSelectedIndex = entries.isEmpty ? null : entries.length - 1;
    setState();
  }

  RemoteFileEntry? primarySelectedEntry(List<RemoteFileEntry> entries) {
    if (selectedPaths.isEmpty) {
      return null;
    }
    return entryForRemotePath(entries, selectedPaths.first);
  }

  RemoteFileEntry? entryForRemotePath(
    List<RemoteFileEntry> entries,
    String remotePath,
  ) {
    for (final entry in entries) {
      if (joinPath(currentPath, entry.name) == remotePath) {
        return entry;
      }
    }
    return null;
  }

  List<RemoteFileEntry> getSelectedEntries(List<RemoteFileEntry> entries) {
    return entries
        .where(
          (entry) => selectedPaths.contains(joinPath(currentPath, entry.name)),
        )
        .toList();
  }

  int resolveAnchorIndex(List<RemoteFileEntry> entries, int fallback) {
    final anchor = selectionAnchorIndex ?? lastSelectedIndex ?? fallback;
    if (entries.isEmpty) {
      return 0;
    }
    return anchor.clamp(0, entries.length - 1);
  }

  int resolveFocusedIndex(List<RemoteFileEntry> entries) {
    final last = lastSelectedIndex;
    if (last != null && last >= 0 && last < entries.length) {
      return last;
    }
    for (var i = 0; i < entries.length; i += 1) {
      final path = joinPath(currentPath, entries[i].name);
      if (selectedPaths.contains(path)) {
        return i;
      }
    }
    return 0;
  }
}
