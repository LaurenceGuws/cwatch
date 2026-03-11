import 'package:cwatch/controller/core/workspace/workspace_tab.dart';
import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/generic_tab_command_entries.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/workspace_shell_chrome.dart';
import 'package:cwatch/view/core/tabs/workspace_settings_sync.dart';

class WslViewShell {
  WslViewShell({
    required this.moduleId,
    required List<WorkspaceTab> Function() tabs,
    required int Function() selectedIndex,
    required void Function(int index) selectTab,
    required void Function(int index) closeTab,
    required Future<void> Function(int index) renameTab,
    required void Function() addPickerTab,
    required String? Function() persistedWorkspaceSignature,
    required String Function() currentWorkspaceSignature,
    required Future<void> Function() restoreWorkspace,
    required Future<void> Function() persistIfPending,
  }) : _tabs = tabs,
       _selectedIndex = selectedIndex,
       _selectTab = selectTab,
       _closeTab = closeTab,
       _renameTab = renameTab,
       _addPickerTab = addPickerTab,
       _persistedWorkspaceSignature = persistedWorkspaceSignature,
       _currentWorkspaceSignature = currentWorkspaceSignature,
       _restoreWorkspace = restoreWorkspace,
       _persistIfPending = persistIfPending;

  final String moduleId;
  final List<WorkspaceTab> Function() _tabs;
  final int Function() _selectedIndex;
  final void Function(int index) _selectTab;
  final void Function(int index) _closeTab;
  final Future<void> Function(int index) _renameTab;
  final void Function() _addPickerTab;
  final String? Function() _persistedWorkspaceSignature;
  final String Function() _currentWorkspaceSignature;
  final Future<void> Function() _restoreWorkspace;
  final Future<void> Function() _persistIfPending;
  final WorkspaceSettingsSync _settingsSync = const WorkspaceSettingsSync();

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

  Future<void> handleSettingsChanged() async {
    _settingsSync.handleSettingsChangedAsync(
      mounted: true,
      persistedSignature: _persistedWorkspaceSignature(),
      currentSignature: _currentWorkspaceSignature(),
      restoreWorkspace: _restoreWorkspace,
      persistIfPending: _persistIfPending,
    );
  }

  List<CommandPaletteEntry> buildCommandPaletteEntries() {
    final tabs = _tabs();
    final selectedIndex = _selectedIndex();
    return buildGenericTabCommandEntries(
      moduleId: moduleId,
      selectedTab: tabs.isNotEmpty ? tabs[selectedIndex] : null,
      onNewTab: _addPickerTab,
      onCloseTab: () => _closeTab(selectedIndex),
      onRenameTab: () {
        _renameTab(selectedIndex);
      },
    );
  }
}
