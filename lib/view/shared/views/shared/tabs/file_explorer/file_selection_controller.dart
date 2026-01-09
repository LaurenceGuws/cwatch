import 'package:flutter/foundation.dart';

/// Controller for managing file selection state in the file explorer
class FileSelectionController extends ChangeNotifier {
  final Set<String> _selectedPaths = {};
  int? _selectionAnchorIndex;
  int? _lastSelectedIndex;
  bool _dragSelecting = false;
  bool _dragSelectionAdditive = true;

  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  int? get selectionAnchorIndex => _selectionAnchorIndex;
  int? get lastSelectedIndex => _lastSelectedIndex;
  bool get dragSelecting => _dragSelecting;
  bool get dragSelectionAdditive => _dragSelectionAdditive;

  bool isSelected(String path) => _selectedPaths.contains(path);

  void selectExclusive(String path, int index) {
    _selectedPaths
      ..clear()
      ..add(path);
    _selectionAnchorIndex = index;
    _lastSelectedIndex = index;
    notifyListeners();
  }

  void selectRange(
    List<String> paths,
    int startIndex,
    int endIndex, {
    bool additive = false,
  }) {
    final start = startIndex < endIndex ? startIndex : endIndex;
    final end = startIndex < endIndex ? endIndex : startIndex;
    final nextSelection = additive ? {..._selectedPaths} : <String>{};
    for (var i = start; i <= end; i++) {
      if (i >= 0 && i < paths.length) {
        nextSelection.add(paths[i]);
      }
    }
    _selectedPaths
      ..clear()
      ..addAll(nextSelection);
    _lastSelectedIndex = endIndex;
    notifyListeners();
  }

  void toggleSelection(String path, int index) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    _selectionAnchorIndex = index;
    _lastSelectedIndex = index;
    notifyListeners();
  }

  void selectAll(List<String> paths) {
    _selectedPaths
      ..clear()
      ..addAll(paths);
    _selectionAnchorIndex = paths.isEmpty ? null : 0;
    _lastSelectedIndex = paths.isEmpty ? null : paths.length - 1;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    _selectionAnchorIndex = null;
    _lastSelectedIndex = null;
    notifyListeners();
  }

  void startDragSelection({bool additive = true}) {
    _dragSelecting = true;
    _dragSelectionAdditive = additive;
  }

  void stopDragSelection() {
    _dragSelecting = false;
  }

  void updateDragSelection(String path, {bool? additive}) {
    if (!_dragSelecting) return;
    final add = additive ?? _dragSelectionAdditive;
    if (add) {
      _selectedPaths.add(path);
    } else {
      _selectedPaths.remove(path);
    }
    notifyListeners();
  }

  int resolveAnchorIndex(int fallback) {
    return _selectionAnchorIndex ?? _lastSelectedIndex ?? fallback;
  }

  int resolveFocusedIndex(
    List<String> allPaths,
    String Function(int) pathForIndex,
  ) {
    final last = _lastSelectedIndex;
    if (last != null && last >= 0 && last < allPaths.length) {
      return last;
    }
    for (var i = 0; i < allPaths.length; i++) {
      final path = pathForIndex(i);
      if (_selectedPaths.contains(path)) {
        return i;
      }
    }
    return 0;
  }
}
