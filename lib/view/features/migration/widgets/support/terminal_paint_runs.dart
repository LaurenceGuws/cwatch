class TerminalPaintCell {
  const TerminalPaintCell({
    required this.codepoint,
    required this.width,
    required this.fgArgb,
    required this.bgArgb,
  });

  final int codepoint;
  final int width;
  final int fgArgb;
  final int bgArgb;
}

class TerminalBackgroundRun {
  const TerminalBackgroundRun({
    required this.startCol,
    required this.endColExclusive,
    required this.bgArgb,
  });

  final int startCol;
  final int endColExclusive;
  final int bgArgb;
}

class TerminalForegroundRun {
  const TerminalForegroundRun({
    required this.startCol,
    required this.endColExclusive,
    required this.fgArgb,
    required this.text,
  });

  final int startCol;
  final int endColExclusive;
  final int fgArgb;
  final String text;
}

class TerminalFallbackGlyph {
  const TerminalFallbackGlyph({
    required this.col,
    required this.width,
    required this.fgArgb,
    required this.codepoint,
  });

  final int col;
  final int width;
  final int fgArgb;
  final int codepoint;
}

class TerminalRowPaintPlan {
  const TerminalRowPaintPlan({
    required this.backgroundRuns,
    required this.foregroundRuns,
    required this.fallbackGlyphs,
  });

  final List<TerminalBackgroundRun> backgroundRuns;
  final List<TerminalForegroundRun> foregroundRuns;
  final List<TerminalFallbackGlyph> fallbackGlyphs;
}

class TerminalPaintRuns {
  const TerminalPaintRuns._();

  static TerminalRowPaintPlan planRow({
    required List<TerminalPaintCell> cells,
    required int cols,
  }) {
    final backgroundRuns = <TerminalBackgroundRun>[];
    final foregroundRuns = <TerminalForegroundRun>[];
    final fallbackGlyphs = <TerminalFallbackGlyph>[];

    if (cols <= 0 || cells.isEmpty) {
      return TerminalRowPaintPlan(
        backgroundRuns: backgroundRuns,
        foregroundRuns: foregroundRuns,
        fallbackGlyphs: fallbackGlyphs,
      );
    }

    var col = 0;
    while (col < cols) {
      final cell = cells[col];
      final runColor = cell.bgArgb;
      var end = col + 1;
      while (end < cols && cells[end].bgArgb == runColor) {
        end++;
      }
      backgroundRuns.add(
        TerminalBackgroundRun(
          startCol: col,
          endColExclusive: end,
          bgArgb: runColor,
        ),
      );
      col = end;
    }

    col = 0;
    while (col < cols) {
      final cell = cells[col];
      if (_eligibleForTextRun(cell)) {
        final fg = cell.fgArgb;
        final sb = StringBuffer()..writeCharCode(cell.codepoint);
        final start = col;
        col++;
        while (col < cols) {
          final next = cells[col];
          if (!_eligibleForTextRun(next) || next.fgArgb != fg) {
            break;
          }
          sb.writeCharCode(next.codepoint);
          col++;
        }
        foregroundRuns.add(
          TerminalForegroundRun(
            startCol: start,
            endColExclusive: col,
            fgArgb: fg,
            text: sb.toString(),
          ),
        );
        continue;
      }

      if (_eligibleForFallbackGlyph(cell)) {
        fallbackGlyphs.add(
          TerminalFallbackGlyph(
            col: col,
            width: cell.width <= 1 ? 1 : 2,
            fgArgb: cell.fgArgb,
            codepoint: cell.codepoint,
          ),
        );
      }
      col++;
    }

    return TerminalRowPaintPlan(
      backgroundRuns: backgroundRuns,
      foregroundRuns: foregroundRuns,
      fallbackGlyphs: fallbackGlyphs,
    );
  }

  static bool _eligibleForTextRun(TerminalPaintCell cell) {
    if (cell.width != 1) {
      return false;
    }
    return _isPrintable(cell.codepoint);
  }

  static bool _eligibleForFallbackGlyph(TerminalPaintCell cell) {
    if (cell.width == 0) {
      return false;
    }
    return _isPrintable(cell.codepoint);
  }

  static bool _isPrintable(int codepoint) {
    return codepoint >= 32 && codepoint != 127;
  }
}
