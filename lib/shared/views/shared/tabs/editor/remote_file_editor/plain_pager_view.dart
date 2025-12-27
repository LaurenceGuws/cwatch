import 'package:flutter/material.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:flutter/services.dart';

import 'match_markers.dart';
import 'search_match.dart';

class PlainPagerView extends StatefulWidget {
  const PlainPagerView({
    super.key,
    required this.text,
    required this.style,
    required this.focusNode,
    required this.showLineNumbers,
    required this.showControls,
    required this.matchLines,
    required this.matches,
    required this.activeMatchIndex,
    required this.matchColor,
    required this.activeMatchColor,
    this.onRegisterScrollToLine,
  });

  final String text;
  final TextStyle style;
  final FocusNode focusNode;
  final bool showLineNumbers;
  final bool showControls;
  final List<int> matchLines;
  final List<SearchMatch> matches;
  final int activeMatchIndex;
  final Color matchColor;
  final Color activeMatchColor;
  final void Function(Future<void> Function(int lineNumber) scrollToLine)?
  onRegisterScrollToLine;

  @override
  State<PlainPagerView> createState() => PlainPagerViewState();
}

class PlainPagerViewState extends State<PlainPagerView> {
  final ScrollController _scrollController = ScrollController();
  double _progress = 0;
  late List<String> _lines;
  double _lineHeight = 16;

  @override
  void initState() {
    super.initState();
    _lines = widget.text.split('\n');
    _updateLineHeight();
    _scrollController.addListener(_updateProgress);
    widget.onRegisterScrollToLine?.call(scrollToLine);
  }

