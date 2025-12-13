import 'package:flutter/widgets.dart';

/// Lightweight helper to attach multi-touch gestures to the shell.
class GestureDetectorFactory {
  GestureDetectorFactory({this.onTripleTap, this.onTripleSwipeDown});

  final VoidCallback? onTripleTap;
  final VoidCallback? onTripleSwipeDown;

  final List<VoidCallback> _disposers = [];

  /// Wraps the given [child] with gesture detectors when callbacks exist.
  Widget wrap(BuildContext context, Widget child) {
    Widget current = child;
    if (onTripleTap != null) {
      current = _TripleTapDetector(onTripleTap: onTripleTap!, child: current);
    }
    if (onTripleSwipeDown != null) {
      current = _TripleSwipeDownDetector(
        onSwipe: onTripleSwipeDown!,
        child: current,
      );
    }
    return current;
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

class _TripleSwipeDownDetector extends StatefulWidget {
  const _TripleSwipeDownDetector({required this.onSwipe, required this.child});

  final VoidCallback onSwipe;
  final Widget child;

  @override
  State<_TripleSwipeDownDetector> createState() =>
      _TripleSwipeDownDetectorState();
}

class _TripleSwipeDownDetectorState extends State<_TripleSwipeDownDetector> {
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
    if (event.delta.dy > 12) {
      _triggered = true;
      widget.onSwipe();
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
