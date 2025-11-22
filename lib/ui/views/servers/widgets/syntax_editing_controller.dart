import 'package:flutter/material.dart';

import 'code_highlighter.dart';

class SyntaxEditingController extends TextEditingController {
  SyntaxEditingController({
    required this.syntaxHighlighter,
    required super.text,
  });

  CodeSyntaxHighlighter syntaxHighlighter;

  void updateHighlighter(CodeSyntaxHighlighter newHighlighter) {
    syntaxHighlighter = newHighlighter;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    if (withComposing && value.isComposingRangeValid) {
      return TextSpan(style: style, text: text);
    }
    final spans = syntaxHighlighter.highlight(text, style);
    return TextSpan(style: style, children: spans);
  }
}

