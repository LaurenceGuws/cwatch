import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/features/migration/widgets/support/editor_text_navigation.dart';

void main() {
  test('normalized selection returns ordered clamped range', () {
    final range = EditorTextNavigation.normalizedSelectionRange(
      anchor: 12,
      focus: 4,
      maxLength: 10,
    );
    expect(range, isNotNull);
    expect(range!.start, 4);
    expect(range.end, 10);
  });

  test('normalized selection returns null for empty or missing values', () {
    expect(
      EditorTextNavigation.normalizedSelectionRange(
        anchor: null,
        focus: 2,
        maxLength: 10,
      ),
      isNull,
    );
    expect(
      EditorTextNavigation.normalizedSelectionRange(
        anchor: 5,
        focus: 5,
        maxLength: 10,
      ),
      isNull,
    );
  });

  test('line start and end offsets are resolved for middle of line', () {
    const text = 'one\ntwo three\nfour';
    const offset = 8; // inside "two three"
    expect(EditorTextNavigation.lineStartOffset(text, offset), 4);
    expect(EditorTextNavigation.lineEndOffset(text, offset), 13);
  });

  test('vertical move keeps column when possible', () {
    const text = 'alpha\nbeta\ngamma';
    const offsetInBeta = 8; // "t" in beta, column 2
    final up = EditorTextNavigation.verticalMoveOffset(text, offsetInBeta, -1);
    final down = EditorTextNavigation.verticalMoveOffset(text, offsetInBeta, 1);

    expect(up, 2);
    expect(down, 13);
  });

  test('word offsets jump over punctuation and spaces', () {
    const text = 'foo,   bar_baz  qux';
    expect(EditorTextNavigation.previousWordOffset(text, 13), 7);
    expect(EditorTextNavigation.nextWordOffset(text, 4), 14);
  });

  test('ctrl+backspace range removes previous word chunk', () {
    const text = 'foo,   bar_baz  qux';
    final range = EditorTextNavigation.previousWordDeleteRange(text, 13);
    expect(range, isNotNull);
    expect(range!.start, 7);
    expect(range.end, 13);
  });

  test('ctrl+delete range removes next word chunk', () {
    const text = 'foo,   bar_baz  qux';
    final range = EditorTextNavigation.nextWordDeleteRange(text, 4);
    expect(range, isNotNull);
    expect(range!.start, 4);
    expect(range.end, 14);
  });

  test('delete ranges return null at boundaries', () {
    const text = 'abc';
    expect(EditorTextNavigation.previousWordDeleteRange(text, 0), isNull);
    expect(EditorTextNavigation.nextWordDeleteRange(text, text.length), isNull);
  });
}
