import 'dart:ui';
import 'package:flutter/painting.dart';

import 'package:xterm/src/ui/palette_builder.dart';
import 'package:xterm/src/ui/paragraph_cache.dart';
import 'package:xterm/xterm.dart';

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(10240);

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(
      textStyle.getTextStyle(textScaler: _textScaler),
    );
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    // Round up to whole pixels so cell extents never undershoot glyph bounds.
    final width = (paragraph.maxIntrinsicWidth / test.length).ceilToDouble();
    final height = paragraph.height.ceilToDouble();
    final result = Size(width, height);

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, _cellSize.height - 1),
          Offset(offset.dx + _cellSize.width, _cellSize.height - 1),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, 0),
          Offset(offset.dx, _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      paint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line,
  ) {
    final cellData = CellData.empty();
    final cellWidth = _cellSize.width;
    final runs = <_TextRun>[];
    _TextRun? currentRun;

    void flushRun() {
      if (currentRun == null) return;
      runs.add(currentRun!);
      currentRun = null;
    }

    var i = 0;
    while (i < line.length) {
      line.getCellData(i, cellData);

      final charWidth = cellData.content >> CellContent.widthShift;
      final cellOffset = offset.translate(i * cellWidth, 0);

      final bool isGridChar =
          _shouldPaintPerCell(cellData.content & CellContent.codepointMask);
      final Offset drawOffset = isGridChar
          ? Offset(
              cellOffset.dx.floorToDouble(),
              cellOffset.dy.floorToDouble(),
            )
          : cellOffset;

      paintCellBackground(canvas, drawOffset, cellData);

      // Keep existing rendering path for wide glyphs.
      if (charWidth == 2) {
        flushRun();
        paintCellForeground(canvas, cellOffset, cellData);
        i += 2;
        continue;
      }

      final charCode = cellData.content & CellContent.codepointMask;
      if (charCode == 0) {
        flushRun();
        i += 1;
        continue;
      }

       // Box drawing and block elements need strict per-cell positioning to keep
       // continuous lines; avoid batching these into paragraph runs.
      if (isGridChar) {
        flushRun();
        paintCellForeground(canvas, drawOffset, cellData);
        i += 1;
        continue;
      }

      final style = _cellStyle(cellData);
      final char = _characterForCell(charCode, style.underline);

      if (currentRun != null && currentRun!.canAppend(style)) {
        currentRun!.buffer.write(char);
      } else {
        flushRun();
        currentRun = _TextRun(
          start: i,
          style: style,
          buffer: StringBuffer(char),
        );
      }

      i += 1;
    }

    flushRun();

    for (final run in runs) {
      final paragraph = _buildParagraph(run.text, run.style);
      final runOffset = offset.translate(run.start * cellWidth, 0);
      canvas.drawParagraph(paragraph, runOffset);
      paragraph.dispose();
    }
  }

  _CellStyle _cellStyle(CellData cellData) {
    final cellFlags = cellData.flags;

    var color = cellFlags & CellFlags.inverse == 0
        ? _resolveForeground(cellData.foreground)
        : _resolveBackground(cellData.background);

    if (cellData.flags & CellFlags.faint != 0) {
      color = color.withOpacity(0.5);
    }

    return _CellStyle(
      color: color,
      bold: cellFlags & CellFlags.bold != 0,
      italic: cellFlags & CellFlags.italic != 0,
      underline: cellFlags & CellFlags.underline != 0,
    );
  }

  Color _resolveForeground(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  Color _resolveBackground(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  String _characterForCell(int charCode, bool underline) {
    // Ensure underlined spaces draw correctly.
    if (underline && charCode == 0x20) {
      return String.fromCharCode(0xA0);
    }
    return String.fromCharCode(charCode);
  }

  Paragraph _buildParagraph(String text, _CellStyle style) {
    final textStyle = _textStyle.toTextStyle(
      color: style.color,
      bold: style.bold,
      italic: style.italic,
      underline: style.underline,
    );
    final builder = ParagraphBuilder(textStyle.getParagraphStyle());
    builder.pushStyle(textStyle.getTextStyle(textScaler: _textScaler));
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));
    return paragraph;
  }

  bool _shouldPaintPerCell(int charCode) {
    // Box drawing (U+2500–U+257F) and block elements (U+2580–U+259F) should
    // stay aligned to the grid; render them individually.
    if (charCode >= 0x2500 && charCode <= 0x259F) {
      return true;
    }
    return false;
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(Canvas canvas, Offset offset, CellData cellData) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    final isBoxDrawing = _shouldPaintPerCell(charCode);
    final cacheKey =
        (cellData.getHash() ^ _textScaler.hashCode) ^ (isBoxDrawing ? 0xBD : 0);
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final cellFlags = cellData.flags;

      var color = cellFlags & CellFlags.inverse == 0
          ? resolveForegroundColor(cellData.foreground)
          : resolveBackgroundColor(cellData.background);

      if (cellData.flags & CellFlags.faint != 0) {
        color = color.withOpacity(0.5);
      }

      var style = _textStyle.toTextStyle(
        color: color,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: cellFlags & CellFlags.underline != 0,
      );

      // Flutter does not draw an underline below a space which is not between
      // other regular characters. As only single characters are drawn, this
      // will never produce an underline below a space in the terminal. As a
      // workaround the regular space CodePoint 0x20 is replaced with
      // the CodePoint 0xA0. This is a non breaking space and a underline can be
      // drawn below it.
      var char = String.fromCharCode(charCode);
      if (cellFlags & CellFlags.underline != 0 && charCode == 0x20) {
        char = String.fromCharCode(0xA0);
      }

      paragraph = _paragraphCache.performAndCacheLayout(
        char,
        style,
        _textScaler,
        cacheKey,
        maxWidth: isBoxDrawing ? _cellSize.width : null,
      );
    }

    canvas.drawParagraph(paragraph, offset);
  }

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(cellData.foreground);
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    final paint = Paint()..color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    // Slightly overdraw height to avoid visible seams between adjacent rows.
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height + 1);
    canvas.drawRect(offset & size, paint);
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

}

class _TextRun {
  _TextRun({
    required this.start,
    required this.style,
    required this.buffer,
  });

  final int start;
  final _CellStyle style;
  final StringBuffer buffer;

  String get text => buffer.toString();

  bool canAppend(_CellStyle other) => style == other;
}

class _CellStyle {
  const _CellStyle({
    required this.color,
    required this.bold,
    required this.italic,
    required this.underline,
  });

  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;

  @override
  int get hashCode => Object.hash(color.value, bold, italic, underline);

  @override
  bool operator ==(Object other) {
    return other is _CellStyle &&
        other.color.value == color.value &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline;
  }
}
