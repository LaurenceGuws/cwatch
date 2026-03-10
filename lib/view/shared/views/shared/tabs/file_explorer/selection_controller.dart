import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';

/// Controller for managing file selection state and interactions
class SelectionController extends ExplorerSelectionState {
  SelectionController({required super.currentPath, required super.joinPath});

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

  static bool isShiftPressed() {
    return HardwareKeyboard.instance.isShiftPressed;
  }

  static bool isMultiSelectModifierPressed() {
    final hardware = HardwareKeyboard.instance;
    return hardware.isControlPressed || hardware.isMetaPressed;
  }
}
