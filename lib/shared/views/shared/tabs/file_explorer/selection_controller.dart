import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../models/remote_file_entry.dart';

/// Controller for managing file selection state and interactions
class SelectionController {
  SelectionController({required this.currentPath, required this.joinPath});

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

  void handleEntryPointerDown(
    PointerDownEvent event,
    List<RemoteFileEntry> entries,
    int index,
    String remotePath,
    VoidCallback requestFocus,
    VoidCallback setState,
  ) {
    requestFocus();
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final control = HardwareKeyboard.instance.isControlPressed;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final isTouch = event.kind == PointerDeviceKind.touch;
    final touchMulti = isTouch && selectedPaths.isNotEmpty;
    final multi = control || meta || touchMulti;
    final isMouse = event.kind == PointerDeviceKind.mouse;
    final isSecondaryClick =
        isMouse && (event.buttons & kSecondaryMouseButton) != 0;

    if (isSecondaryClick) {
      dragSelecting = false;
      return;
    }

    applySelection(
      entries,
      index,
      shift: shift,
      multi: multi,
      setState: setState,
    );

    if (isMouse && (event.buttons & kPrimaryMouseButton) != 0) {
      dragSelecting = true;
      dragSelectionAdditive = true;
    } else {
      dragSelecting = false;
    }
  }

  void handleDragHover(
    PointerEnterEvent event,
    int index,
    String remotePath,
    VoidCallback setState,
  ) {
    if (!dragSelecting || event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    if (dragSelectionAdditive) {
      selectedPaths.add(remotePath);
    } else {
      selectedPaths.remove(remotePath);
    }
    lastSelectedIndex = index;
    setState();
  }

  void stopDragSelection() {
    dragSelecting = false;
  }

  KeyEventResult handleListKeyEvent(
    FocusNode node,
    KeyEvent event,
    List<RemoteFileEntry> entries,
    VoidCallback setState,
    VoidCallback onCopy,
    VoidCallback onCut,
    VoidCallback onPaste,
    VoidCallback onDelete,
    VoidCallback onRename,
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
        onCopy();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyX) {
        onCut();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyV) {
        onPaste();
        return KeyEventResult.handled;
      }
    }
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.delete) {
      onDelete();
      return KeyEventResult.handled;
    }
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.f2) {
      onRename();
      return KeyEventResult.handled;
    }
    final currentIndex = resolveFocusedIndex(entries);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        final next = (currentIndex + 1).clamp(0, entries.length - 1);
        if (next == currentIndex) {
          return KeyEventResult.handled;
        }
        handleKeyboardNavigation(
          entries,
          next,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final next = (currentIndex - 1).clamp(0, entries.length - 1);
        if (next == currentIndex) {
          return KeyEventResult.handled;
        }
        handleKeyboardNavigation(
          entries,
          next,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        handleKeyboardNavigation(
          entries,
          0,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        handleKeyboardNavigation(
          entries,
          entries.length - 1,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        if (shift) {
          selectRange(
            entries,
            currentIndex,
            additive: true,
            setState: setState,
          );
        } else {
          toggleSelection(entries, currentIndex, setState: setState);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyA:
        if (multi) {
          selectAll(entries, setState: setState);
          return KeyEventResult.handled;
        }
        break;
      default:
        break;
    }
    return KeyEventResult.ignored;
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

  static bool isShiftPressed() {
    return HardwareKeyboard.instance.isShiftPressed;
  }

  static bool isMultiSelectModifierPressed() {
    final hardware = HardwareKeyboard.instance;
    return hardware.isControlPressed || hardware.isMetaPressed;
  }
}
