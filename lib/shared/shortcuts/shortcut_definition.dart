import 'shortcut_actions.dart';

enum ShortcutCategory { global, terminal, tabs, editor, docker, grid }

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
      id: ShortcutActions.terminalOpenScrollback,
      label: 'Open scrollback in editor',
      description: 'Open the current terminal buffer in an editor tab.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+e',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalOpenScrollback,
      label: 'Open scrollback in editor',
      description: 'Open current terminal scrollback in an editor tab.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+e',
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
    ShortcutDefinition(
      id: ShortcutActions.terminalZoomIn,
      label: 'Zoom in',
      description: 'Increase terminal font size.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+=',
    ),
    ShortcutDefinition(
      id: ShortcutActions.terminalZoomOut,
      label: 'Zoom out',
      description: 'Decrease terminal font size.',
      category: ShortcutCategory.terminal,
      defaultBinding: 'ctrl+shift+_',
    ),
    ShortcutDefinition(
      id: ShortcutActions.editorZoomIn,
      label: 'Zoom in',
      description: 'Increase editor font size.',
      category: ShortcutCategory.editor,
      defaultBinding: 'ctrl+shift+=',
    ),
    ShortcutDefinition(
      id: ShortcutActions.editorZoomOut,
      label: 'Zoom out',
      description: 'Decrease editor font size.',
      category: ShortcutCategory.editor,
      defaultBinding: 'ctrl+shift+_',
    ),
    ShortcutDefinition(
      id: ShortcutActions.globalZoomIn,
      label: 'Zoom in',
      description: 'Increase interface zoom.',
      category: ShortcutCategory.global,
      defaultBinding: 'ctrl+shift+=',
    ),
    ShortcutDefinition(
      id: ShortcutActions.globalZoomOut,
      label: 'Zoom out',
      description: 'Decrease interface zoom.',
      category: ShortcutCategory.global,
      defaultBinding: 'ctrl+shift+_',
    ),
    ShortcutDefinition(
      id: ShortcutActions.globalCommandPalette,
      label: 'Command palette',
      description: 'Open the global command palette.',
      category: ShortcutCategory.global,
      defaultBinding: 'f1',
    ),
    ShortcutDefinition(
      id: ShortcutActions.tabsPrevious,
      label: 'Previous tab',
      description: 'Switch to the tab on the left.',
      category: ShortcutCategory.tabs,
      defaultBinding: 'alt+arrowleft',
    ),
    ShortcutDefinition(
      id: ShortcutActions.tabsNext,
      label: 'Next tab',
      description: 'Switch to the tab on the right.',
      category: ShortcutCategory.tabs,
      defaultBinding: 'alt+arrowright',
    ),
    ShortcutDefinition(
      id: ShortcutActions.viewsFocusUp,
      label: 'Focus previous view',
      description: 'Move focus to the previous view/pane.',
      category: ShortcutCategory.tabs,
      defaultBinding: 'alt+arrowup',
    ),
    ShortcutDefinition(
      id: ShortcutActions.viewsFocusDown,
      label: 'Focus next view',
      description: 'Move focus to the next view/pane.',
      category: ShortcutCategory.tabs,
      defaultBinding: 'alt+arrowdown',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridMoveLeft,
      label: 'Move left',
      description: 'Move to the previous cell.',
      category: ShortcutCategory.grid,
      defaultBinding: 'arrowleft',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridMoveRight,
      label: 'Move right',
      description: 'Move to the next cell.',
      category: ShortcutCategory.grid,
      defaultBinding: 'arrowright',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridMoveUp,
      label: 'Move up',
      description: 'Move to the cell above.',
      category: ShortcutCategory.grid,
      defaultBinding: 'arrowup',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridMoveDown,
      label: 'Move down',
      description: 'Move to the cell below.',
      category: ShortcutCategory.grid,
      defaultBinding: 'arrowdown',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridExtendLeft,
      label: 'Extend left',
      description: 'Extend selection to the left.',
      category: ShortcutCategory.grid,
      defaultBinding: 'shift+arrowleft',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridExtendRight,
      label: 'Extend right',
      description: 'Extend selection to the right.',
      category: ShortcutCategory.grid,
      defaultBinding: 'shift+arrowright',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridExtendUp,
      label: 'Extend up',
      description: 'Extend selection upward.',
      category: ShortcutCategory.grid,
      defaultBinding: 'shift+arrowup',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridExtendDown,
      label: 'Extend down',
      description: 'Extend selection downward.',
      category: ShortcutCategory.grid,
      defaultBinding: 'shift+arrowdown',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridEditToggle,
      label: 'Toggle edit mode',
      description: 'Enter or exit cell edit mode.',
      category: ShortcutCategory.grid,
      defaultBinding: 'f2',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridSelectRow,
      label: 'Select row',
      description: 'Select the current row.',
      category: ShortcutCategory.grid,
      defaultBinding: 'shift+space',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridSelectColumn,
      label: 'Select column',
      description: 'Select the current column.',
      category: ShortcutCategory.grid,
      defaultBinding: 'ctrl+space',
    ),
    ShortcutDefinition(
      id: ShortcutActions.gridSelectAll,
      label: 'Select all',
      description: 'Select all cells.',
      category: ShortcutCategory.grid,
      defaultBinding: 'ctrl+a',
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
