import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller that centralizes focus + selection handling for list views.
class SelectableListController extends ChangeNotifier {
  SelectableListController({this.allowMultiSelect = false, int? initialFocus})
    : _focusedIndex = initialFocus;

  final bool allowMultiSelect;
  int _itemCount = 0;
  int? _focusedIndex;
  int? _anchorIndex;
  final Set<int> _selectedIndices = <int>{};

  int? get focusedIndex => _focusedIndex;
  Set<int> get selectedIndices => Set.unmodifiable(_selectedIndices);

  /// Set the current item count so focus/selection can be clamped.
  void setItemCount(int count) {
    if (count == _itemCount) return;
    _itemCount = count;
    final changed = _pruneOutOfRange();
    if (changed) {
      notifyListeners();
    }
  }

  /// Focus a specific index without changing selection.
  void focus(int? index) {
    final clamped = _clampIndex(index);
    if (_focusedIndex == clamped) return;
    _focusedIndex = clamped;
    notifyListeners();
  }

  /// Clear selection and select only [index]. Also sets the anchor for shift+range.
  void selectSingle(int index) {
    final clamped = _clampIndex(index);
    if (clamped == null) return;
    _selectedIndices
      ..clear()
      ..add(clamped);
    _anchorIndex = clamped;
    _focusedIndex = clamped;
    notifyListeners();
  }

  /// Toggle selection for [index]; replaces selection when multi-select is off.
  void toggle(int index) {
    final clamped = _clampIndex(index);
    if (clamped == null) return;
    if (!allowMultiSelect) {
      selectSingle(clamped);
      return;
    }
    if (_selectedIndices.contains(clamped)) {
      _selectedIndices.remove(clamped);
    } else {
      _selectedIndices.add(clamped);
    }
    _anchorIndex = clamped;
    _focusedIndex = clamped;
    notifyListeners();
  }

  /// Extend selection from anchor/focus to [index] (Shift-like behavior).
  void extendSelection(int index) {
    final clamped = _clampIndex(index);
    if (clamped == null) return;
    if (!allowMultiSelect) {
      selectSingle(clamped);
      return;
    }
    final start = _anchorIndex ?? _focusedIndex ?? clamped;
    final lower = math.min(start, clamped);
    final upper = math.max(start, clamped);
    _selectedIndices
      ..clear()
      ..addAll(List<int>.generate(upper - lower + 1, (i) => lower + i));
    _focusedIndex = clamped;
    _anchorIndex = start;
    notifyListeners();
  }

  /// Move focus by [delta] and optionally ensure selection follows focus.
  void moveFocus(int delta, {bool selectOnFocus = true}) {
    if (_itemCount == 0) return;
    final next = (_focusedIndex ?? 0) + delta;
    focus(_clampIndex(next));
    if (selectOnFocus && _focusedIndex != null) {
      if (_selectedIndices.isEmpty) {
        selectSingle(_focusedIndex!);
      } else if (!allowMultiSelect) {
        selectSingle(_focusedIndex!);
      }
    }
  }

  /// Focus the first item and optionally select it.
  void focusFirst({bool select = false}) {
    if (_itemCount == 0) return;
    focus(0);
    if (select) {
      selectSingle(0);
    }
  }

  /// Focus the last item and optionally select it.
  void focusLast({bool select = false}) {
    if (_itemCount == 0) return;
    focus(_itemCount - 1);
    if (select) {
      selectSingle(_itemCount - 1);
    }
  }

  /// Remove selection/focus when indices go out of range.
  bool _pruneOutOfRange() {
    var changed = false;
    final before = _selectedIndices.length;
    _selectedIndices.removeWhere((index) => index >= _itemCount);
    if (_selectedIndices.length != before) changed = true;
    if (_focusedIndex != null && _focusedIndex! >= _itemCount) {
      _focusedIndex = _itemCount == 0 ? null : _itemCount - 1;
      changed = true;
    }
    if (_anchorIndex != null && _anchorIndex! >= _itemCount) {
      _anchorIndex = _itemCount == 0 ? null : _itemCount - 1;
      changed = true;
    }
    return changed;
  }

