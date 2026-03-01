import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/features/migration/widgets/support/editor_caret_layout.dart';

const TextStyle _style = TextStyle(
  fontFamily: 'JetBrainsMono Nerd Font Mono',
  fontSize: 12,
  height: 1.2,
);

void main() {
  test('primary caret starts at origin for offset 0', () {
    final layout = EditorCaretLayout.compute(
      text: 'abc',
      primaryOffset: 0,
      auxiliaryOffsets: const [],
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 300,
      style: _style,
    );

    expect(layout.primaryCaret.dx, inInclusiveRange(-2.0, 2.0));
    expect(layout.primaryCaret.dy, inInclusiveRange(-2.0, 2.0));
    expect(layout.lineHeight, greaterThan(0));
  });

  test('caret wraps to next visual line with constrained width', () {
    final layout = EditorCaretLayout.compute(
      text: '01234567890123456789',
      primaryOffset: 18,
      auxiliaryOffsets: const [],
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 60,
      style: _style,
    );

    expect(layout.primaryCaret.dy, greaterThan(0));
  });

  test('text scaling increases line height', () {
    final base = EditorCaretLayout.compute(
      text: 'line',
      primaryOffset: 4,
      auxiliaryOffsets: const [],
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 300,
      style: _style,
    );
    final zoomed = EditorCaretLayout.compute(
      text: 'line',
      primaryOffset: 4,
      auxiliaryOffsets: const [],
      textScaler: const TextScaler.linear(1.5),
      maxWidth: 300,
      style: _style,
    );

    expect(zoomed.lineHeight, greaterThan(base.lineHeight));
  });

  test('returns one auxiliary caret position per auxiliary offset', () {
    final layout = EditorCaretLayout.compute(
      text: 'abcdef',
      primaryOffset: 2,
      auxiliaryOffsets: const [1, 4, 6],
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 300,
      style: _style,
    );

    expect(layout.auxiliaryCarets.length, 3);
  });

  test('point maps to near-start offset at top-left', () {
    final offset = EditorCaretLayout.offsetFromPoint(
      text: 'abcdef',
      point: const Offset(0, 0),
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 300,
      style: _style,
    );
    expect(offset, inInclusiveRange(0, 1));
  });

  test('point lower in wrapped text maps to larger offset', () {
    final firstLine = EditorCaretLayout.offsetFromPoint(
      text: '01234567890123456789',
      point: const Offset(5, 0),
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 60,
      style: _style,
    );
    final secondLine = EditorCaretLayout.offsetFromPoint(
      text: '01234567890123456789',
      point: const Offset(5, 40),
      textScaler: const TextScaler.linear(1.0),
      maxWidth: 60,
      style: _style,
    );
    expect(secondLine, greaterThan(firstLine));
  });
}
