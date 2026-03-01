import 'package:flutter/material.dart';

class EditorCaretLayoutResult {
  const EditorCaretLayoutResult({
    required this.textPainter,
    required this.primaryCaret,
    required this.auxiliaryCarets,
    required this.lineHeight,
  });

  final TextPainter textPainter;
  final Offset primaryCaret;
  final List<Offset> auxiliaryCarets;
  final double lineHeight;
}

class EditorCaretLayout {
  const EditorCaretLayout._();

  static EditorCaretLayoutResult compute({
    required String text,
    required int primaryOffset,
    required List<int> auxiliaryOffsets,
    required TextScaler textScaler,
    required double maxWidth,
    required TextStyle style,
  }) {
    final normalizedText = text.isEmpty ? ' ' : text;
    final textPainter = TextPainter(
      text: TextSpan(text: normalizedText, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final safePrimary = primaryOffset.clamp(0, normalizedText.length);
    final primary = textPainter.getOffsetForCaret(
      TextPosition(offset: safePrimary),
      Rect.zero,
    );

    final auxiliary = <Offset>[];
    for (final offset in auxiliaryOffsets) {
      final safeOffset = offset.clamp(0, normalizedText.length);
      auxiliary.add(
        textPainter.getOffsetForCaret(
          TextPosition(offset: safeOffset),
          Rect.zero,
        ),
      );
    }

    return EditorCaretLayoutResult(
      textPainter: textPainter,
      primaryCaret: primary,
      auxiliaryCarets: auxiliary,
      lineHeight: textPainter.preferredLineHeight,
    );
  }

  static int offsetFromPoint({
    required String text,
    required Offset point,
    required TextScaler textScaler,
    required double maxWidth,
    required TextStyle style,
  }) {
    final normalizedText = text.isEmpty ? ' ' : text;
    final textPainter = TextPainter(
      text: TextSpan(text: normalizedText, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final position = textPainter.getPositionForOffset(point);
    return position.offset.clamp(0, normalizedText.length);
  }
}
