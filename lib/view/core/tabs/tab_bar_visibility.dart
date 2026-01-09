import 'package:flutter/foundation.dart';

/// Global controller to show/hide tab bars across workspaces (servers, docker,
/// k8s, etc.). UI consumers can listen to [value] and rebuild.
class TabBarVisibilityController extends ValueNotifier<bool> {
  TabBarVisibilityController._() : super(true);

  static final TabBarVisibilityController instance =
      TabBarVisibilityController._();

  void show() {
    if (!value) value = true;
  }

  void hide() {
    if (value) value = false;
  }

  void toggle() => value = !value;
}
