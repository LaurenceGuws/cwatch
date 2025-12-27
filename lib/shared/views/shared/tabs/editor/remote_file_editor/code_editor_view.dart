import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';


class CodeEditorView extends StatelessWidget {
  const CodeEditorView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.baseTextStyle,
    required this.themeStyles,
    required this.showLineNumbers,
    required this.highlightEnabled,
  });

  final CodeController controller;
  final FocusNode focusNode;
  final TextStyle baseTextStyle;
  final Map<String, TextStyle> themeStyles;
  final bool showLineNumbers;
  final bool highlightEnabled;

  @override
  Widget build(BuildContext context) {
    return CodeTheme(
      data: CodeThemeData(styles: themeStyles),
      child: CodeField(
        controller: controller,
        focusNode: focusNode,
        expands: true,
        maxLines: null,
        minLines: null,
        textStyle: baseTextStyle,
        gutterStyle: GutterStyle(
          showLineNumbers: showLineNumbers,
          showErrors: highlightEnabled,
          showFoldingHandles: highlightEnabled,
        ),
      ),
    );
  }
}
