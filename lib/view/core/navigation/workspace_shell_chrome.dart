import 'command_palette_registry.dart';
import 'tab_navigation_registry.dart';

class WorkspaceShellChrome {
  const WorkspaceShellChrome({
    required this.moduleId,
    required this.tabNavigator,
    required this.commandPaletteHandle,
  });

  final String moduleId;
  final TabNavigationHandle tabNavigator;
  final CommandPaletteHandle commandPaletteHandle;

  void register() {
    TabNavigationRegistry.instance.register(moduleId, tabNavigator);
    CommandPaletteRegistry.instance.register(moduleId, commandPaletteHandle);
  }

  void unregister() {
    TabNavigationRegistry.instance.unregister(moduleId, tabNavigator);
    CommandPaletteRegistry.instance.unregister(moduleId, commandPaletteHandle);
  }
}
