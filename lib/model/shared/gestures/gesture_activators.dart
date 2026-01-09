import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../shortcuts/shortcut_definition.dart';

/// Identifier-based activator used for touch gestures.
class GestureActivator extends ShortcutActivator {
  const GestureActivator(this.id, {this.label});

  /// Unique id for the gesture.
  final String id;

  /// Human readable description of the gesture trigger.
  final String? label;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) => false;

  @override
  String debugDescribeKeys() => label ?? id;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    return other is GestureActivator && other.id == id;
  }

  @override
  String toString() => label ?? id;
}

/// Stable gesture identifiers to mirror [ShortcutActions].
class Gestures {
  // Global
  static const commandPaletteTripleTap = GestureActivator(
    'global.commandPalette.tripleTap',
    label: 'Triple tap',
  );
  static const commandPaletteTripleSwipeDown = GestureActivator(
    'global.commandPalette.tripleSwipeDown',
    label: '3-finger swipe down',
  );
  static const tabsNextSwipe = GestureActivator(
    'tabs.next.swipeLeft',
    label: '3-finger swipe left',
  );
  static const tabsPreviousSwipe = GestureActivator(
    'tabs.previous.swipeRight',
    label: '3-finger swipe right',
  );
  static const viewsFocusUpSwipe = GestureActivator(
    'views.focusUp.swipeUp',
    label: '3-finger swipe up',
  );
  static const viewsFocusDownSwipe = GestureActivator(
    'views.focusDown.swipeDown',
    label: '3-finger swipe down',
  );

  static const globalPinchZoom = GestureActivator(
    'global.pinchZoom',
    label: 'Pinch to zoom interface',
  );

  // Terminal (remote + docker)
  static const terminalPinchZoom = GestureActivator(
    'terminal.pinchZoom',
    label: 'Pinch to zoom',
  );
  static const terminalLongPressMenu = GestureActivator(
    'terminal.longPressMenu',
    label: 'Long press',
  );
  static const dockerTerminalPinchZoom = GestureActivator(
    'dockerTerminal.pinchZoom',
    label: 'Pinch to zoom',
  );
  static const dockerTerminalLongPressMenu = GestureActivator(
    'dockerTerminal.longPressMenu',
    label: 'Long press',
  );

  // Editor
  static const editorPinchZoom = GestureActivator(
    'editor.pinchZoom',
    label: 'Pinch to zoom',
  );
}

class GestureDefinition {
  const GestureDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
  });

  final GestureActivator id;
  final String label;
  final String description;
  final ShortcutCategory category;
}

class GestureCatalog {
  static const definitions = <GestureDefinition>[
    GestureDefinition(
      id: Gestures.commandPaletteTripleTap,
      label: 'Open command palette',
      description: 'Triple tap anywhere in the shell.',
      category: ShortcutCategory.global,
    ),
    GestureDefinition(
      id: Gestures.commandPaletteTripleSwipeDown,
      label: 'Open command palette',
      description: 'Swipe down with three fingers.',
      category: ShortcutCategory.global,
    ),
    GestureDefinition(
      id: Gestures.tabsNextSwipe,
      label: 'Next tab',
      description: 'Three-finger swipe left.',
      category: ShortcutCategory.tabs,
    ),
    GestureDefinition(
      id: Gestures.tabsPreviousSwipe,
      label: 'Previous tab',
      description: 'Three-finger swipe right.',
      category: ShortcutCategory.tabs,
    ),
    GestureDefinition(
      id: Gestures.viewsFocusDownSwipe,
      label: 'Focus next view',
      description: 'Three-finger swipe down.',
      category: ShortcutCategory.tabs,
    ),
    GestureDefinition(
      id: Gestures.viewsFocusUpSwipe,
      label: 'Focus previous view',
      description: 'Three-finger swipe up.',
      category: ShortcutCategory.tabs,
    ),
    GestureDefinition(
      id: Gestures.terminalPinchZoom,
      label: 'Terminal zoom',
      description: 'Pinch to adjust terminal font size.',
      category: ShortcutCategory.terminal,
    ),
    GestureDefinition(
      id: Gestures.globalPinchZoom,
      label: 'App zoom',
      description: 'Pinch to change the app interface zoom.',
      category: ShortcutCategory.global,
    ),
    GestureDefinition(
      id: Gestures.terminalLongPressMenu,
      label: 'Terminal menu',
      description: 'Long press to open copy/paste/select controls.',
      category: ShortcutCategory.terminal,
    ),
    GestureDefinition(
      id: Gestures.dockerTerminalPinchZoom,
      label: 'Docker terminal zoom',
      description: 'Pinch to adjust terminal font size.',
      category: ShortcutCategory.docker,
    ),
    GestureDefinition(
      id: Gestures.dockerTerminalLongPressMenu,
      label: 'Docker terminal menu',
      description: 'Long press to open copy/paste/select controls.',
      category: ShortcutCategory.docker,
    ),
    GestureDefinition(
      id: Gestures.editorPinchZoom,
      label: 'Editor zoom',
      description: 'Pinch to change editor font size.',
      category: ShortcutCategory.editor,
    ),
  ];

  static GestureDefinition? find(GestureActivator activator) {
    for (final definition in definitions) {
      if (definition.id == activator) return definition;
    }
    return null;
  }
}
