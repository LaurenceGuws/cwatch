import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tree_sitter/tree_sitter.dart';

import '../../../../services/code/tree_sitter_support.dart';

class CodeHighlightTheme {
  const CodeHighlightTheme({
    required this.keyword,
    required this.function,
    required this.type,
    required this.string,
    required this.comment,
    required this.number,
  });

  factory CodeHighlightTheme.fromScheme(ColorScheme scheme) {
    return CodeHighlightTheme(
      keyword: scheme.secondary,
      function: scheme.primary,
      type: scheme.tertiary,
      string: scheme.error,
      comment: scheme.outline,
      number: scheme.secondaryContainer,
    );
  }

  final Color keyword;
  final Color function;
  final Color type;
  final Color string;
  final Color comment;
  final Color number;
}

abstract class CodeSyntaxHighlighter {
  List<TextSpan> highlight(String source, TextStyle? baseStyle);
}

class PlainCodeHighlighter implements CodeSyntaxHighlighter {
  @override
  List<TextSpan> highlight(String source, TextStyle? baseStyle) {
    return [TextSpan(text: source, style: baseStyle)];
  }
}

class TreeSitterSyntaxHighlighter implements CodeSyntaxHighlighter {
  TreeSitterSyntaxHighlighter({required this.session, required this.theme});

  final TreeSitterSession session;
  final CodeHighlightTheme theme;

  Parser? get _parser => session.parser;

  @override
  List<TextSpan> highlight(String source, TextStyle? baseStyle) {
    if (_parser == null || source.isEmpty) {
      return [TextSpan(text: source, style: baseStyle)];
    }
    try {
      final tree = _parser!.parse(source);
      final spans = _collectSpans(tree.root, source);
      if (spans.isEmpty) {
        return [TextSpan(text: source, style: baseStyle)];
      }
      spans.sort((a, b) => a.start.compareTo(b.start));
      final filtered = <_HighlightSpan>[];
      for (final span in spans) {
        if (filtered.isEmpty || span.start >= filtered.last.end) {
          filtered.add(span);
        }
      }
      final children = <TextSpan>[];
      var cursor = 0;
      for (final span in filtered) {
        if (span.start > cursor) {
          children.add(
            TextSpan(
              text: source.substring(cursor, span.start),
              style: baseStyle,
            ),
          );
        }
        children.add(
          TextSpan(
            text: source.substring(span.start, span.end),
            style:
                baseStyle?.copyWith(color: span.style.color) ??
                TextStyle(color: span.style.color),
          ),
        );
        cursor = span.end;
      }
      if (cursor < source.length) {
        children.add(
          TextSpan(text: source.substring(cursor), style: baseStyle),
        );
      }
      return children;
    } catch (_) {
      return [TextSpan(text: source, style: baseStyle)];
    }
  }

  List<_HighlightSpan> _collectSpans(TSNode root, String source) {
    final converter = _ByteOffsetConverter(source);
    final spans = <_HighlightSpan>[];
    void visit(TSNode node) {
      if (node.isNull) return;
      final style = _styleForType(node.nodeType);
      final isLeaf = node.namedChildCount == 0;
      if (style != null && isLeaf) {
        final start = converter.toCharIndex(node.startByte);
        final end = converter.toCharIndex(node.endByte);
        if (end > start) {
          spans.add(_HighlightSpan(start: start, end: end, style: style));
        }
      }
      final childCount = node.namedChildCount;
      for (var i = 0; i < childCount; i++) {
        visit(node.namedChild(i));
      }
    }

    visit(root);
    return spans;
  }

  TextStyle? _styleForType(String rawType) {
    final type = rawType.toLowerCase();
    if (type.contains('comment')) {
      return TextStyle(color: theme.comment);
    }
    if (type.contains('string') || type.contains('char')) {
      return TextStyle(color: theme.string);
    }
    if (type.contains('number') || type.contains('float')) {
      return TextStyle(color: theme.number);
    }
    if (type.contains('keyword') ||
        type.contains('modifier') ||
        type.contains('operator')) {
      return TextStyle(color: theme.keyword);
    }
    if (type.contains('type') ||
        type.contains('class') ||
        type.contains('interface')) {
      return TextStyle(color: theme.type);
    }
    if (type.contains('function') ||
        type.contains('method') ||
        type.contains('property')) {
      return TextStyle(color: theme.function);
    }
    return null;
  }
}

class _HighlightSpan {
  _HighlightSpan({required this.start, required this.end, required this.style});

  final int start;
  final int end;
  final TextStyle style;
}

class _ByteOffsetConverter {
  _ByteOffsetConverter(String text) {
    var charIndex = 0;
    for (var i = 0; i < text.length; i++) {
      final character = text[i];
      final bytes = utf8.encode(character);
      for (var j = 0; j < bytes.length; j++) {
        _byteToChar.add(charIndex);
      }
      charIndex++;
    }
    _byteToChar.add(charIndex);
  }

  final List<int> _byteToChar = [];

  int toCharIndex(int byteOffset) {
    if (_byteToChar.isEmpty) return 0;
    if (byteOffset < 0) return 0;
    if (byteOffset >= _byteToChar.length) {
      return _byteToChar.last;
    }
    return _byteToChar[byteOffset];
  }
}
