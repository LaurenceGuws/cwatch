import 'package:flutter/material.dart';

class MatchMarkersRail extends StatelessWidget {
  const MatchMarkersRail({
    super.key,
    required this.lineCount,
    required this.matches,
    required this.color,
    required this.activeColor,
    required this.activeLine,
  });

  final int lineCount;
  final List<int> matches;
  final Color color;
  final Color activeColor;
  final int? activeLine;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _MatchMarkersPainter(
          lineCount: lineCount,
          matches: matches,
          color: color,
          activeColor: activeColor,
          activeLine: activeLine,
        ),
      ),
    );
  }
}

class _MatchMarkersPainter extends CustomPainter {
  _MatchMarkersPainter({
    required this.lineCount,
    required this.matches,
    required this.color,
    required this.activeColor,
    required this.activeLine,
  });

  final int lineCount;
  final List<int> matches;
  final Color color;
  final Color activeColor;
  final int? activeLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount == 0 || matches.isEmpty) return;
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    final activePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    for (final match in matches) {
      final safeLine = match.clamp(1, lineCount);
      final frac = (safeLine - 0.5) / lineCount;
      final dy = (size.height - 6) * frac.clamp(0.0, 1.0);
      final isActive = activeLine != null && safeLine == activeLine;
      canvas.drawLine(
        Offset(size.width - 1.5, dy),
        Offset(size.width - 1.5, dy + 8),
        isActive ? activePaint : basePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MatchMarkersPainter oldDelegate) {
    return lineCount != oldDelegate.lineCount ||
        color != oldDelegate.color ||
        activeColor != oldDelegate.activeColor ||
        activeLine != oldDelegate.activeLine ||
        matches.length != oldDelegate.matches.length ||
        !_listEquals(matches, oldDelegate.matches);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
