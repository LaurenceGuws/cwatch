import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/view/features/migration/widgets/support/terminal_paint_layout.dart';

void main() {
  test('compute chooses limiting scale and centers grid', () {
    final layout = TerminalPaintLayout.compute(
      size: const Size(400, 200),
      rows: 10,
      cols: 20,
      modelCellWidth: 8,
      modelCellHeight: 16,
    );

    expect(layout.scale, closeTo(1.25, 0.001));
    expect(layout.cellWidth, closeTo(10, 0.001));
    expect(layout.cellHeight, closeTo(20, 0.001));
    expect(layout.gridWidth, closeTo(200, 0.001));
    expect(layout.gridHeight, closeTo(200, 0.001));
    expect(layout.originX, closeTo(100, 0.001));
    expect(layout.originY, closeTo(0, 0.001));
  });

  test('cell rect maps row/col to pixel bounds', () {
    final layout = TerminalPaintLayout.compute(
      size: const Size(320, 160),
      rows: 10,
      cols: 20,
      modelCellWidth: 8,
      modelCellHeight: 16,
    );

    final rect = layout.cellRect(row: 2, col: 3);
    expect(rect.left, closeTo(layout.originX + 3 * layout.cellWidth, 0.001));
    expect(rect.top, closeTo(layout.originY + 2 * layout.cellHeight, 0.001));
    expect(rect.width, closeTo(layout.cellWidth, 0.001));
    expect(rect.height, closeTo(layout.cellHeight, 0.001));
  });

  test('compute fill uses full size without aspect lock', () {
    final layout = TerminalPaintLayout.computeFill(
      size: const Size(600, 200),
      rows: 10,
      cols: 20,
    );

    expect(layout.originX, 0);
    expect(layout.originY, 0);
    expect(layout.gridWidth, closeTo(600, 0.001));
    expect(layout.gridHeight, closeTo(200, 0.001));
    expect(layout.cellWidth, closeTo(30, 0.001));
    expect(layout.cellHeight, closeTo(20, 0.001));
  });
}
