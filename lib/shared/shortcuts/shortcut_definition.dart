import 'shortcut_actions.dart';

enum ShortcutCategory { global, terminal, tabs, editor, docker }

class ShortcutDefinition {
  const ShortcutDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.defaultBinding,
  });

  final String id;
  final String label;
  final String description;
  final ShortcutCategory category;
  final String defaultBinding;
}

class ShortcutCatalog {
  static const definitions = <ShortcutDefinition>[
    ShortcutDefinition(
      id: ShortcutActions.terminalCopy,
      label: 'Copy',
      description: 'Copy selection (or all output when nothing is selected).',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+c',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalPaste,
      label: 'Paste',
      description: 'Paste clipboard contents into the terminal.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+v',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalSelectAll,
      label: 'Select all',
      description: 'Select the visible buffer contents.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+a',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollLineUp,
      label: 'Scroll up (line)',
      description: 'Scroll up by a small step.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+arrowup',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollLineDown,
      label: 'Scroll down (line)',
      description: 'Scroll down by a small step.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+arrowdown',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollPageUp,
      label: 'Scroll up (page)',
      description: 'Scroll up by a page.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+pageup',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollPageDown,
      label: 'Scroll down (page)',
      description: 'Scroll down by a page.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+pagedown',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollToTop,
      label: 'Scroll to top',
      description: 'Jump to the start of the buffer.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+home',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalScrollToBottom,
      label: 'Scroll to bottom',
      description: 'Jump to the end of the buffer.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+end',
    ),
  ];

  static Iterable<ShortcutDefinition> byCategory(ShortcutCategory category) =>
      definitions.where((d) => d.category == category);

  static ShortcutDefinition? find(String id) {
    for (final definition in definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}
