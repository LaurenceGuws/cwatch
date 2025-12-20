import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/nerd_fonts.dart';
import '../lists/selectable_list_controller.dart';

/// Declarative column definition for [StructuredDataTable].
class StructuredDataColumn<T> {
  const StructuredDataColumn({
    required this.label,
    required this.cellBuilder,
    this.tooltip,
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
    this.width,
    this.minWidth,
    this.sortValue,
    this.autoFitText,
    this.autoFitTextStyle,
    this.autoFitWidth,
    this.autoFitExtraWidth,
    this.wrap = false,
  });

  final String label;
  final String? tooltip;
  final int flex;
  final Alignment alignment;
  final double? width;
  final double? minWidth;
  final Comparable<Object?>? Function(T row)? sortValue;
  final String Function(T row)? autoFitText;
  final TextStyle? autoFitTextStyle;
  final double Function(BuildContext context, T row)? autoFitWidth;
  final double? autoFitExtraWidth;
  final bool wrap;
  final Widget Function(BuildContext context, T row) cellBuilder;
}

/// Context menu or inline action for a table row.
class StructuredDataAction<T> {
  const StructuredDataAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final void Function(T row) onSelected;
  final bool enabled;
  final bool destructive;
}

/// Small pill used to surface entry metadata (state, tags, counts, etc).
class StructuredDataChip {
  const StructuredDataChip({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;
}

/// Location of a selected cell in a [StructuredDataTable].
class StructuredDataCellCoordinate {
  const StructuredDataCellCoordinate({
    required this.rowIndex,
    required this.columnIndex,
  });

  final int rowIndex;
  final int columnIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StructuredDataCellCoordinate &&
        rowIndex == other.rowIndex &&
        columnIndex == other.columnIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);
}

/// A flexible, list-backed data table with keyboard navigation, selection, and
/// contextual actions. Designed for complex lists like servers, clusters, and
/// explorer entries that need rich metadata and right-click menus.
class StructuredDataTable<T> extends StatefulWidget {
  StructuredDataTable({
    super.key,
    required this.rows,
    required this.columns,
    this.verticalController,
    this.horizontalController,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onSelectionChanged,
    this.onSortChanged,
    this.onColumnsReordered,
    this.rowActions = const [],
    this.metadataBuilder,
    this.emptyState,
    this.allowMultiSelect = true,
    this.rowHeight = 60,
    this.headerHeight = 38,
    this.shrinkToContent = false,
    this.primaryDoubleClickOpensContextMenu = false,
    this.verticalScrollbarBottomInset = 0,
    this.cellSelectionEnabled = false,
    this.onCellTap,
  }) : assert(columns.isNotEmpty, 'At least one column is required');

  final List<T> rows;
  final List<StructuredDataColumn<T>> columns;
  final ScrollController? verticalController;
  final ScrollController? horizontalController;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowDoubleTap;
  final ValueChanged<List<T>>? onSelectionChanged;
  final void Function(int columnIndex, bool ascending)? onSortChanged;
  final ValueChanged<List<StructuredDataColumn<T>>>? onColumnsReordered;
  final List<StructuredDataAction<T>> rowActions;
  final List<StructuredDataChip> Function(T row)? metadataBuilder;
  final Widget? emptyState;
  final bool allowMultiSelect;
  final double rowHeight;
  final double headerHeight;
  final bool shrinkToContent;
  final bool primaryDoubleClickOpensContextMenu;
  final double verticalScrollbarBottomInset;
  final bool cellSelectionEnabled;
  final ValueChanged<StructuredDataCellCoordinate>? onCellTap;

  @override
  State<StructuredDataTable<T>> createState() => _StructuredDataTableState<T>();
}

class _StructuredDataTableState<T> extends State<StructuredDataTable<T>> {
  late SelectableListController _listController;
  late FocusNode _focusNode;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  late final bool _ownsVerticalController;
  late final bool _ownsHorizontalController;
  static const double _defaultMinFlexColumnWidth = 120;
  late List<StructuredDataColumn<T>> _columns;
  late List<double?> _columnWidthOverrides;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  final Map<int, double> _autoFitCache = {};
  StructuredDataCellCoordinate? _selectedCell;
  StructuredDataCellCoordinate? _cellSelectionAnchor;
  StructuredDataCellCoordinate? _cellSelectionExtent;
  List<double> _lastColumnWidths = const [];
  double _lastGapWidth = 0;
  double _lastRowPaddingX = 0;
  int? _pendingScrollToRow;
  bool _scrollToRowScheduled = false;
  int? _pendingScrollToColumn;
  bool _scrollToColumnScheduled = false;

