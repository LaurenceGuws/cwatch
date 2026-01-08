import 'package:flutter/foundation.dart';
import 'package:cwatch/core/tabs/tab_host.dart';
import 'workspace_tab.dart';

abstract class TabbedWorkspaceController
    extends TabHostController<WorkspaceTab> {
  TabbedWorkspaceController({required super.baseTabBuilder})
    : super(tabId: (tab) => tab.id);

  bool _isRestored = false;
  bool get isRestored => _isRestored;

  // Override methods to hook persistence

  @override
  void addTab(WorkspaceTab tab) {
    super.addTab(tab);
    persistState();
  }

  @override
  void select(int index) {
    super.select(index);
    persistState();
  }

  @override
  void replaceBaseTab(WorkspaceTab tab) {
    super.replaceBaseTab(tab);
    persistState();
  }

  @override
  void replaceTab(String id, WorkspaceTab replacement) {
    super.replaceTab(id, replacement);
    persistState();
  }

  @override
  void closeTab(int index, {WorkspaceTab? baseReplacement}) {
    super.closeTab(index, baseReplacement: baseReplacement);
    persistState();
  }

  @override
  void reorder(int oldIndex, int newIndex) {
    super.reorder(oldIndex, newIndex);
    persistState();
  }

  @override
  void replaceAll(List<WorkspaceTab> tabs, {int selectedIndex = 0}) {
    super.replaceAll(tabs, selectedIndex: selectedIndex);
    // Usually called during restore, so mark restored
    _isRestored = true;
    // Don't persist immediately on restore? Or do?
    // Usually restore sets the state to what matches persistence.
  }

  Future<void> restoreState();
  Future<void> persistState();
}
