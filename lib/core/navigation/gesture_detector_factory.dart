import 'package:flutter/widgets.dart';

import '../../shared/gestures/gesture_activators.dart';
import '../../shared/gestures/gesture_service.dart';

/// Lightweight helper to attach multi-touch gestures to the shell.
class GestureDetectorFactory {
  GestureDetectorFactory({
    this.tripleTapActivator = Gestures.commandPaletteTripleTap,
    this.swipeDownActivators = const [
      Gestures.viewsFocusDownSwipe,
      Gestures.commandPaletteTripleSwipeDown,
    ],
    this.swipeUpActivators = const [Gestures.viewsFocusUpSwipe],
    this.swipeLeftActivators = const [Gestures.tabsPreviousSwipe],
    this.swipeRightActivators = const [Gestures.tabsNextSwipe],
  });

  final GestureActivator? tripleTapActivator;
  final List<GestureActivator> swipeDownActivators;
  final List<GestureActivator> swipeUpActivators;
  final List<GestureActivator> swipeLeftActivators;
  final List<GestureActivator> swipeRightActivators;

  final List<VoidCallback> _disposers = [];

  /// Wraps the given [child] with gesture detectors when callbacks exist.
  Widget wrap(BuildContext context, Widget child, {bool enabled = true}) {
    if (!enabled) return child;
    Widget current = child;
    if (tripleTapActivator != null) {
      current = _TripleTapDetector(
        onTripleTap: () => _dispatch([tripleTapActivator!]),
        child: current,
      );
    }
    final swipeActivators = {
      _SwipeDirection.down: swipeDownActivators,
      _SwipeDirection.up: swipeUpActivators,
      _SwipeDirection.left: swipeLeftActivators,
      _SwipeDirection.right: swipeRightActivators,
    };
    final hasSwipeHandlers = swipeActivators.values.any(
      (activators) => activators.isNotEmpty,
    );
    if (hasSwipeHandlers) {
      current = _TripleSwipeDetector(
        onSwipe: (direction) => _dispatch(swipeActivators[direction] ?? []),
        child: current,
      );
    }
    return current;
  }

  void _dispatch(List<GestureActivator> activators) {
    for (final activator in activators) {
      final handled = GestureService.instance.handle(activator);
      if (handled) {
        return;
      }
    }
  }

  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
  }
}

class _TripleTapDetector extends StatefulWidget {
  const _TripleTapDetector({required this.onTripleTap, required this.child});

  final VoidCallback onTripleTap;
  final Widget child;

  @override
  State<_TripleTapDetector> createState() => _TripleTapDetectorState();
}

class _TripleTapDetectorState extends State<_TripleTapDetector> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _handleTapDown(TapDownDetails details) {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(milliseconds: 450)) {
      _tapCount = 0;
    }
    _tapCount += 1;
    _lastTap = now;
    if (_tapCount == 3) {
      _tapCount = 0;
      widget.onTripleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      child: widget.child,
    );
  }
}

enum _SwipeDirection { left, right, up, down }

class _TripleSwipeDetector extends StatefulWidget {
  const _TripleSwipeDetector({required this.onSwipe, required this.child});

  final ValueChanged<_SwipeDirection> onSwipe;
  final Widget child;

  @override
  State<_TripleSwipeDetector> createState() => _TripleSwipeDetectorState();
}

class _TripleSwipeDetectorState extends State<_TripleSwipeDetector> {
  int _activePointers = 0;
  bool _triggered = false;

  void _onPointerDown(PointerDownEvent event) {
    _activePointers += 1;
    _triggered = false;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _triggered = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _triggered = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_triggered || _activePointers < 3) return;
    final dx = event.delta.dx;
    final dy = event.delta.dy;
    const threshold = 12;
    if (dy > threshold) {
      _triggered = true;
      widget.onSwipe(_SwipeDirection.down);
    } else if (dy < -threshold) {
      _triggered = true;
      widget.onSwipe(_SwipeDirection.up);
    } else if (dx < -threshold) {
      _triggered = true;
      widget.onSwipe(_SwipeDirection.left);
    } else if (dx > threshold) {
      _triggered = true;
      widget.onSwipe(_SwipeDirection.right);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onPointerMove: _onPointerMove,
      child: widget.child,
    );
  }
}
