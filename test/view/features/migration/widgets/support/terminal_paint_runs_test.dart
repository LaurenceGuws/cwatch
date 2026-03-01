import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/features/migration/widgets/support/terminal_paint_runs.dart';

TerminalPaintCell _cell({
  required int cp,
  required int width,
  int fg = 0xFFFFFFFF,
  int bg = 0xFF000000,
}) {
  return TerminalPaintCell(codepoint: cp, width: width, fgArgb: fg, bgArgb: bg);
}

void main() {
  test('background runs merge contiguous colors', () {
    final cells = [
      _cell(cp: 65, width: 1, bg: 0xFF111111),
      _cell(cp: 66, width: 1, bg: 0xFF111111),
      _cell(cp: 67, width: 1, bg: 0xFF222222),
      _cell(cp: 68, width: 1, bg: 0xFF222222),
      _cell(cp: 69, width: 1, bg: 0xFF111111),
    ];
    final plan = TerminalPaintRuns.planRow(cells: cells, cols: cells.length);
    expect(plan.backgroundRuns.length, 3);
    expect(plan.backgroundRuns[0].startCol, 0);
    expect(plan.backgroundRuns[0].endColExclusive, 2);
    expect(plan.backgroundRuns[1].startCol, 2);
    expect(plan.backgroundRuns[1].endColExclusive, 4);
    expect(plan.backgroundRuns[2].startCol, 4);
    expect(plan.backgroundRuns[2].endColExclusive, 5);
  });

  test('foreground runs merge contiguous printable single-width glyphs', () {
    final cells = [
      _cell(cp: 65, width: 1, fg: 0xFFAAAAAA), // A
      _cell(cp: 66, width: 1, fg: 0xFFAAAAAA), // B
      _cell(cp: 67, width: 1, fg: 0xFFBBBBBB), // C new fg
      _cell(cp: 10, width: 1, fg: 0xFFBBBBBB), // non-printable break
      _cell(cp: 68, width: 1, fg: 0xFFBBBBBB), // D
    ];
    final plan = TerminalPaintRuns.planRow(cells: cells, cols: cells.length);
    expect(plan.foregroundRuns.length, 3);
    expect(plan.foregroundRuns[0].text, 'AB');
    expect(plan.foregroundRuns[0].startCol, 0);
    expect(plan.foregroundRuns[0].endColExclusive, 2);
    expect(plan.foregroundRuns[1].text, 'C');
    expect(plan.foregroundRuns[1].startCol, 2);
    expect(plan.foregroundRuns[2].text, 'D');
    expect(plan.foregroundRuns[2].startCol, 4);
  });

  test('wide glyphs are routed to fallback glyphs', () {
    final cells = [
      _cell(cp: 65, width: 1), // A normal
      _cell(cp: 0x4E2D, width: 2), // wide
      _cell(cp: 0, width: 0), // placeholder
      _cell(cp: 66, width: 1), // B normal
    ];
    final plan = TerminalPaintRuns.planRow(cells: cells, cols: cells.length);
    expect(plan.foregroundRuns.length, 2);
    expect(plan.foregroundRuns[0].text, 'A');
    expect(plan.foregroundRuns[1].text, 'B');
    expect(plan.fallbackGlyphs.length, 1);
    expect(plan.fallbackGlyphs.single.col, 1);
    expect(plan.fallbackGlyphs.single.width, 2);
    expect(plan.fallbackGlyphs.single.codepoint, 0x4E2D);
  });
}
