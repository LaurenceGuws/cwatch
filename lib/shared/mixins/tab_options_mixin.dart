import 'package:flutter/material.dart';

import '../views/shared/tabs/tab_chip.dart';

mixin TabOptionsMixin<T extends StatefulWidget> on State<T> {
  List<TabChipOption>? _pendingTabOptions;
  bool _optionsScheduled = false;

  void queueTabOptions(
    TabOptionsController? controller,
    List<TabChipOption> options, {
    bool useBase = false,
    bool useOverlay = false,
  }) {
    if (controller == null) {
      return;
    }
    _pendingTabOptions = options;
    if (_optionsScheduled) {
      return;
    }
    _optionsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _optionsScheduled = false;
      if (!mounted) {
        return;
      }
      final pending = _pendingTabOptions;
      if (pending == null) {
        return;
      }
      _pendingTabOptions = null;
      if (controller is CompositeTabOptionsController) {
        if (useOverlay) {
          controller.updateOverlay(pending);
        } else if (useBase) {
          controller.updateBase(pending);
        } else {
          controller.update(pending);
        }
      } else {
        controller.update(pending);
      }
    });
  }
}
