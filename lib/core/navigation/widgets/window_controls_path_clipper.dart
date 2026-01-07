import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Custom path clipper that excludes only the window controls button area
/// from the top-right corner, allowing content to use space to the left
/// and below the buttons.
class WindowControlsPathClipper extends CustomClipper<ui.Path> {
  const WindowControlsPathClipper({
    required this.buttonWidth,
    required this.buttonHeight,
  });

  final double buttonWidth;
  final double buttonHeight;

  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();

    path
      ..moveTo(0, 0)
      ..lineTo(size.width - buttonWidth, 0)
      ..lineTo(size.width - buttonWidth, buttonHeight)
      ..lineTo(size.width, buttonHeight)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(WindowControlsPathClipper oldClipper) {
    return oldClipper.buttonWidth != buttonWidth ||
        oldClipper.buttonHeight != buttonHeight;
  }
}
