import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowDragRegion extends StatelessWidget {
  const WindowDragRegion({super.key, this.child});

  final Widget? child;

  bool get _supportsCustomChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  void _startDrag() {
    if (!_supportsCustomChrome) return;
    windowManager.startDragging();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _startDrag(),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