  List<T> get _visibleRows {
    final sortIndex = _sortColumnIndex;
    if (sortIndex == null) return widget.rows;
    if (sortIndex < 0 || sortIndex >= _columns.length) return widget.rows;
    final sortValue = _sortValueForColumn(sortIndex);
    if (sortValue == null) return widget.rows;

    final sorted = widget.rows.toList(growable: false);
    sorted.sort((a, b) {
      final av = sortValue(a);
      final bv = sortValue(b);
      final result = _compareNullable(av, bv);
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  int _compareNullable(Comparable<Object?>? a, Comparable<Object?>? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  void _toggleSort(int index) {
    final sortable = _sortValueForColumn(index) != null;
    if (!sortable) return;
    setState(() {
      if (_sortColumnIndex == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = index;
        _sortAscending = true;
      }
      _listController.clearSelection();
      _listController.setItemCount(_visibleRows.length);
    });
    widget.onSortChanged?.call(index, _sortAscending);
  }

  Comparable<Object?>? Function(T row)? _sortValueForColumn(int index) {
    if (index < 0 || index >= _columns.length) return null;
    final column = _columns[index];
    if (column.sortValue != null) return column.sortValue;
    final textExtractor = column.autoFitText;
    if (textExtractor == null) return null;
    return (row) => textExtractor(row).toLowerCase();
  }

  void _autoFitColumn(int index) {
    if (index < 0 || index >= _columns.length) return;
    final column = _columns[index];
    final extractor = column.autoFitText;
    final widthExtractor = column.autoFitWidth;
    if (extractor == null && widthExtractor == null) {
      // If the column doesn't participate in auto-fit, interpret double-click
      // as "reset to default" (remove any manual override).
      setState(() {
        _columnWidthOverrides[index] = null;
      });
      return;
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final headerStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final cellStyle =
        column.autoFitTextStyle ?? Theme.of(context).textTheme.bodyMedium;

    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    final headerWidth = measure(column.label, headerStyle);

    var maxWidth = _autoFitCache[index] ?? headerWidth;
    final sampleCount = min(_visibleRows.length, 400);
    for (var i = 0; i < sampleCount; i++) {
      final row = _visibleRows[i];
      if (widthExtractor != null) {
        maxWidth = max(maxWidth, widthExtractor(context, row));
      } else {
        maxWidth = max(maxWidth, measure(extractor!(row), cellStyle));
      }
    }

    // Add a single-character pad so text is not flush against the edge.
    final paddingChar = 'M';
    final paddingWidth = measure(paddingChar, cellStyle);

    final target = maxWidth + paddingWidth + (column.autoFitExtraWidth ?? 0);
    final minWidth = max(_defaultMinFlexColumnWidth, column.minWidth ?? 0);

    _autoFitCache[index] = maxWidth;

    setState(() {
      _columnWidthOverrides[index] = max(minWidth, target);
    });
  }

  double _tableContentWidth(List<double> columnWidths, double gapWidth) {
    final totalGaps = max(0, _columns.length - 1);
    final totalWidth =
        columnWidths.fold<double>(0, (sum, width) => sum + width) +
        totalGaps * gapWidth;
    return totalWidth.ceilToDouble();
  }

  @override
  void initState() {
    super.initState();
    _columns = List.of(widget.columns);
    _columnWidthOverrides = List<double?>.filled(
      _columns.length,
      null,
      growable: true,
    );
    _autoFitCache.clear();
    _verticalController = widget.verticalController ?? ScrollController();
    _horizontalController = widget.horizontalController ?? ScrollController();
    _ownsVerticalController = widget.verticalController == null;
    _ownsHorizontalController = widget.horizontalController == null;
    _listController = SelectableListController(
      allowMultiSelect: widget.allowMultiSelect,
    )..addListener(_handleSelectionChanged);
    _focusNode = FocusNode(debugLabel: 'StructuredDataTable');
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void didUpdateWidget(covariant StructuredDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameColumns(oldWidget.columns, widget.columns)) {
      _columns = List.of(widget.columns);
      _columnWidthOverrides = List<double?>.filled(
        _columns.length,
        null,
        growable: true,
      );
      _autoFitCache.clear();
      _sortColumnIndex = null;
      _sortAscending = true;
      _listController.clearSelection();
      _selectedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
    }
    if (oldWidget.allowMultiSelect != widget.allowMultiSelect) {
      _listController
        ..removeListener(_handleSelectionChanged)
        ..dispose();
      _listController = SelectableListController(
        allowMultiSelect: widget.allowMultiSelect,
      )..addListener(_handleSelectionChanged);
    }
    if (oldWidget.verticalController != widget.verticalController &&
        widget.verticalController != null) {
      if (_ownsVerticalController) {
        _verticalController.dispose();
      }
      _verticalController = widget.verticalController!;
      _ownsVerticalController = false;
    }
    if (oldWidget.horizontalController != widget.horizontalController &&
        widget.horizontalController != null) {
      if (_ownsHorizontalController) {
        _horizontalController.dispose();
      }
      _horizontalController = widget.horizontalController!;
      _ownsHorizontalController = false;
    }
    if (!widget.cellSelectionEnabled) {
      _selectedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
    } else if (oldWidget.cellSelectionEnabled != widget.cellSelectionEnabled) {
      _selectedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _listController.clearSelection();
    }
    if (_selectedCell != null &&
        (_selectedCell!.rowIndex >= _visibleRows.length ||
            _selectedCell!.columnIndex >= _columns.length)) {
      _selectedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
    }
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void dispose() {
    _listController
      ..removeListener(_handleSelectionChanged)
      ..dispose();
    _focusNode.dispose();
    if (_ownsVerticalController) {
      _verticalController.dispose();
    }
    if (_ownsHorizontalController) {
      _horizontalController.dispose();
    }
    super.dispose();
  }

  bool _sameColumns(
    List<StructuredDataColumn<T>> a,
    List<StructuredDataColumn<T>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return false;
    }
    return true;
  }

  void _handleSelectionChanged() {
    setState(() {});
    widget.onSelectionChanged?.call(_selectedRows());
    if (!widget.cellSelectionEnabled) {
      final focused = _listController.focusedIndex;
      if (focused != null) {
        _scheduleScrollToRow(focused);
      }
    }
  }

  List<T> _selectedRows() => _listController.selectedIndices
      .where((index) => index < _visibleRows.length)
      .map((index) => _visibleRows[index])
      .toList(growable: false);

  void _selectSingle(int index) {
    _listController.selectSingle(index);
  }

  void _handleRowTapSelection(int index) {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    if (!widget.allowMultiSelect) {
      _selectSingle(index);
      return;
    }
    final hardware = HardwareKeyboard.instance;
    final isShift = hardware.isShiftPressed;
    final isControl = hardware.isControlPressed || hardware.isMetaPressed;
    if (isShift) {
      _listController.extendSelection(index);
      return;
    }
    if (isControl) {
      _listController.toggle(index);
      return;
    }
    _selectSingle(index);
  }

  void _handleDoubleTap(int index) {
    if (_visibleRows.isEmpty) return;
    if (!widget.cellSelectionEnabled) {
      _selectSingle(index);
    }
    widget.onRowDoubleTap?.call(_visibleRows[index]);
  }

  void _handleCellTap(int? rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled ||
        rowIndex == null ||
        rowIndex >= _visibleRows.length ||
        columnIndex >= _columns.length) {
      return;
    }
    _updateCellSelection(
      rowIndex: rowIndex,
      columnIndex: columnIndex,
    );
  }

  void _updateCellSelection({
    required int rowIndex,
    required int columnIndex,
    bool extend = false,
    bool notify = true,
  }) {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    final clampedRow = rowIndex.clamp(0, _visibleRows.length - 1);
    final clampedColumn = columnIndex.clamp(0, _columns.length - 1);
    final coordinate = StructuredDataCellCoordinate(
      rowIndex: clampedRow,
      columnIndex: clampedColumn,
    );
    if (_selectedCell == coordinate) {
      _listController.focus(clampedRow);
      return;
    }
    setState(() {
      _selectedCell = coordinate;
      if (extend) {
        _cellSelectionAnchor ??= _cellSelectionExtent ?? coordinate;
        _cellSelectionExtent = coordinate;
      } else {
        _cellSelectionAnchor = coordinate;
        _cellSelectionExtent = coordinate;
      }
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    if (notify) {
      widget.onCellTap?.call(coordinate);
    }
    _scheduleScrollToRow(clampedRow);
    _scheduleScrollToColumn(clampedColumn);
  }

  void _ensureCellSelection() {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    if (_selectedCell != null) {
      return;
    }
    final fallbackRow = _listController.focusedIndex ?? 0;
    _updateCellSelection(
      rowIndex: fallbackRow,
      columnIndex: 0,
      notify: false,
    );
  }

  bool _isCellSelected(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    final anchor = _cellSelectionAnchor;
    final extent = _cellSelectionExtent ?? _selectedCell;
    if (anchor == null || extent == null) return false;
    final top = min(anchor.rowIndex, extent.rowIndex);
    final bottom = max(anchor.rowIndex, extent.rowIndex);
    final left = min(anchor.columnIndex, extent.columnIndex);
    final right = max(anchor.columnIndex, extent.columnIndex);
    return rowIndex >= top &&
        rowIndex <= bottom &&
        columnIndex >= left &&
        columnIndex <= right;
  }

  int _pageStep() {
    if (!_verticalController.hasClients) {
      return 10;
    }
    final rowExtent = widget.rowHeight + 1;
    final viewport = _verticalController.position.viewportDimension;
    if (viewport <= 0) {
      return 10;
    }
    return max(1, (viewport / rowExtent).floor());
  }

  void _scrollToRow(int rowIndex) {
    if (!_verticalController.hasClients) {
      return;
    }
    final rowExtent = widget.rowHeight + 1;
    final position = _verticalController.position;
    final viewport = position.viewportDimension;
    final minOffset = position.minScrollExtent;
    final maxOffset = position.maxScrollExtent;
    var target = position.pixels;
    final rowTop = rowIndex * rowExtent;
    final rowBottom = rowTop + rowExtent;
    if (rowTop < position.pixels) {
      target = rowTop;
    } else if (rowBottom > position.pixels + viewport) {
      target = rowBottom - viewport;
    }
    target = target.clamp(minOffset, maxOffset);
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    _verticalController.jumpTo(target);
  }

  void _scrollToColumn(int columnIndex) {
    if (!_horizontalController.hasClients || _lastColumnWidths.isEmpty) {
      return;
    }
    if (columnIndex < 0 || columnIndex >= _lastColumnWidths.length) {
      return;
    }
    final position = _horizontalController.position;
    final viewport = position.viewportDimension;
    final minOffset = position.minScrollExtent;
    final maxOffset = position.maxScrollExtent;
    var left = _lastRowPaddingX;
    for (var i = 0; i < columnIndex; i++) {
      left += _lastColumnWidths[i];
      left += _lastGapWidth;
    }
    final right = left + _lastColumnWidths[columnIndex];
    var target = position.pixels;
    if (left < position.pixels) {
      target = left;
    } else if (right > position.pixels + viewport) {
      target = right - viewport;
    }
    target = target.clamp(minOffset, maxOffset);
    if ((target - position.pixels).abs() < 1) {
      return;
    }
    _horizontalController.jumpTo(target);
  }

  void _scheduleScrollToRow(int rowIndex) {
    _pendingScrollToRow = rowIndex;
    if (_scrollToRowScheduled) {
      return;
    }
    _scrollToRowScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToRowScheduled = false;
      final targetRow = _pendingScrollToRow;
      _pendingScrollToRow = null;
      if (!mounted || targetRow == null) {
        return;
      }
      _scrollToRow(targetRow);
    });
  }

  void _scheduleScrollToColumn(int columnIndex) {
    _pendingScrollToColumn = columnIndex;
    if (_scrollToColumnScheduled) {
      return;
    }
    _scrollToColumnScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToColumnScheduled = false;
      final targetColumn = _pendingScrollToColumn;
      _pendingScrollToColumn = null;
      if (!mounted || targetColumn == null) {
        return;
      }
      _scrollToColumn(targetColumn);
    });
  }

  bool _cellHasValue(int rowIndex, int columnIndex) {
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return false;
    }
    if (columnIndex < 0 || columnIndex >= _columns.length) {
      return false;
    }
    final row = _visibleRows[rowIndex];
    final column = _columns[columnIndex];
    final textExtractor = column.autoFitText;
    if (textExtractor != null) {
      return textExtractor(row).trim().isNotEmpty;
    }
    final sortValue = column.sortValue;
    if (sortValue != null) {
      final value = sortValue(row);
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      return true;
    }
    return true;
  }

  int _jumpRow(int startRow, int columnIndex, int delta) {
    if (_visibleRows.isEmpty) return startRow;
    final step = delta.sign;
    if (step == 0) return startRow;
    var row = startRow;
    final currentHasValue = _cellHasValue(startRow, columnIndex);
    if (currentHasValue) {
      var next = row + step;
      while (next >= 0 &&
          next < _visibleRows.length &&
          _cellHasValue(next, columnIndex)) {
        row = next;
        next += step;
      }
      return row;
    }
    var next = row + step;
    while (next >= 0 &&
        next < _visibleRows.length &&
        !_cellHasValue(next, columnIndex)) {
      row = next;
      next += step;
    }
    if (next >= 0 && next < _visibleRows.length) {
      return next;
    }
    return row;
  }

  int _jumpColumn(int rowIndex, int startColumn, int delta) {
    if (_columns.isEmpty) return startColumn;
    final step = delta.sign;
    if (step == 0) return startColumn;
    var col = startColumn;
    final currentHasValue = _cellHasValue(rowIndex, startColumn);
    if (currentHasValue) {
      var next = col + step;
      while (next >= 0 && next < _columns.length) {
        if (!_cellHasValue(rowIndex, next)) {
          break;
        }
        col = next;
        next += step;
      }
      return col;
    }
    var next = col + step;
    while (next >= 0 && next < _columns.length) {
      if (_cellHasValue(rowIndex, next)) {
        return next;
      }
      col = next;
      next += step;
    }
    return col;
  }

  KeyEventResult _handleCellKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent &&
        event is! KeyUpEvent &&
        event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return KeyEventResult.ignored;
    }
    _ensureCellSelection();
    final hardware = HardwareKeyboard.instance;
    final isShift = hardware.isShiftPressed;
    final isControl = hardware.isControlPressed || hardware.isMetaPressed;
    final current = _selectedCell ??
        StructuredDataCellCoordinate(
          rowIndex: _listController.focusedIndex ?? 0,
          columnIndex: 0,
        );
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      final isHandledKey = key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.home ||
          key == LogicalKeyboardKey.end ||
          key == LogicalKeyboardKey.pageUp ||
          key == LogicalKeyboardKey.pageDown ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.tab ||
          key == LogicalKeyboardKey.f2 ||
          (key == LogicalKeyboardKey.keyA && isControl) ||
          (key == LogicalKeyboardKey.space && (isControl || isShift));
      return isHandledKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter) {
      _updateCellSelection(
        rowIndex: current.rowIndex + (isShift ? -1 : 1),
        columnIndex: current.columnIndex,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      final delta = isShift ? -1 : 1;
      var nextRow = current.rowIndex;
      var nextColumn = current.columnIndex + delta;
      if (nextColumn < 0) {
        nextColumn = _columns.length - 1;
        nextRow = current.rowIndex - 1;
      } else if (nextColumn >= _columns.length) {
        nextColumn = 0;
        nextRow = current.rowIndex + 1;
      }
      _updateCellSelection(
        rowIndex: nextRow,
        columnIndex: nextColumn,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA && isControl) {
      if (_visibleRows.isNotEmpty && _columns.isNotEmpty) {
        setState(() {
          _cellSelectionAnchor =
              const StructuredDataCellCoordinate(rowIndex: 0, columnIndex: 0);
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
        });
        _scheduleScrollToRow(_visibleRows.length - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && (isControl || isShift)) {
      if (isControl) {
        setState(() {
          _cellSelectionAnchor = StructuredDataCellCoordinate(
            rowIndex: 0,
            columnIndex: current.columnIndex,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: current.columnIndex,
          );
        });
        _scheduleScrollToRow(_visibleRows.length - 1);
      } else if (isShift) {
        setState(() {
          _cellSelectionAnchor = StructuredDataCellCoordinate(
            rowIndex: current.rowIndex,
            columnIndex: 0,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
          );
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      final coordinate = _selectedCell;
      if (coordinate != null) {
        widget.onCellTap?.call(coordinate);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, -1)
          : current.rowIndex - 1;
      _updateCellSelection(
        rowIndex: nextRow,
        columnIndex: current.columnIndex,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, 1)
          : current.rowIndex + 1;
      _updateCellSelection(
        rowIndex: nextRow,
        columnIndex: current.columnIndex,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, -1)
          : current.columnIndex - 1;
      _updateCellSelection(
        rowIndex: current.rowIndex,
        columnIndex: nextColumn,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, 1)
          : current.columnIndex + 1;
      _updateCellSelection(
        rowIndex: current.rowIndex,
        columnIndex: nextColumn,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      if (isControl) {
        _updateCellSelection(rowIndex: 0, columnIndex: 0, extend: isShift);
      } else {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: 0,
          extend: isShift,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (isControl) {
        _updateCellSelection(
          rowIndex: _visibleRows.length - 1,
          columnIndex: _columns.length - 1,
          extend: isShift,
        );
      } else {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: _columns.length - 1,
          extend: isShift,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      _updateCellSelection(
        rowIndex: current.rowIndex - _pageStep(),
        columnIndex: current.columnIndex,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      _updateCellSelection(
        rowIndex: current.rowIndex + _pageStep(),
        columnIndex: current.columnIndex,
        extend: isShift,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showContextMenu(T row, Offset position) async {
    if (widget.rowActions.isEmpty) return;
    final selected = await showMenu<StructuredDataAction<T>>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: widget.rowActions
          .map(
            (action) => PopupMenuItem<StructuredDataAction<T>>(
              value: action,
              enabled: action.enabled,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    color: action.destructive
                        ? Theme.of(context).colorScheme.error
                        : null,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(action.label),
                ],
              ),
            ),
          )
          .toList(),
    );
    selected?.onSelected(row);
  }

  void _showContextMenuForIndex(int index, Offset position) {
    if (_visibleRows.isEmpty || widget.rowActions.isEmpty) return;
    if (!widget.cellSelectionEnabled) {
      _selectSingle(index);
    }
    _showContextMenu(_visibleRows[index], position);
  }

  List<Widget> _buildRowCells(
    BuildContext context, {
    T? row,
    required bool header,
    required List<double> columnWidths,
    int? rowIndex,
  }) {
    assert(header || row != null, 'Row is required when rendering cells');
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final cells = <Widget>[];
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final content = header
          ? Text(
              column.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              softWrap: false,
              overflow: TextOverflow.clip,
            )
          : DefaultTextStyle.merge(
              softWrap: column.wrap,
              maxLines: column.wrap ? null : 1,
              overflow: column.wrap
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              child: column.cellBuilder(context, row as T),
            );
      final cellPaddingX = widget.cellSelectionEnabled
          ? spacing.base * 1.2
          : spacing.base * 0.6;
      final aligned = Align(
        alignment: column.alignment,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cellPaddingX),
          child: content,
        ),
      );
      final roundedCorner = BorderRadius.zero;
      final isBodyCell = !header && rowIndex != null;
      final isSelectedCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _selectedCell != null &&
          _selectedCell!.rowIndex == rowIndex &&
          _selectedCell!.columnIndex == i;
      final isRangeCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _selectedCell != null &&
          _isCellSelected(rowIndex!, i);
      final separatorSide = BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        width: 0.5,
      );
      final defaultCellBorder = widget.cellSelectionEnabled
          ? Border(
              right: i == _columns.length - 1 ? BorderSide.none : separatorSide,
            )
          : null;
      final highlightColor = scheme.primary.withValues(alpha: 0.85);
      final rangeFill = scheme.primary.withValues(alpha: 0.14);
      final selectedCellBorder = Border.all(color: highlightColor, width: 1.4);
      final cellDecoration = BoxDecoration(
        borderRadius: roundedCorner,
        color: isRangeCell ? rangeFill : null,
        border: widget.cellSelectionEnabled
            ? (isSelectedCell ? selectedCellBorder : defaultCellBorder)
            : null,
      );
      final cellBody = Container(
        decoration: cellDecoration.copyWith(
          boxShadow: isSelectedCell
              ? [
                  BoxShadow(
                    color: highlightColor.withValues(alpha: 0.35),
                    blurRadius: 6,
                    spreadRadius: 0.3,
                  ),
                ]
              : null,
        ),
        child: aligned,
      );
      final interactiveCell = isBodyCell && widget.cellSelectionEnabled
          ? Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if ((event.buttons & kPrimaryButton) != 0) {
                  _handleCellTap(rowIndex, i);
                }
              },
              child: SizedBox.expand(child: cellBody),
            )
          : SizedBox.expand(child: cellBody);
      final cell = SizedBox(width: columnWidths[i], child: interactiveCell);
      cells.add(cell);
      if (i != _columns.length - 1) {
        final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
        cells.add(SizedBox(width: gapWidth));
      }
    }
    return cells;
  }

  Widget _buildHeader(
    BuildContext context,
    List<double> columnWidths,
    double gapWidth,
  ) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final headerHorizontalPadding = widget.cellSelectionEnabled
        ? spacing.base + spacing.xs
        : spacing.base * 1.2 + spacing.xs;
    final handleWidth = spacing.base * 1.5;
    final hasSpacing = gapWidth > 0;

    Widget buildResizeHandle(int index) => SizedBox(
          width: handleWidth,
          child: _HeaderResizeHandle(
            key: ValueKey('structured_data_table.resize.$index'),
            height: widget.headerHeight,
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            onResize: (delta) {
              setState(() {
                final column = _columns[index];
                final current =
                    _columnWidthOverrides[index] ?? column.width ?? columnWidths[index];
                final minWidth = max(
                  _defaultMinFlexColumnWidth,
                  column.minWidth ?? 0,
                );
                _columnWidthOverrides[index] = max(
                  minWidth,
                  current + delta,
                );
              });
            },
            onAutoFit: () => _autoFitColumn(index),
          ),
        );

    Widget wrapWithOverlay(Widget base, int index) => Stack(
          clipBehavior: Clip.none,
          children: [
            base,
            Positioned(
              top: 0,
              bottom: 0,
              right: -handleWidth / 2,
              width: handleWidth,
              child: buildResizeHandle(index),
            ),
          ],
        );

    return Container(
      height: widget.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: headerHorizontalPadding),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        children: List<Widget>.generate(_columns.length, (index) {
          final column = _columns[index];
          final sortable = _sortValueForColumn(index) != null;
          final sorted = _sortColumnIndex == index;
          final icon = _sortAscending
              ? Icons.arrow_upward
              : Icons.arrow_downward;

          final headerLabel = Text(
            column.label,
            style: textStyle,
            softWrap: false,
            overflow: TextOverflow.clip,
          );

          final headerContent = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: headerLabel),
              if (sortable && sorted) ...[
                SizedBox(width: spacing.xs),
                Icon(icon, size: 14, color: scheme.primary),
              ],
            ],
          );

          final headerPaddingX = widget.cellSelectionEnabled
              ? spacing.base * 1.2
              : spacing.base * 0.6;
          final headerCell = Align(
            alignment: column.alignment,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: headerPaddingX,
                vertical: spacing.xs,
              ),
              child: headerContent,
            ),
          );
          final separatorSide = BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          );
          final headerCellDecorated = DecoratedBox(
            decoration: const BoxDecoration(),
            child: headerCell,
          );

