import 'package:flutter/foundation.dart';

/// Generic controller for tab hosts that tracks the list of tabs, selection,
/// and persistence state. Consumers provide tab IDs and a factory for the base
/// tab (e.g., picker).
class TabHostController<T> extends ChangeNotifier {
  TabHostController({required this.baseTabBuilder, required this.tabId})
    : _tabs = [baseTabBuilder()];

  final T Function() baseTabBuilder;
  final String Function(T tab) tabId;

  final List<T> _tabs;
  int _selectedIndex = 0;

  List<T> get tabs => List.unmodifiable(_tabs);
  int get selectedIndex => _selectedIndex;

  void select(int index) {
    _selectedIndex = index.clamp(0, _tabs.length - 1);
    notifyListeners();
  }

  void addTab(T tab) {
    _tabs.add(tab);
    _selectedIndex = _tabs.length - 1;
    notifyListeners();
  }

  void replaceBaseTab(T tab) {
    if (_tabs.isEmpty) {
      _tabs.add(tab);
      _selectedIndex = 0;
    } else {
      final existingId = tabId(_tabs.first);
      _tabs[0] = tab;
      if (_selectedIndex == 0) {
        _selectedIndex = 0;
      } else {
        _selectedIndex = _tabs.indexWhere(
          (candidate) => tabId(candidate) == existingId,
        );
      }
    }
    notifyListeners();
  }

  void replaceTab(String id, T replacement) {
    final index = _tabs.indexWhere((tab) => tabId(tab) == id);
    if (index == -1) return;
    _tabs[index] = replacement;
    _selectedIndex = index;
    notifyListeners();
  }

  void closeTab(int index, {T? baseReplacement}) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    _tabs.removeAt(index);
    final wasBase = index == 0;
    if (_tabs.isEmpty) {
      final replacement = baseReplacement ?? baseTabBuilder();
      _tabs.add(replacement);
      _selectedIndex = 0;
    } else if (_selectedIndex >= _tabs.length) {
      _selectedIndex = _tabs.length - 1;
    } else if (_selectedIndex > index) {
      _selectedIndex -= 1;
    }
    // If a base replacement is provided and we removed the base tab, swap it in.
    if (baseReplacement != null && wasBase) {
      _tabs[0] = baseReplacement;
      _selectedIndex = 0;
    }
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length) return;
    if (oldIndex == newIndex) return;
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);
    _selectedIndex = _tabs.indexWhere((candidate) => candidate == tab);
    notifyListeners();
  }

  T? tabById(String id) =>
      _tabs.firstWhere((tab) => tabId(tab) == id, orElse: () => null as T);

  void replaceAll(List<T> tabs, {int selectedIndex = 0}) {
    _tabs
      ..clear()
      ..addAll(tabs.isEmpty ? [baseTabBuilder()] : tabs);
    _selectedIndex = _tabs.isEmpty
        ? 0
        : selectedIndex.clamp(0, _tabs.length - 1);
    notifyListeners();
  }
}
