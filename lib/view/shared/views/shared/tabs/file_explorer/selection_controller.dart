import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cwatch/model/models/remote_file_entry.dart';
import 'package:cwatch/model/shared/services/explorer_selection_state.dart';

/// Controller for managing file selection state and interactions
class SelectionController {
  SelectionController({required ExplorerSelectionState state}) : _state = state;

  final ExplorerSelectionState _state;

  Set<String> get selectedPaths => _state.selectedPaths;

  RemoteFileEntry? primarySelectedEntry(List<RemoteFileEntry> entries) {
    return _state.primarySelectedEntry(entries);
  }

  List<RemoteFileEntry> getSelectedEntries(List<RemoteFileEntry> entries) {
    return _state.getSelectedEntries(entries);
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
      if (!_state.selectedPaths.contains(remotePath)) {
        _state.applySelection(
          entries,
          index,
          shift: false,
          multi: false,
          setState: setState,
        );
      }
      _state.dragSelecting = false;
      return;
    }

    _state.applySelection(
      entries,
      index,
      shift: shift,
      multi: multi,
      setState: setState,
    );

    if (isMouse && (event.buttons & kPrimaryMouseButton) != 0) {
      _state.dragSelecting = true;
      _state.dragSelectionAdditive = true;
    } else {
      _state.dragSelecting = false;
    }
  }

  void handleDragHover(
    PointerEnterEvent event,
    int index,
    String remotePath,
    VoidCallback setState,
  ) {
    if (!_state.dragSelecting || event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if ((event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }
    if (_state.dragSelectionAdditive) {
      _state.selectedPaths.add(remotePath);
    } else {
      _state.selectedPaths.remove(remotePath);
    }
    _state.lastSelectedIndex = index;
    setState();
  }

  void stopDragSelection() {
    _state.dragSelecting = false;
  }

  void replaceSelection(
    Iterable<RemoteFileEntry> entries,
    String Function(RemoteFileEntry entry) pathBuilder,
    VoidCallback setState,
  ) {
    _state.selectedPaths
      ..clear()
      ..addAll(entries.map(pathBuilder));
    _state.lastSelectedIndex = null;
    _state.dragSelecting = false;
    setState();
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
    if (!isCtrl && event.logicalKey == LogicalKeyboardKey.escape) {
      _state.selectedPaths.clear();
      _state.lastSelectedIndex = null;
      _state.dragSelecting = false;
      setState();
      return KeyEventResult.handled;
    }
    final currentIndex = _state.resolveFocusedIndex(entries);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        final next = (currentIndex + 1).clamp(0, entries.length - 1);
        if (next == currentIndex) {
          return KeyEventResult.handled;
        }
        _state.handleKeyboardNavigation(
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
        _state.handleKeyboardNavigation(
          entries,
          next,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _state.handleKeyboardNavigation(
          entries,
          0,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _state.handleKeyboardNavigation(
          entries,
          entries.length - 1,
          shift: shift,
          multi: multi,
          setState: setState,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        if (shift) {
          _state.selectRange(
            entries,
            currentIndex,
            additive: true,
            setState: setState,
          );
        } else {
          _state.toggleSelection(entries, currentIndex, setState: setState);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyA:
        if (multi) {
          _state.selectAll(entries, setState: setState);
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
