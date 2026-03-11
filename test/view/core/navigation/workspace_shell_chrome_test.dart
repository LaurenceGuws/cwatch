import 'package:cwatch/view/core/navigation/command_palette_registry.dart';
import 'package:cwatch/view/core/navigation/tab_navigation_registry.dart';
import 'package:cwatch/view/core/navigation/workspace_shell_chrome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('register and unregister manage both shell registries', () {
    final chrome = WorkspaceShellChrome(
      moduleId: 'test-module',
      tabNavigator: TabNavigationHandle(
        next: () => true,
        previous: () => true,
      ),
      commandPaletteHandle: CommandPaletteHandle(loader: () => const []),
    );

    chrome.register();
    expect(TabNavigationRegistry.instance.forModule('test-module'), isNotNull);
    expect(CommandPaletteRegistry.instance.forModule('test-module'), isNotNull);

    chrome.unregister();
    expect(TabNavigationRegistry.instance.forModule('test-module'), isNull);
    expect(CommandPaletteRegistry.instance.forModule('test-module'), isNull);
  });
}
