class EditorTextNavigation {
  const EditorTextNavigation._();

  static ({int start, int end})? normalizedSelectionRange({
    required int? anchor,
    required int? focus,
    required int maxLength,
  }) {
    if (anchor == null || focus == null) {
      return null;
    }
    final safeAnchor = anchor.clamp(0, maxLength);
    final safeFocus = focus.clamp(0, maxLength);
    if (safeAnchor == safeFocus) {
      return null;
    }
    return (
      start: safeAnchor < safeFocus ? safeAnchor : safeFocus,
      end: safeAnchor < safeFocus ? safeFocus : safeAnchor,
    );
  }

  static int lineStartOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    final index = text.lastIndexOf('\n', clamped - 1);
    return index < 0 ? 0 : index + 1;
  }

  static int lineEndOffset(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    final index = text.indexOf('\n', clamped);
    return index < 0 ? text.length : index;
  }

  static int verticalMoveOffset(String text, int offset, int direction) {
    final clamped = offset.clamp(0, text.length);
    final lineStart = lineStartOffset(text, clamped);
    final lineEnd = lineEndOffset(text, clamped);
    final column = clamped - lineStart;

    if (direction < 0) {
      if (lineStart == 0) {
        return clamped;
      }
      final prevEnd = lineStart - 1;
      final prevStart = lineStartOffset(text, prevEnd);
      return (prevStart + column).clamp(prevStart, prevEnd);
    }

    if (lineEnd >= text.length) {
      return clamped;
    }
    final nextStart = lineEnd + 1;
    final nextEnd = lineEndOffset(text, nextStart);
    return (nextStart + column).clamp(nextStart, nextEnd);
  }

  static int previousWordOffset(String text, int offset) {
    var i = offset.clamp(0, text.length);
    while (i > 0 && !_isWordChar(text.codeUnitAt(i - 1))) {
      i--;
    }
    while (i > 0 && _isWordChar(text.codeUnitAt(i - 1))) {
      i--;
    }
    return i;
  }

  static int nextWordOffset(String text, int offset) {
    var i = offset.clamp(0, text.length);
    while (i < text.length && !_isWordChar(text.codeUnitAt(i))) {
      i++;
    }
    while (i < text.length && _isWordChar(text.codeUnitAt(i))) {
      i++;
    }
    return i;
  }

  static ({int start, int end})? previousWordDeleteRange(
    String text,
    int offset,
  ) {
    final clamped = offset.clamp(0, text.length);
    if (clamped <= 0) {
      return null;
    }
    final start = previousWordOffset(text, clamped);
    if (start == clamped) {
      return (start: clamped - 1, end: clamped);
    }
    return (start: start, end: clamped);
  }

  static ({int start, int end})? nextWordDeleteRange(String text, int offset) {
    final clamped = offset.clamp(0, text.length);
    if (clamped >= text.length) {
      return null;
    }
    final end = nextWordOffset(text, clamped);
    if (end == clamped) {
      return (start: clamped, end: clamped + 1);
    }
    return (start: clamped, end: end);
  }

  static bool _isWordChar(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122) ||
        codeUnit == 95;
  }
}
