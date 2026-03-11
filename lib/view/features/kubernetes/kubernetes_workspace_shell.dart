import 'dart:async';

import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/model/models/kubernetes/kubeconfig_context.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/generic_tab_command_entries.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/workspace_shell_chrome.dart';

class KubernetesWorkspaceShell {
  KubernetesWorkspaceShell({
    required this.moduleId,
    required Future<List<KubeconfigContext>> Function() loadContexts,
    required void Function(Future<List<KubeconfigContext>> contextsFuture)
    setContextsFuture,
    required List<WorkspaceTab> Function() tabs,
    required int Function() selectedIndex,
    required void Function(int index) selectTab,
    required void Function(int index) closeTab,
    required void Function(String tabId, WorkspaceTab replacement) replaceTab,
    required void Function(WorkspaceTab tab) addTab,
    required WorkspaceTab Function({String? id}) createPlaceholderTab,
    required WorkspaceTab Function({
      required KubeconfigContext context,
      String? id,
      String? customName,
    })
    createContextTab,
    required bool Function(WorkspaceTab tab) isPlaceholder,
    required String? Function() persistedWorkspaceSignature,
    required String Function() currentWorkspaceSignature,
    required Future<void> Function() restoreWorkspace,
    required Future<void> Function() persistIfPending,
    required Future<void> Function() persistState,
    required void Function(void Function() action) runWithoutPersist,
  }) : _loadContexts = loadContexts,
       _setContextsFuture = setContextsFuture,
       _tabs = tabs,
       _selectedIndex = selectedIndex,
       _selectTab = selectTab,
       _closeTab = closeTab,
       _replaceTab = replaceTab,
       _addTab = addTab,
       _createPlaceholderTab = createPlaceholderTab,
       _createContextTab = createContextTab,
       _isPlaceholder = isPlaceholder,
       _persistedWorkspaceSignature = persistedWorkspaceSignature,
       _currentWorkspaceSignature = currentWorkspaceSignature,
       _restoreWorkspace = restoreWorkspace,
       _persistIfPending = persistIfPending,
       _persistState = persistState,
       _runWithoutPersist = runWithoutPersist;

  final String moduleId;
  final Future<List<KubeconfigContext>> Function() _loadContexts;
  final void Function(Future<List<KubeconfigContext>> contextsFuture)
  _setContextsFuture;
  final List<WorkspaceTab> Function() _tabs;
  final int Function() _selectedIndex;
  final void Function(int index) _selectTab;
  final void Function(int index) _closeTab;
  final void Function(String tabId, WorkspaceTab replacement) _replaceTab;
  final void Function(WorkspaceTab tab) _addTab;
  final WorkspaceTab Function({String? id}) _createPlaceholderTab;
  final WorkspaceTab Function({
    required KubeconfigContext context,
    String? id,
    String? customName,
  })
  _createContextTab;
  final bool Function(WorkspaceTab tab) _isPlaceholder;
  final String? Function() _persistedWorkspaceSignature;
  final String Function() _currentWorkspaceSignature;
  final Future<void> Function() _restoreWorkspace;
  final Future<void> Function() _persistIfPending;
  final Future<void> Function() _persistState;
  final void Function(void Function() action) _runWithoutPersist;

  late final TabNavigationHandle tabNavigator = TabNavigationHandle(
    next: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      _selectTab((_selectedIndex() + 1) % length);
      return true;
    },
    previous: () {
      final length = _tabs().length;
      if (length <= 1) return false;
      _selectTab((_selectedIndex() - 1 + length) % length);
      return true;
    },
  );

  late final CommandPaletteHandle commandPaletteHandle = CommandPaletteHandle(
    loader: buildCommandPaletteEntries,
  );
  late final WorkspaceShellChrome _shellChrome = WorkspaceShellChrome(
    moduleId: moduleId,
    tabNavigator: tabNavigator,
    commandPaletteHandle: commandPaletteHandle,
  );

  void initializeWorkspaceChrome() {
    _shellChrome.register();
  }

  void dispose() {
    _shellChrome.unregister();
  }

  Future<List<KubeconfigContext>> initializeContexts() {
    final future = _loadContexts();
    _setContextsFuture(future);
    return future;
  }

  Future<void> handleSettingsChanged() async {
    refreshContexts();

    final persistedSignature = _persistedWorkspaceSignature();
    if (persistedSignature != null &&
        persistedSignature != _currentWorkspaceSignature()) {
      await _restoreWorkspace();
    }

    await _persistIfPending();
  }

  void refreshContexts() {
    _setContextsFuture(_loadContexts());

    final placeholderIds = _tabs()
        .where(_isPlaceholder)
        .map((t) => t.id)
        .toList(growable: false);

    _runWithoutPersist(() {
      for (final id in placeholderIds) {
        _replaceTab(id, _createPlaceholderTab(id: id));
      }
    });

    unawaited(_persistState());
  }

  List<CommandPaletteEntry> buildCommandPaletteEntries() {
    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    return buildGenericTabCommandEntries(
      moduleId: moduleId,
      selectedTab: tabs.isNotEmpty ? tabs[selectedIndex] : null,
      onNewTab: startEmptyTab,
      onCloseTab: () => _closeTab(selectedIndex),
    );
  }

  void startEmptyTab() {
    _addTab(_createPlaceholderTab());
  }

  void openContextTab(KubeconfigContext context, {String? replaceTabId}) {
    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    final replacementId =
        replaceTabId ??
        (selectedIndex >= 0 &&
                selectedIndex < tabs.length &&
                _isPlaceholder(tabs[selectedIndex])
            ? tabs[selectedIndex].id
            : null);

    final tab = _createContextTab(
      context: context,
      id: replacementId,
      customName: null,
    );

    if (replacementId != null) {
      _replaceTab(replacementId, tab);
      return;
    }

    if (selectedIndex >= 0 &&
        selectedIndex < tabs.length &&
        _isPlaceholder(tabs[selectedIndex])) {
      _replaceTab(tabs[selectedIndex].id, tab);
      return;
    }

    _addTab(tab);
  }
}