  @override
  void didUpdateWidget(covariant PlainPagerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = widget.text.split('\n');
    }
    if (oldWidget.style != widget.style) {
      _updateLineHeight();
    }
    if (oldWidget.onRegisterScrollToLine != widget.onRegisterScrollToLine &&
        widget.onRegisterScrollToLine != null) {
      widget.onRegisterScrollToLine!(scrollToLine);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) {
      setState(() => _progress = 0);
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || position.maxScrollExtent == 0) {
      setState(() => _progress = 0);
      return;
    }
    final value = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    setState(() => _progress = value);
  }

  Future<void> _scrollTo(double offset) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pageBy(double multiplier) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final delta = position.viewportDimension * multiplier;
    await _scrollTo(position.pixels + delta);
  }

  void _updateLineHeight() {
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    _lineHeight = painter.height;
  }

  Future<void> scrollToLine(int lineNumber) async {
    if (!_scrollController.hasClients) return;
    final index = (lineNumber - 1).clamp(0, _lines.length - 1);
    final targetOffset = index * _lineHeight;
    await _scrollTo(targetOffset);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final percent = (_progress * 100).clamp(0, 100);
    final gutterWidth = widget.showLineNumbers
        ? (_lines.length.toString().length * 9.0)
        : 0.0;
    final activeLine =
        widget.activeMatchIndex >= 0 &&
            widget.activeMatchIndex < widget.matches.length
        ? widget.matches[widget.activeMatchIndex].lineNumber
        : null;
    final textOffsetX =
        widget.showLineNumbers ? gutterWidth + spacing.lg : 0.0;
    return FocusableActionDetector(
      autofocus: true,
      focusNode: widget.focusNode,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.home): const _JumpIntent(toTop: true),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.home):
            const _JumpIntent(toTop: true),
        LogicalKeySet(LogicalKeyboardKey.end): const _JumpIntent(toTop: false),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.end):
            const _JumpIntent(toTop: false),
      },
      actions: {
        _JumpIntent: CallbackAction<_JumpIntent>(
          onInvoke: (intent) async {
            if (intent.toTop) {
              await _scrollTo(0);
            } else if (_scrollController.hasClients) {
              await _scrollTo(_scrollController.position.maxScrollExtent);
            }
            return null;
          },
        ),
      },
      child: Column(
        children: [
          if (widget.showControls) ...[
            Container(
              padding: spacing.inset(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Top',
                    icon: const Icon(Icons.vertical_align_top, size: 18),
                    onPressed: () => _scrollTo(0),
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: () => _pageBy(-0.9),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: () => _pageBy(0.9),
                  ),
                  IconButton(
                    tooltip: 'Bottom',
                    icon: const Icon(Icons.vertical_align_bottom, size: 18),
                  onPressed: () async {
                    if (_scrollController.hasClients) {
                      await _scrollTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  },
                ),
                SizedBox(width: spacing.lg),
                Text('${percent.toStringAsFixed(0)}%'),
              ],
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
                return Stack(
                  children: [
                    Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(right: spacing.lg),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _InlineMatchPainter(
                                    lines: _lines,
                                    textStyle: widget.style,
                                    lineHeight: _lineHeight,
                                    textOffsetX: textOffsetX,
                                    matches: widget.matches,
                                    activeMatchIndex: widget.activeMatchIndex,
                                    matchColor: widget.matchColor,
                                    activeMatchColor: widget.activeMatchColor,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.showLineNumbers)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: spacing.lg,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: gutterWidth,
                                      ),
                                      child: Text(
                                        List.generate(
                                          _lines.length,
                                          (index) => '${index + 1}',
                                        ).join('\n'),
                                        textAlign: TextAlign.right,
                                        style: widget.style.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.7),
                                          height: widget.style.height ?? 1.2,
                                        ),
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: SelectableRegion(
                                    selectionControls:
                                        materialTextSelectionControls,
                                    child: Text(
                                      widget.text,
                                      style: widget.style.copyWith(
                                        height: widget.style.height ?? 1.2,
                                      ),
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: 8,
                      child: MatchMarkersRail(
                        lineCount: _lines.length,
                        matches: widget.matchLines,
                        color: widget.matchColor,
                        activeColor: widget.activeMatchColor,
                        activeLine: activeLine,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpIntent extends Intent {
  const _JumpIntent({required this.toTop});

  final bool toTop;
}

class _InlineMatchPainter extends CustomPainter {
  _InlineMatchPainter({
    required this.lines,
    required this.textStyle,
    required this.lineHeight,
    required this.textOffsetX,
    required this.matches,
    required this.activeMatchIndex,
    required this.matchColor,
    required this.activeMatchColor,
  });

  final List<String> lines;
  final TextStyle textStyle;
  final double lineHeight;
  final double textOffsetX;
  final List<SearchMatch> matches;
  final int activeMatchIndex;
  final Color matchColor;
  final Color activeMatchColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty || lines.isEmpty) return;
    final effectiveStyle = textStyle.copyWith(height: textStyle.height ?? 1.2);
    const direction = TextDirection.ltr;
    final matchPaint = Paint()..color = matchColor;
    final activePaint = Paint()..color = activeMatchColor;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final lineIndex = match.lineNumber - 1;
      if (lineIndex < 0 || lineIndex >= lines.length) continue;
      final lineText = lines[lineIndex];
      final endColumn = match.endColumn > lineText.length
          ? lineText.length
          : match.endColumn;
      final painter = TextPainter(
        text: TextSpan(text: lineText, style: effectiveStyle),
        textDirection: direction,
      )..layout();
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: match.startColumn, extentOffset: endColumn),
      );
      final paint = i == activeMatchIndex ? activePaint : matchPaint;
      for (final box in boxes) {
        final width = box.right - box.left;
        final height = box.bottom - box.top;
        final rect = Rect.fromLTWH(
          textOffsetX + box.left,
          (lineIndex * lineHeight) + box.top,
          width,
          height,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InlineMatchPainter oldDelegate) {
    return lineHeight != oldDelegate.lineHeight ||
        textOffsetX != oldDelegate.textOffsetX ||
        textStyle != oldDelegate.textStyle ||
        lines.length != oldDelegate.lines.length ||
        matchColor != oldDelegate.matchColor ||
        activeMatchColor != oldDelegate.activeMatchColor ||
        activeMatchIndex != oldDelegate.activeMatchIndex ||
        matches.length != oldDelegate.matches.length ||
        !_matchesEqual(matches, oldDelegate.matches);
  }

  bool _matchesEqual(List<SearchMatch> a, List<SearchMatch> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.start != right.start ||
          left.end != right.end ||
          left.lineNumber != right.lineNumber ||
          left.startColumn != right.startColumn) {
        return false;
      }
    }
    return true;
  }
}