  int? _clampIndex(int? value) {
    if (value == null) return null;
    if (_itemCount == 0) return null;
    return value.clamp(0, _itemCount - 1);
  }
}

/// Intent + Actions to wire keyboard navigation into a SelectableListController.
class SelectableListKeyboardHandler extends StatefulWidget {
  const SelectableListKeyboardHandler({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.focusNode,
    required this.child,
    this.onActivate,
  });

  final SelectableListController controller;
  final int itemCount;
  final FocusNode focusNode;
  final Widget child;
  final void Function(int index)? onActivate;

  @override
  State<SelectableListKeyboardHandler> createState() =>
      _SelectableListKeyboardHandlerState();
}

class _SelectableListKeyboardHandlerState
    extends State<SelectableListKeyboardHandler> {
  @override
  void initState() {
    super.initState();
    widget.controller.setItemCount(widget.itemCount);
  }

  @override
  void didUpdateWidget(covariant SelectableListKeyboardHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      widget.controller.setItemCount(widget.itemCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.arrowDown):
          const _MoveSelectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp):
          const _MoveSelectionIntent(-1),
      const SingleActivator(LogicalKeyboardKey.home):
          const _JumpSelectionIntent(toEnd: false),
      const SingleActivator(LogicalKeyboardKey.end): const _JumpSelectionIntent(
        toEnd: true,
      ),
      const SingleActivator(LogicalKeyboardKey.space):
          const _ToggleSelectionIntent(),
      const SingleActivator(LogicalKeyboardKey.enter):
          const _ActivateSelectionIntent(),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
          const _ExtendSelectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
          const _ExtendSelectionIntent(-1),
    };

    final controller = widget.controller;
    final itemCount = widget.itemCount;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (_) => controller.setItemCount(itemCount),
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: {
            _MoveSelectionIntent: CallbackAction<_MoveSelectionIntent>(
              onInvoke: (intent) {
                controller.moveFocus(intent.delta);
                return null;
              },
            ),
            _JumpSelectionIntent: CallbackAction<_JumpSelectionIntent>(
              onInvoke: (intent) {
                if (itemCount == 0) return null;
                if (intent.toEnd) {
                  controller.focusLast(select: true);
                } else {
                  controller.focusFirst(select: true);
                }
                return null;
              },
            ),
            _ToggleSelectionIntent: CallbackAction<_ToggleSelectionIntent>(
              onInvoke: (intent) {
                final index = controller.focusedIndex;
                if (index != null) {
                  controller.toggle(index);
                }
                return null;
              },
            ),
            _ExtendSelectionIntent: CallbackAction<_ExtendSelectionIntent>(
              onInvoke: (intent) {
                if (itemCount == 0) return null;
                final target = (controller.focusedIndex ?? 0) + intent.delta;
                controller.extendSelection(target);
                return null;
              },
            ),
            _ActivateSelectionIntent: CallbackAction<_ActivateSelectionIntent>(
              onInvoke: (intent) {
                final index = controller.focusedIndex;
                if (index != null) {
                  widget.onActivate?.call(index);
                }
                return null;
              },
            ),
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _MoveSelectionIntent extends Intent {
  const _MoveSelectionIntent(this.delta);
  final int delta;
}

class _JumpSelectionIntent extends Intent {
  const _JumpSelectionIntent({required this.toEnd});
  final bool toEnd;
}

class _ToggleSelectionIntent extends Intent {
  const _ToggleSelectionIntent();
}

class _ExtendSelectionIntent extends Intent {
  const _ExtendSelectionIntent(this.delta);
  final int delta;
}

class _ActivateSelectionIntent extends Intent {
  const _ActivateSelectionIntent();
}