          void reorderFrom(int from) {
            setState(() {
              final moved = _columns.removeAt(from);
              _columns.insert(index, moved);
              final movedWidth = _columnWidthOverrides.removeAt(from);
              _columnWidthOverrides.insert(index, movedWidth);
              _sortColumnIndex = null;
              _sortAscending = true;
              _listController.clearSelection();
            });
            widget.onColumnsReordered?.call(
              List<StructuredDataColumn<T>>.unmodifiable(_columns),
            );
          }

          final headerInteractive = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: sortable ? () => _toggleSort(index) : null,
            child: MouseRegion(
              cursor:
                  sortable ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Row(children: [Expanded(child: headerCellDecorated)]),
            ),
          );

          final dragFeedback = Material(
            color: Colors.transparent,
            child: Container(
              width: columnWidths[index] +
                  (hasSpacing ? 0.0 : handleWidth),
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.85),
                  width: 1.2,
                ),
              ),
              child: DefaultTextStyle(
                style: textStyle ?? const TextStyle(),
                child: headerContent,
              ),
            ),
          );

          final canReorder = _columns.length > 1;
          const dragHandleWidth = 28.0;
          final dragHandleInsetRight = hasSpacing
              ? spacing.xs + (handleWidth / 2)
              : (handleWidth / 2) + spacing.sm;
          final dragHandle = SizedBox(
            width: dragHandleWidth,
            child: _HeaderDragHandle(
              enabled: canReorder,
              data: index,
              feedback: dragFeedback,
              activeColor: scheme.primary,
              inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          );

          final target = DragTarget<int>(
            hitTestBehavior: HitTestBehavior.deferToChild,
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) => reorderFrom(details.data),
            builder: (context, candidateData, rejectedData) {
              final highlight = candidateData.isNotEmpty;
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: highlight
                      ? Border(
                          bottom: BorderSide(
                            color: scheme.primary.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        )
                      : null,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right:
                          index == _columns.length - 1
                              ? BorderSide.none
                              : separatorSide,
                    ),
                  ),
                  child: Stack(
                    children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: dragHandleWidth + dragHandleInsetRight,
                      ),
                      child: headerInteractive,
                    ),
                    Positioned(
                      right: dragHandleInsetRight,
                      top: 0,
                      bottom: 0,
                      child: dragHandle,
                    ),
                    ],
                  ),
                ),
              );
            },
          );

          final cell = SizedBox(
            key: ValueKey('structured_data_table.header_cell.$index'),
            width: columnWidths[index],
            child: target,
          );

          if (index == _columns.length - 1) {
            return wrapWithOverlay(cell, index);
          }

          if (hasSpacing) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                cell,
                SizedBox(
                  width: gapWidth,
                  child: Transform.translate(
                    offset: Offset(-handleWidth / 2, 0),
                    child: buildResizeHandle(index),
                  ),
                ),
              ],
            );
          }

          return wrapWithOverlay(cell, index);
        }, growable: false),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, List<double> columnWidths) {
    final row = _visibleRows[index];
    final spacing = context.appTheme.spacing;
    final listTokens = context.appTheme.list;
    final selected = _listController.selectedIndices.contains(index);
    final focused = _listController.focusedIndex == index;
    final verticalPadding = widget.cellSelectionEnabled
        ? 0.0
        : spacing.base * 0.7;
    final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
    final rowContentWidth = _tableContentWidth(columnWidths, gapWidth) +
        (widget.cellSelectionEnabled ? 0.0 : 1.0);

    final stripeBackground = widget.cellSelectionEnabled
        ? Colors.transparent
        : (index.isEven
            ? listTokens.stripeEvenBackground
            : listTokens.stripeOddBackground);
    final background = widget.cellSelectionEnabled
        ? Colors.transparent
        : (selected ? listTokens.selectedBackground : stripeBackground);
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed)) {
        return listTokens.hoverBackground;
      }
      return null;
    });

    final showFocusOutline = focused && !widget.cellSelectionEnabled;
    final border = Border.all(
      color: showFocusOutline ? listTokens.focusOutline : Colors.transparent,
      width: showFocusOutline ? 0.9 : 0.4,
    );

    Offset? tapPosition;

    return Material(
      color: background,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          tapPosition = event.position;
          if ((event.buttons & kPrimaryButton) != 0) {
            if (!widget.cellSelectionEnabled) {
              _handleRowTapSelection(index);
            }
            widget.onRowTap?.call(row);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) {
            tapPosition = details.globalPosition;
            _showContextMenuForIndex(index, details.globalPosition);
          },
          onLongPressStart: (details) {
            tapPosition = details.globalPosition;
            _showContextMenuForIndex(index, details.globalPosition);
          },
          onDoubleTap: () {
            if (widget.primaryDoubleClickOpensContextMenu) {
              final position =
                  tapPosition ??
                  (context.findRenderObject() as RenderBox?)?.localToGlobal(
                    Offset.zero,
                  ) ??
                  Offset.zero;
              _showContextMenuForIndex(index, position);
              return;
            }
            _handleDoubleTap(index);
          },
          child: InkWell(
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            overlayColor: overlayColor,
            onTap: () {},
            child: Container(
              height: widget.rowHeight,
              constraints: BoxConstraints(minHeight: widget.rowHeight),
              padding: EdgeInsets.symmetric(
                horizontal: widget.cellSelectionEnabled
                    ? spacing.base
                    : spacing.base * 1.2,
                vertical: verticalPadding,
              ),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                border: border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      width: rowContentWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ..._buildRowCells(
                            context,
                            row: row,
                            header: false,
                            columnWidths: columnWidths,
                            rowIndex: index,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<double> _computeColumnWidths(double availableWidth) {
    final flexIndices = <int>[];
    var totalFlex = 0;
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final override = i < _columnWidthOverrides.length
          ? _columnWidthOverrides[i]
          : null;
      final isFixed = override != null || column.width != null;
      if (!isFixed) {
        flexIndices.add(i);
        totalFlex += column.flex;
      }
    }

    final remainingForFlex = flexIndices.fold<double>(
      0,
      (sum, index) =>
          sum + max(_defaultMinFlexColumnWidth, _columns[index].minWidth ?? 0),
    );
    final widths = <double>[];

    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final override = i < _columnWidthOverrides.length
          ? _columnWidthOverrides[i]
          : null;
      if (override != null) {
        widths.add(max(column.minWidth ?? 0, override));
        continue;
      }
      if (column.width != null) {
        widths.add(max(column.minWidth ?? 0, column.width!));
        continue;
      }
      final flexShare = totalFlex == 0
          ? remainingForFlex
          : remainingForFlex / totalFlex;
      final target = totalFlex == 0
          ? remainingForFlex
          : flexShare * column.flex;
      widths.add(
        max(_defaultMinFlexColumnWidth, max(column.minWidth ?? 0, target)),
      );
    }
    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final surface = context.appTheme.section.surface;

    if (_visibleRows.isEmpty && widget.emptyState != null) {
      return Container(
        decoration: BoxDecoration(
          color: surface.background,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: surface.borderColor.withValues(alpha: 0.2),
            width: 0.4,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.appTheme.spacing.base * 1.2,
          vertical: context.appTheme.spacing.base * 1.2,
        ),
        child: Center(child: widget.emptyState),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const double verticalScrollbarSpace = 14;
        final availableWidth = max(
          0.0,
          constraints.maxWidth - verticalScrollbarSpace,
        );
        final columnWidths = _computeColumnWidths(availableWidth);
        final spacing = context.appTheme.spacing;
        final basePadding = spacing.base;
    final headerPaddingX = widget.cellSelectionEnabled
        ? basePadding + spacing.xs
        : basePadding * 1.2 + spacing.xs;
        final rowPaddingX = widget.cellSelectionEnabled
            ? spacing.base + spacing.xs
            : spacing.base * 1.2 + spacing.xs;
        final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
        _lastColumnWidths = columnWidths;
        _lastGapWidth = gapWidth;
        _lastRowPaddingX = rowPaddingX;
        final contentWidth = _tableContentWidth(columnWidths, gapWidth) +
            (widget.cellSelectionEnabled ? 0.0 : 1.0);
        final paddedWidth = contentWidth + 2 * max(headerPaddingX, rowPaddingX);
        final targetWidth =
            max(constraints.maxWidth, paddedWidth + verticalScrollbarSpace) +
            1.0;

        const verticalScrollbarWidth = 10.0;
        const horizontalScrollbarThickness = 10.0;
        return Container(
          margin: surface.margin,
          decoration: BoxDecoration(
            color: surface.background,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: surface.borderColor.withValues(alpha: 0.2),
              width: 0.4,
            ),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: RawScrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              thickness: verticalScrollbarWidth,
              radius: const Radius.circular(6),
              scrollbarOrientation: ScrollbarOrientation.right,
              padding: EdgeInsets.only(
                bottom: widget.verticalScrollbarBottomInset,
              ),
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                thickness: horizontalScrollbarThickness,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: targetWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                        _buildHeader(context, columnWidths, gapWidth),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: _buildBody(surface, columnWidths),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(AppSurfaceStyle surface, List<double> columnWidths) {
    final scheme = Theme.of(context).colorScheme;
    final listView = ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _verticalController,
        padding: EdgeInsets.zero,
        shrinkWrap: widget.shrinkToContent,
        primary: false,
        physics: const ClampingScrollPhysics(),
        itemExtent: widget.rowHeight + 1,
        cacheExtent: (widget.rowHeight + 1) * 20,
        itemCount: _visibleRows.length,
        itemBuilder: (context, index) => Column(
          children: [
            _buildRow(context, index, columnWidths),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );

    if (widget.cellSelectionEnabled) {
      return Focus(
        focusNode: _focusNode,
        onFocusChange: (_) => _listController.setItemCount(_visibleRows.length),
        onKeyEvent: _handleCellKeyEvent,
        child: listView,
      );
    }

    return SelectableListKeyboardHandler(
      controller: _listController,
      itemCount: _visibleRows.length,
      focusNode: _focusNode,
      onActivate: (index) => _handleDoubleTap(index),
      child: listView,
    );
  }
}

class _HeaderDragHandle extends StatefulWidget {
  const _HeaderDragHandle({
    required this.enabled,
    required this.data,
    required this.feedback,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool enabled;
  final int data;
  final Widget feedback;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<_HeaderDragHandle> createState() => _HeaderDragHandleState();
}

class _HeaderDragHandleState extends State<_HeaderDragHandle> {
  bool _dragActive = false;

  void _setActive(bool value) {
    if (_dragActive == value) return;
    setState(() => _dragActive = value);
  }

  @override
  Widget build(BuildContext context) {
    final icon = _dragActive ? NerdIcon.dragSelect.data : NerdIcon.drag.data;
    final color = _dragActive ? widget.activeColor : widget.inactiveColor;
    final handle = Align(
      alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(
            left: context.appTheme.spacing.xs,
            right: context.appTheme.spacing.sm,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
    );

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.grab : MouseCursor.defer,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.0,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _setActive(true),
            onPointerUp: (_) => _setActive(false),
            onPointerCancel: (_) => _setActive(false),
            child: Draggable<int>(
              data: widget.data,
              axis: Axis.horizontal,
              feedback: widget.feedback,
              onDragStarted: () => _setActive(true),
              onDragEnd: (_) => _setActive(false),
              onDraggableCanceled: (_, __) => _setActive(false),
              onDragCompleted: () => _setActive(false),
              child: handle,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderResizeHandle extends StatefulWidget {
  const _HeaderResizeHandle({
    super.key,
    required this.height,
    required this.color,
    required this.onResize,
    required this.onAutoFit,
  });

  final double height;
  final Color color;
  final ValueChanged<double> onResize;
  final VoidCallback onAutoFit;

  @override
  State<_HeaderResizeHandle> createState() => _HeaderResizeHandleState();
}

class _HeaderResizeHandleState extends State<_HeaderResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = _hovered
        ? scheme.primary.withValues(alpha: 0.85)
        : widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => widget.onResize(details.delta.dx),
        onDoubleTap: widget.onAutoFit,
        child: Center(
          child: Container(
            width: 1,
            height: widget.height * 0.55,
            color: dividerColor,
          ),
        ),
      ),
    );
  }
}
