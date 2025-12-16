import 'package:flutter/widgets.dart';

/// Provides window control widgets (e.g., minimize/maximize/close) to consumers
/// like tab bars so they can render inline.
class WindowControlsScope extends InheritedWidget {
  const WindowControlsScope({
    super.key,
    required this.trailing,
    required super.child,
  });

  /// Widget to render inline with tab bars (e.g., window buttons).
  final Widget? trailing;

  static WindowControlsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowControlsScope>();
  }

  @override
  bool updateShouldNotify(covariant WindowControlsScope oldWidget) {
    return oldWidget.trailing != trailing;
  }
}
