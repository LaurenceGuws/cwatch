import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

import 'match_markers.dart';

class CodeEditorView extends StatelessWidget {
  const CodeEditorView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.baseTextStyle,
    required this.themeStyles,
    required this.showLineNumbers,
    required this.highlightEnabled,
    required this.lineCount,
    required this.matchLines,
    required this.activeLine,
    required this.matchColor,
    required this.activeMatchColor,
  });

  final CodeController controller;
  final FocusNode focusNode;
  final TextStyle baseTextStyle;
  final Map<String, TextStyle> themeStyles;
  final bool showLineNumbers;
  final bool highlightEnabled;
  final int lineCount;
  final List<int> matchLines;
  final int? activeLine;
  final Color matchColor;
  final Color activeMatchColor;

  @override
  Widget build(BuildContext context) {
    return CodeTheme(
      data: CodeThemeData(styles: themeStyles),
      child: Stack(
        children: [
          CodeField(
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
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 8,
            child: MatchMarkersRail(
              lineCount: lineCount,
              matches: matchLines,
              color: matchColor,
              activeColor: activeMatchColor,
              activeLine: activeLine,
            ),
          ),
        ],
      ),
    );
  }
}
