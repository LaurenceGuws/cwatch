import 'dart:math' as math;

import 'package:flutter/material.dart';

class TerminalPaintLayout {
  const TerminalPaintLayout({
    required this.scale,
    required this.cellWidth,
    required this.cellHeight,
    required this.gridWidth,
    required this.gridHeight,
    required this.originX,
    required this.originY,
  });

  final double scale;
  final double cellWidth;
  final double cellHeight;
  final double gridWidth;
  final double gridHeight;
  final double originX;
  final double originY;

  static TerminalPaintLayout compute({
    required Size size,
    required int rows,
    required int cols,
    required double modelCellWidth,
    required double modelCellHeight,
  }) {
    final fitScaleX = (size.width / (cols * modelCellWidth)).clamp(
      0.01,
      double.infinity,
    );
    final fitScaleY = (size.height / (rows * modelCellHeight)).clamp(
      0.01,
      double.infinity,
    );
    final scale = math.min(fitScaleX, fitScaleY);
    final cellWidth = modelCellWidth * scale;
    final cellHeight = modelCellHeight * scale;
    final gridWidth = cols * cellWidth;
    final gridHeight = rows * cellHeight;
    final originX = (size.width - gridWidth) / 2;
    final originY = (size.height - gridHeight) / 2;
    return TerminalPaintLayout(
      scale: scale,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      originX: originX,
      originY: originY,
    );
  }

  static TerminalPaintLayout computeFill({
    required Size size,
    required int rows,
    required int cols,
  }) {
    final safeCols = cols <= 0 ? 1 : cols;
    final safeRows = rows <= 0 ? 1 : rows;
    final cellWidth = size.width / safeCols;
    final cellHeight = size.height / safeRows;
    final scale = (cellWidth / 8.0 + cellHeight / 16.0) / 2.0;
    return TerminalPaintLayout(
      scale: scale,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      gridWidth: size.width,
      gridHeight: size.height,
      originX: 0,
      originY: 0,
    );
  }

  Rect cellRect({required int row, required int col}) {
    return Rect.fromLTWH(
      originX + col * cellWidth,
      originY + row * cellHeight,
      cellWidth,
      cellHeight,
    );
  }
}
