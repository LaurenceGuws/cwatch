import 'package:cwatch/view/core/tabs/tab_host.dart';
import 'workspace_tab.dart';

abstract class TabbedWorkspaceController
    extends TabHostController<WorkspaceTab> {
  TabbedWorkspaceController({required super.baseTabBuilder})
    : super(tabId: (tab) => tab.id);

  bool _isRestored = false;
  bool get isRestored => _isRestored;

  bool _suspendPersist = false;

  T runWithoutPersist<T>(T Function() action) {
    final previous = _suspendPersist;
    _suspendPersist = true;
    try {
      return action();
    } finally {
      _suspendPersist = previous;
    }
  }

  void addOrReplaceCurrent(
    WorkspaceTab tab, {
    required bool Function(WorkspaceTab current) shouldReplace,
  }) {
    if (tabs.isNotEmpty && selectedIndex >= 0 && selectedIndex < tabs.length) {
      final current = tabs[selectedIndex];
      if (shouldReplace(current)) {
        replaceTab(current.id, tab);
        return;
      }
    }
    addTab(tab);
  }

  // Override methods to hook persistence

  @override
  void addTab(WorkspaceTab tab) {
    super.addTab(tab);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void select(int index) {
    super.select(index);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void replaceBaseTab(WorkspaceTab tab) {
    super.replaceBaseTab(tab);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void replaceTab(String id, WorkspaceTab replacement) {
    super.replaceTab(id, replacement);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void closeTab(int index, {WorkspaceTab? baseReplacement}) {
    super.closeTab(index, baseReplacement: baseReplacement);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void reorder(int oldIndex, int newIndex) {
    super.reorder(oldIndex, newIndex);
    if (!_suspendPersist) {
      persistState();
    }
  }

  @override
  void replaceAll(List<WorkspaceTab> tabs, {int selectedIndex = 0}) {
    super.replaceAll(tabs, selectedIndex: selectedIndex);
    _isRestored = true;
  }

  Future<void> restoreState();
  Future<void> persistState();
}
