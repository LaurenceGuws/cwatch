import 'package:flutter/material.dart';

import 'gesture_service.dart';

class GestureActions extends StatelessWidget {
  const GestureActions({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        _TriggerGestureIntent: CallbackAction<_TriggerGestureIntent>(
          onInvoke: (intent) {
            GestureService.instance.handle(intent.activator);
            return null;
          },
        ),
      },
      child: child,
    );
  }
}

class _TriggerGestureIntent extends Intent {
  const _TriggerGestureIntent(this.activator);
  final ShortcutActivator activator;
}
