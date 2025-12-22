import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/services/logging/app_logger.dart';

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

class StructuredDataMenuAction<T> {
  const StructuredDataMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final void Function(List<T> selectedRows, T primaryRow) onSelected;
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

class StructuredDataCellRange {
  const StructuredDataCellRange({required this.anchor, required this.extent});

  final StructuredDataCellCoordinate anchor;
  final StructuredDataCellCoordinate extent;

  int get top => min(anchor.rowIndex, extent.rowIndex);
  int get bottom => max(anchor.rowIndex, extent.rowIndex);
  int get left => min(anchor.columnIndex, extent.columnIndex);
  int get right => max(anchor.columnIndex, extent.columnIndex);
}

/// A flexible, list-backed data table with keyboard navigation, selection, and
/// contextual actions. Designed for complex lists like servers, clusters, and
/// explorer entries that need rich metadata and right-click menus.
class StructuredDataTable<T> extends StatefulWidget {
  StructuredDataTable({
    super.key,
    required this.rows,
    required this.columns,
    this.hiddenColumnIds = const {},
    this.columnIdBuilder,
    this.verticalController,
    this.horizontalController,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onRowContextMenu,
    this.onRowPointerDown,
    this.onRowPointerMove,
    this.onRowPointerUp,
    this.onRowPointerCancel,
    this.onRowPointerEnter,
    this.onBackgroundContextMenu,
    this.rowSelectionEnabled = true,
    this.rowSelectionPredicate,
    this.selectedRowsBuilder,
    this.enableKeyboardNavigation = true,
    this.focusNode,
    this.onKeyEvent,
    this.onSelectionChanged,
    this.onSortChanged,
    this.onColumnsReordered,
    this.rowActions = const [],
    this.rowContextMenuBuilder,
    this.metadataBuilder,
    this.emptyState,
    this.searchQuery = '',
    this.rowSearchTextBuilder,
    this.useZebraStripes = true,
    this.surfaceBackgroundColor,
    this.refreshListenable,
    this.allowMultiSelect = true,

    this.rowHeight = 60,
    this.headerHeight = 38,
    this.shrinkToContent = false,
    this.primaryDoubleClickOpensContextMenu = true,
    this.verticalScrollbarBottomInset = 0,
    this.cellSelectionEnabled = false,
    this.onCellTap,
    this.onCellEditRequested,
    this.onCellEditCommitted,
    this.onCellEditCanceled,
    this.onFillHandleCopy,
    this.rowDragPayloadBuilder,
    this.rowDragFeedbackBuilder,
  }) : assert(columns.isNotEmpty, 'At least one column is required');

  final List<T> rows;
  final List<StructuredDataColumn<T>> columns;
  final Set<String> hiddenColumnIds;
  final String Function(StructuredDataColumn<T> column)? columnIdBuilder;
  final ScrollController? verticalController;
  final ScrollController? horizontalController;
  final ValueChanged<T>? onRowTap;
  final ValueChanged<T>? onRowDoubleTap;
  final void Function(T row, Offset? anchor)? onRowContextMenu;
  final void Function(int index, T row, PointerDownEvent event)?
  onRowPointerDown;
  final void Function(int index, T row, PointerMoveEvent event)?
  onRowPointerMove;
  final void Function(int index, T row, PointerUpEvent event)? onRowPointerUp;
  final void Function(int index, T row, PointerCancelEvent event)?
  onRowPointerCancel;
  final void Function(int index, T row, PointerEnterEvent event)?
  onRowPointerEnter;
  final ValueChanged<Offset>? onBackgroundContextMenu;
  final bool rowSelectionEnabled;
  final bool Function(T row)? rowSelectionPredicate;
  final List<T> Function(List<T> rows)? selectedRowsBuilder;
  final bool enableKeyboardNavigation;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final ValueChanged<List<T>>? onSelectionChanged;
  final void Function(int columnIndex, bool ascending)? onSortChanged;
  final ValueChanged<List<StructuredDataColumn<T>>>? onColumnsReordered;
  final List<StructuredDataAction<T>> rowActions;
  final List<StructuredDataMenuAction<T>> Function(
    T row,
    List<T> selectedRows,
    Offset? anchor,
  )?
  rowContextMenuBuilder;
  final List<StructuredDataChip> Function(T row)? metadataBuilder;
  final Widget? emptyState;
  final String searchQuery;
  final String Function(T row)? rowSearchTextBuilder;
  final bool useZebraStripes;
  final Color? surfaceBackgroundColor;
  final Listenable? refreshListenable;
  final bool allowMultiSelect;
  final double rowHeight;
  final double headerHeight;
  final bool shrinkToContent;
  final bool primaryDoubleClickOpensContextMenu;
  final double verticalScrollbarBottomInset;
  final bool cellSelectionEnabled;
  final ValueChanged<StructuredDataCellCoordinate>? onCellTap;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditRequested;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditCommitted;
  final ValueChanged<StructuredDataCellCoordinate>? onCellEditCanceled;
  final void Function(
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange,
  )?
  onFillHandleCopy;
  final Object Function(T row, List<T> selectedRows)? rowDragPayloadBuilder;
  final Widget Function(BuildContext context, T row, List<T> selectedRows)?
  rowDragFeedbackBuilder;

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
  StructuredDataCellCoordinate? _focusedCell;
  StructuredDataCellCoordinate? _cellSelectionAnchor;
  StructuredDataCellCoordinate? _cellSelectionExtent;
  final Set<StructuredDataCellCoordinate> _additionalSelectedCells = {};
  bool _cellEditMode = false;
  int? _marqueePointer;
  bool _isMarqueeSelecting = false;
  StructuredDataCellCoordinate? _hoveredCell;
  final GlobalKey _bodyKey = GlobalKey();
  bool _isFillHandleDragging = false;
  StructuredDataCellRange? _fillHandleSourceRange;
  StructuredDataCellCoordinate? _fillHandleExtent;
  int? _touchDragPointer;
  bool _isTouchDragging = false;
  List<double> _lastColumnWidths = const [];
  double _lastGapWidth = 0;
  double _lastRowPaddingX = 0;
  int? _pendingScrollToRow;
  bool _scrollToRowScheduled = false;
  int? _pendingScrollToColumn;
  bool _scrollToColumnScheduled = false;

  List<T> get _visibleRows {
    final filtered = _applySearch(widget.rows);
    final sortIndex = _sortColumnIndex;
    if (sortIndex == null) return filtered;
    if (sortIndex < 0 || sortIndex >= _columns.length) return filtered;
    final sortValue = _sortValueForColumn(sortIndex);
    if (sortValue == null) return filtered;

    final sorted = filtered.toList(growable: false);
    sorted.sort((a, b) {
      final av = sortValue(a);
      final bv = sortValue(b);
      final result = _compareNullable(av, bv);
      return _sortAscending ? result : -result;
    });
    return sorted;
  }

  List<T> _applySearch(List<T> rows) {
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isEmpty) return rows;
    final builder = widget.rowSearchTextBuilder;
    return rows
        .where((row) => _rowMatchesQuery(row, query, builder))
        .toList(growable: false);
  }

  bool _rowMatchesQuery(T row, String query, String Function(T row)? builder) {
    if (builder != null) {
      return builder(row).toLowerCase().contains(query);
    }
    var hasSearchableColumn = false;
    for (final column in _columns) {
      final textExtractor = column.autoFitText;
      if (textExtractor == null) continue;
      hasSearchableColumn = true;
      if (textExtractor(row).toLowerCase().contains(query)) {
        return true;
      }
    }
    return !hasSearchableColumn;
  }

  List<StructuredDataColumn<T>> _buildVisibleColumns() {
    if (widget.hiddenColumnIds.isEmpty) {
      return List.of(widget.columns);
    }
    final idFor = widget.columnIdBuilder ?? (column) => column.label.trim();
    final visible = <StructuredDataColumn<T>>[];
    for (var i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i];
      if (!widget.hiddenColumnIds.contains(idFor(column))) {
        visible.add(column);
      }
    }
    if (visible.isEmpty && widget.columns.isNotEmpty) {
      visible.add(widget.columns.first);
    }
    return visible;
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

  void _handleExternalRefresh() {
    if (!mounted) return;
    AppLogger.d(
      'StructuredDataTable refreshListenable fired: '
      'rows=${widget.rows.length} visible=${_visibleRows.length}',
      tag: 'StructuredDataTable',
    );
    setState(() {
      _listController.setItemCount(_visibleRows.length);
    });
  }

  @override
  void initState() {
    super.initState();
    _columns = _buildVisibleColumns();
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
    widget.refreshListenable?.addListener(_handleExternalRefresh);
    _focusNode = FocusNode(debugLabel: 'StructuredDataTable');
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void didUpdateWidget(covariant StructuredDataTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameColumns(oldWidget.columns, widget.columns) ||
        oldWidget.hiddenColumnIds != widget.hiddenColumnIds) {
      _columns = _buildVisibleColumns();
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
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    }
    if (oldWidget.allowMultiSelect != widget.allowMultiSelect) {
      _listController
        ..removeListener(_handleSelectionChanged)
        ..dispose();
      _listController = SelectableListController(
        allowMultiSelect: widget.allowMultiSelect,
      )..addListener(_handleSelectionChanged);
    }
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_handleExternalRefresh);
      widget.refreshListenable?.addListener(_handleExternalRefresh);
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _listController.clearSelection();
      if (widget.cellSelectionEnabled) {
        _selectedCell = null;
        _focusedCell = null;
        _cellSelectionAnchor = null;
        _cellSelectionExtent = null;
        _additionalSelectedCells.clear();
        _cellEditMode = false;
      }
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
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    } else if (oldWidget.cellSelectionEnabled != widget.cellSelectionEnabled) {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
      _listController.clearSelection();
    }
    if (_selectedCell != null &&
        (_selectedCell!.rowIndex >= _visibleRows.length ||
            _selectedCell!.columnIndex >= _columns.length)) {
      _selectedCell = null;
      _focusedCell = null;
      _cellSelectionAnchor = null;
      _cellSelectionExtent = null;
      _additionalSelectedCells.clear();
      _cellEditMode = false;
    }
    if (_columns.isEmpty && widget.columns.isNotEmpty) {
      _columns = _buildVisibleColumns();
      _columnWidthOverrides = List<double?>.filled(
        _columns.length,
        null,
        growable: true,
      );
      _autoFitCache.clear();
    }
    _listController.setItemCount(_visibleRows.length);
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_handleExternalRefresh);
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

  List<T> _selectedRows() {
    final builder = widget.selectedRowsBuilder;
    if (builder != null) {
      return builder(_visibleRows);
    }
    return _listController.selectedIndices
        .where((index) => index < _visibleRows.length)
        .map((index) => _visibleRows[index])
        .toList(growable: false);
  }

  void _selectSingle(int index) {
    _listController.selectSingle(index);
  }

  void _handleRowTapSelection(int index) {
    if (!widget.rowSelectionEnabled) {
      return;
    }
    final focusNode = widget.focusNode ?? _focusNode;
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
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
    if (!widget.cellSelectionEnabled && widget.rowSelectionEnabled) {
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
    if (_cellEditMode) {
      _exitCellEditMode(commit: false);
    }
    _updateCellSelection(rowIndex: rowIndex, columnIndex: columnIndex);
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
      _focusedCell = coordinate;
      return;
    }
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      if (extend) {
        _cellSelectionAnchor ??= _cellSelectionExtent ?? coordinate;
        _cellSelectionExtent = coordinate;
      } else {
        _cellSelectionAnchor = coordinate;
        _cellSelectionExtent = coordinate;
        _additionalSelectedCells.clear();
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

  void _ensureCellFocus() {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    if (_focusedCell != null || _selectedCell != null) {
      return;
    }
    final fallbackRow = _listController.focusedIndex ?? 0;
    _updateCellFocus(rowIndex: fallbackRow, columnIndex: 0);
  }

  bool _isCellSelected(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    if (_additionalSelectedCells.contains(
      StructuredDataCellCoordinate(
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      ),
    )) {
      return true;
    }
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

  bool _isHoveredCell(int rowIndex, int columnIndex) {
    if (!widget.cellSelectionEnabled) return false;
    final hovered = _hoveredCell;
    if (hovered == null) return false;
    return hovered.rowIndex == rowIndex && hovered.columnIndex == columnIndex;
  }

  StructuredDataCellRange? _selectionRange() {
    final anchor = _cellSelectionAnchor;
    final extent = _cellSelectionExtent ?? _selectedCell;
    if (anchor == null || extent == null) return null;
    return StructuredDataCellRange(anchor: anchor, extent: extent);
  }

  void _startFillHandleDrag(StructuredDataCellRange range) {
    setState(() {
      _isFillHandleDragging = true;
      _fillHandleSourceRange = range;
      _fillHandleExtent = range.extent;
    });
  }

  void _updateFillHandleDrag(Offset globalPosition) {
    final coordinate = _cellCoordinateForGlobalOffset(globalPosition);
    if (coordinate == null) return;
    final sourceRange = _fillHandleSourceRange;
    if (sourceRange == null) return;
    setState(() {
      _fillHandleExtent = coordinate;
      _cellSelectionAnchor = sourceRange.anchor;
      _cellSelectionExtent = coordinate;
      _selectedCell = coordinate;
      _focusedCell = coordinate;
    });
  }

  void _endFillHandleDrag() {
    final sourceRange = _fillHandleSourceRange;
    final extent = _fillHandleExtent;
    if (sourceRange != null && extent != null) {
      final targetRange = StructuredDataCellRange(
        anchor: sourceRange.anchor,
        extent: extent,
      );
      widget.onFillHandleCopy?.call(sourceRange, targetRange);
    }
    setState(() {
      _isFillHandleDragging = false;
      _fillHandleSourceRange = null;
      _fillHandleExtent = null;
    });
  }

  void _applyEdgeScroll(Offset localPosition) {
    final renderBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    const edgeThreshold = 24.0;
    const scrollStep = 18.0;

    var verticalDelta = 0.0;
    if (localPosition.dy < edgeThreshold) {
      verticalDelta = -scrollStep;
    } else if (localPosition.dy > size.height - edgeThreshold) {
      verticalDelta = scrollStep;
    }

    var horizontalDelta = 0.0;
    if (localPosition.dx < edgeThreshold) {
      horizontalDelta = -scrollStep;
    } else if (localPosition.dx > size.width - edgeThreshold) {
      horizontalDelta = scrollStep;
    }

    if (verticalDelta != 0 && _verticalController.hasClients) {
      final position = _verticalController.position;
      final next = (position.pixels + verticalDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _verticalController.jumpTo(next);
    }

    if (horizontalDelta != 0 && _horizontalController.hasClients) {
      final position = _horizontalController.position;
      final next = (position.pixels + horizontalDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _horizontalController.jumpTo(next);
    }
  }

  StructuredDataCellCoordinate? _cellCoordinateForOffset(Offset localPosition) {
    if (_visibleRows.isEmpty || _columns.isEmpty || _lastColumnWidths.isEmpty) {
      return null;
    }
    final rowExtent = widget.rowHeight + 1;
    final contentY = localPosition.dy + _verticalController.offset;
    final rowIndex = (contentY / rowExtent).floor();
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return null;
    }
    var contentX =
        localPosition.dx + _horizontalController.offset - _lastRowPaddingX;
    if (contentX <= 0) {
      return StructuredDataCellCoordinate(rowIndex: rowIndex, columnIndex: 0);
    }
    for (var i = 0; i < _lastColumnWidths.length; i++) {
      final width = _lastColumnWidths[i];
      if (contentX < width) {
        return StructuredDataCellCoordinate(rowIndex: rowIndex, columnIndex: i);
      }
      contentX -= width + _lastGapWidth;
    }
    return StructuredDataCellCoordinate(
      rowIndex: rowIndex,
      columnIndex: _lastColumnWidths.length - 1,
    );
  }

  StructuredDataCellCoordinate? _cellCoordinateForGlobalOffset(
    Offset globalPosition,
  ) {
    final renderBox = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(globalPosition);
    return _cellCoordinateForOffset(local);
  }

  int _columnIndexForLocalDx(double localDx) {
    if (_columns.isEmpty || _lastColumnWidths.isEmpty) {
      return 0;
    }
    var contentX = localDx + _horizontalController.offset - _lastRowPaddingX;
    if (contentX <= 0) return 0;
    for (var i = 0; i < _lastColumnWidths.length; i++) {
      final width = _lastColumnWidths[i];
      if (contentX < width) {
        return i;
      }
      contentX -= width + _lastGapWidth;
    }
    return _lastColumnWidths.length - 1;
  }

  void _beginMarqueeSelection(Offset localPosition) {
    final coordinate = _cellCoordinateForOffset(localPosition);
    if (coordinate == null) return;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (!isShift &&
        _isCellSelected(coordinate.rowIndex, coordinate.columnIndex)) {
      setState(() {
        _focusedCell = coordinate;
      });
      return;
    }
    if (_cellEditMode) {
      _exitCellEditMode(commit: false);
    }
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      _cellSelectionAnchor = coordinate;
      _cellSelectionExtent = coordinate;
      _additionalSelectedCells.clear();
    });
  }

  void _updateMarqueeSelection(Offset localPosition) {
    final coordinate = _cellCoordinateForOffset(localPosition);
    if (coordinate == null) return;
    setState(() {
      _selectedCell = coordinate;
      _focusedCell = coordinate;
      _cellSelectionExtent = coordinate;
    });
  }

  int? _rowIndexForOffset(Offset localPosition) {
    if (_visibleRows.isEmpty) return null;
    final rowExtent = widget.rowHeight + 1;
    final contentY = localPosition.dy + _verticalController.offset;
    final rowIndex = (contentY / rowExtent).floor();
    if (rowIndex < 0 || rowIndex >= _visibleRows.length) {
      return null;
    }
    return rowIndex;
  }

  void _updateCellFocus({required int rowIndex, required int columnIndex}) {
    if (!widget.cellSelectionEnabled || _visibleRows.isEmpty) {
      return;
    }
    final clampedRow = rowIndex.clamp(0, _visibleRows.length - 1);
    final clampedColumn = columnIndex.clamp(0, _columns.length - 1);
    final coordinate = StructuredDataCellCoordinate(
      rowIndex: clampedRow,
      columnIndex: clampedColumn,
    );
    if (_focusedCell == coordinate) {
      _listController.focus(clampedRow);
      return;
    }
    setState(() {
      _focusedCell = coordinate;
    });
    _listController.focus(clampedRow);
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    _scheduleScrollToRow(clampedRow);
    _scheduleScrollToColumn(clampedColumn);
  }

  void _enterCellEditMode(StructuredDataCellCoordinate coordinate) {
    if (_cellEditMode) return;
    setState(() {
      _cellEditMode = true;
    });
    widget.onCellEditRequested?.call(coordinate);
  }

  void _exitCellEditMode({required bool commit}) {
    if (!_cellEditMode) return;
    final coordinate = _selectedCell ?? _focusedCell;
    setState(() {
      _cellEditMode = false;
    });
    if (coordinate == null) return;
    if (commit) {
      widget.onCellEditCommitted?.call(coordinate);
    } else {
      widget.onCellEditCanceled?.call(coordinate);
    }
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
    _ensureCellFocus();
    final hardware = HardwareKeyboard.instance;
    final isShift = hardware.isShiftPressed;
    final isControl = hardware.isControlPressed || hardware.isMetaPressed;
    final current =
        _focusedCell ??
        _selectedCell ??
        StructuredDataCellCoordinate(
          rowIndex: _listController.focusedIndex ?? 0,
          columnIndex: 0,
        );
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      final isHandledKey =
          key == LogicalKeyboardKey.arrowUp ||
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
          key == LogicalKeyboardKey.escape ||
          (key == LogicalKeyboardKey.keyA && isControl) ||
          (key == LogicalKeyboardKey.space && (isControl || isShift));
      return isHandledKey ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.enter && isControl) {
      setState(() {
        _additionalSelectedCells.add(current);
        _cellSelectionAnchor ??= current;
        _cellSelectionExtent ??= current;
        _selectedCell ??= current;
        _focusedCell = current;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_cellEditMode) {
        _exitCellEditMode(commit: true);
        _updateCellSelection(
          rowIndex: current.rowIndex + (isShift ? -1 : 1),
          columnIndex: current.columnIndex,
        );
      } else {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: current.columnIndex,
        );
      }
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
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: nextColumn);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA && isControl) {
      if (_visibleRows.isNotEmpty && _columns.isNotEmpty) {
        setState(() {
          _cellSelectionAnchor = const StructuredDataCellCoordinate(
            rowIndex: 0,
            columnIndex: 0,
          );
          _cellSelectionExtent = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
          _selectedCell = StructuredDataCellCoordinate(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
          _focusedCell = _selectedCell;
          _additionalSelectedCells.clear();
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
          _selectedCell = current;
          _focusedCell = current;
          _additionalSelectedCells.clear();
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
          _selectedCell = current;
          _focusedCell = current;
          _additionalSelectedCells.clear();
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      final coordinate = _selectedCell ?? _focusedCell;
      if (coordinate != null) {
        if (_cellEditMode) {
          _exitCellEditMode(commit: true);
        } else {
          _enterCellEditMode(coordinate);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, -1)
          : current.rowIndex - 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: current.columnIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final nextRow = isControl
          ? _jumpRow(current.rowIndex, current.columnIndex, 1)
          : current.rowIndex + 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: nextRow,
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: nextRow, columnIndex: current.columnIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, -1)
          : current.columnIndex - 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: current.rowIndex, columnIndex: nextColumn);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      final nextColumn = isControl
          ? _jumpColumn(current.rowIndex, current.columnIndex, 1)
          : current.columnIndex + 1;
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex,
          columnIndex: nextColumn,
          extend: true,
        );
      } else {
        _updateCellFocus(rowIndex: current.rowIndex, columnIndex: nextColumn);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      if (isControl) {
        if (isShift) {
          _updateCellSelection(rowIndex: 0, columnIndex: 0, extend: true);
        } else {
          _updateCellFocus(rowIndex: 0, columnIndex: 0);
        }
      } else {
        if (isShift) {
          _updateCellSelection(
            rowIndex: current.rowIndex,
            columnIndex: 0,
            extend: true,
          );
        } else {
          _updateCellFocus(rowIndex: current.rowIndex, columnIndex: 0);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      if (isControl) {
        if (isShift) {
          _updateCellSelection(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
            extend: true,
          );
        } else {
          _updateCellFocus(
            rowIndex: _visibleRows.length - 1,
            columnIndex: _columns.length - 1,
          );
        }
      } else {
        if (isShift) {
          _updateCellSelection(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
            extend: true,
          );
        } else {
          _updateCellFocus(
            rowIndex: current.rowIndex,
            columnIndex: _columns.length - 1,
          );
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex - _pageStep(),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex - _pageStep(),
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      if (isShift) {
        _updateCellSelection(
          rowIndex: current.rowIndex + _pageStep(),
          columnIndex: current.columnIndex,
          extend: true,
        );
      } else {
        _updateCellFocus(
          rowIndex: current.rowIndex + _pageStep(),
          columnIndex: current.columnIndex,
        );
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_cellEditMode) {
        _exitCellEditMode(commit: false);
      } else {
        setState(() {
          if (_selectedCell != null) {
            _cellSelectionAnchor = _selectedCell;
            _cellSelectionExtent = _selectedCell;
          }
          _additionalSelectedCells.clear();
        });
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<StructuredDataMenuAction<T>> _contextActionsFor(
    T row,
    List<T> selectedRows,
    Offset? anchor,
  ) {
    final customBuilder = widget.rowContextMenuBuilder;
    if (customBuilder != null) {
      return customBuilder(row, selectedRows, anchor);
    }
    if (widget.rowActions.isEmpty) return const [];
    return widget.rowActions
        .map(
          (action) => StructuredDataMenuAction<T>(
            label: action.label,
            icon: action.icon,
            enabled: action.enabled,
            destructive: action.destructive,
            onSelected: (_, primary) => action.onSelected(primary),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _showContextMenu(
    T row,
    Offset position,
    List<T> selectedRows,
  ) async {
    final actions = _contextActionsFor(row, selectedRows, position);
    if (actions.isEmpty) return;
    final overlayState = Overlay.of(context, rootOverlay: true);
    final overlay = overlayState?.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }
    final base = overlay.localToGlobal(Offset.zero);
    final anchor = position;
    final left = anchor.dx - base.dx;
    final top = anchor.dy - base.dy;
    final selected = await showMenu<StructuredDataMenuAction<T>>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromLTRB(
        left,
        top,
        overlay.size.width - left,
        overlay.size.height - top,
      ),
      items: actions
          .map(
            (action) => PopupMenuItem<StructuredDataMenuAction<T>>(
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
    selected?.onSelected(selectedRows, row);
  }

  void _showContextMenuForIndex(int index, Offset position) {
    if (_visibleRows.isEmpty) return;
    if (widget.rowActions.isEmpty &&
        widget.rowContextMenuBuilder == null &&
        widget.onRowContextMenu == null) {
      return;
    }
    if (!widget.cellSelectionEnabled && widget.rowSelectionEnabled) {
      final usesExternalSelection =
          widget.rowSelectionPredicate != null ||
          widget.selectedRowsBuilder != null;
      if (!usesExternalSelection) {
        final isAlreadySelected = _listController.selectedIndices.contains(
          index,
        );
        if (!isAlreadySelected) {
          _selectSingle(index);
        }
      }
    }
    final onRowContextMenu = widget.onRowContextMenu;
    if (onRowContextMenu != null) {
      onRowContextMenu(_visibleRows[index], position);
      return;
    }
    final selectedRows = _selectedRows();
    _showContextMenu(_visibleRows[index], position, selectedRows);
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
      final isFocusedCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _focusedCell != null &&
          _focusedCell!.rowIndex == rowIndex &&
          _focusedCell!.columnIndex == i;
      final isRangeCell =
          isBodyCell &&
          widget.cellSelectionEnabled &&
          _isCellSelected(rowIndex!, i);
      final isHoveredCell = isBodyCell && _isHoveredCell(rowIndex!, i);
      final isHoveredColumn =
          widget.cellSelectionEnabled &&
          _hoveredCell != null &&
          _hoveredCell!.columnIndex == i;
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
      final focusedCellBorder = Border.all(
        color: scheme.primary.withValues(alpha: 0.6),
        width: 1.1,
      );
      final hoverFill = scheme.primary.withValues(alpha: 0.08);
      final columnHoverFill = scheme.primary.withValues(alpha: 0.02);
      final cellDecoration = BoxDecoration(
        borderRadius: roundedCorner,
        color: isRangeCell
            ? rangeFill
            : (isHoveredCell
                  ? hoverFill
                  : (isHoveredColumn ? columnHoverFill : null)),
        border: widget.cellSelectionEnabled
            ? (isSelectedCell
                  ? selectedCellBorder
                  : (isFocusedCell ? focusedCellBorder : defaultCellBorder))
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
                  final isShift = HardwareKeyboard.instance.isShiftPressed;
                  if (!isShift && _isCellSelected(rowIndex!, i)) {
                    return;
                  }
                  _handleCellTap(rowIndex, i);
                }
              },
              child: MouseRegion(
                onEnter: (_) => setState(() {
                  _hoveredCell = StructuredDataCellCoordinate(
                    rowIndex: rowIndex!,
                    columnIndex: i,
                  );
                }),
                onExit: (_) => setState(() {
                  final hovered = _hoveredCell;
                  if (hovered?.rowIndex == rowIndex &&
                      hovered?.columnIndex == i) {
                    _hoveredCell = null;
                  }
                }),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    final coordinate = StructuredDataCellCoordinate(
                      rowIndex: rowIndex!,
                      columnIndex: i,
                    );
                    _updateCellSelection(
                      rowIndex: coordinate.rowIndex,
                      columnIndex: coordinate.columnIndex,
                    );
                    _enterCellEditMode(coordinate);
                  },
                  child: SizedBox.expand(child: cellBody),
                ),
              ),
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
                _columnWidthOverrides[index] ??
                column.width ??
                columnWidths[index];
            final minWidth = max(
              _defaultMinFlexColumnWidth,
              column.minWidth ?? 0,
            );
            _columnWidthOverrides[index] = max(minWidth, current + delta);
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
              cursor: sortable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Row(children: [Expanded(child: headerCellDecorated)]),
            ),
          );

          final dragFeedback = Material(
            color: Colors.transparent,
            child: Container(
              width: columnWidths[index] + (hasSpacing ? 0.0 : handleWidth),
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
                      right: index == _columns.length - 1
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
    final selected =
        widget.rowSelectionPredicate?.call(row) ??
        _listController.selectedIndices.contains(index);
    final focused = _listController.focusedIndex == index;
    final verticalPadding = widget.cellSelectionEnabled
        ? 0.0
        : spacing.base * 0.7;
    final gapWidth = widget.cellSelectionEnabled ? 0.0 : spacing.base * 1.5;
    final rowContentWidth =
        _tableContentWidth(columnWidths, gapWidth) +
        (widget.cellSelectionEnabled ? 0.0 : 1.0);

    final stripeBackground = widget.cellSelectionEnabled
        ? Colors.transparent
        : (widget.useZebraStripes
              ? (index.isEven
                    ? listTokens.stripeEvenBackground
                    : listTokens.stripeOddBackground)
              : Colors.transparent);
    final rowHoverBackground =
        widget.cellSelectionEnabled &&
            _hoveredCell != null &&
            _hoveredCell!.rowIndex == index
        ? listTokens.hoverBackground.withValues(alpha: 0.12)
        : Colors.transparent;
    final background = widget.cellSelectionEnabled
        ? rowHoverBackground
        : (selected ? listTokens.selectedBackground : stripeBackground);
    final overlayColor = widget.cellSelectionEnabled
        ? WidgetStateProperty.all(Colors.transparent)
        : WidgetStateProperty.resolveWith<Color?>((states) {
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

    final allowRowDrag =
        !widget.cellSelectionEnabled && widget.rowDragPayloadBuilder != null;
    final rowContent = Material(
      color: background,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          widget.onRowPointerDown?.call(index, row, event);
          tapPosition = event.position;
          if ((event.buttons & kPrimaryButton) != 0) {
            if (!widget.cellSelectionEnabled) {
              final canDragRows = widget.rowDragPayloadBuilder != null;
              final isShift = HardwareKeyboard.instance.isShiftPressed;
              if (!(canDragRows &&
                  _listController.selectedIndices.contains(index) &&
                  !isShift)) {
                _handleRowTapSelection(index);
              }
            }
            widget.onRowTap?.call(row);
          }
        },
        onPointerMove: (event) =>
            widget.onRowPointerMove?.call(index, row, event),
        onPointerUp: (event) => widget.onRowPointerUp?.call(index, row, event),
        onPointerCancel: (event) =>
            widget.onRowPointerCancel?.call(index, row, event),
        child: MouseRegion(
          onEnter: widget.onRowPointerEnter == null
              ? null
              : (event) => widget.onRowPointerEnter?.call(index, row, event),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) {
              tapPosition = details.globalPosition;
              if (widget.cellSelectionEnabled) {
                final columnIndex = _columnIndexForLocalDx(
                  details.localPosition.dx,
                );
                if (!_isCellSelected(index, columnIndex)) {
                  _updateCellSelection(
                    rowIndex: index,
                    columnIndex: columnIndex,
                  );
                }
              }
              _showContextMenuForIndex(index, details.globalPosition);
            },
            onLongPressStart: allowRowDrag
                ? null
                : (details) {
                    tapPosition = details.globalPosition;
                    if (widget.cellSelectionEnabled) {
                      final columnIndex = _columnIndexForLocalDx(
                        details.localPosition.dx,
                      );
                      if (!_isCellSelected(index, columnIndex)) {
                        _updateCellSelection(
                          rowIndex: index,
                          columnIndex: columnIndex,
                        );
                      }
                    }
                    _showContextMenuForIndex(index, details.globalPosition);
                  },
            onDoubleTap: () {
              if (widget.primaryDoubleClickOpensContextMenu) {
                final renderBox =
                    _bodyKey.currentContext?.findRenderObject() as RenderBox?;
                final position =
                    tapPosition ??
                    renderBox?.localToGlobal(Offset.zero) ??
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
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!allowRowDrag) {
      return rowContent;
    }
    return LongPressDraggable<Object>(
      data: widget.rowDragPayloadBuilder!(
        row,
        _listController.selectedIndices.contains(index)
            ? _selectedRows()
            : [row],
      ),
      feedback:
          widget.rowDragFeedbackBuilder?.call(
            context,
            row,
            _listController.selectedIndices.contains(index)
                ? _selectedRows()
                : [row],
          ) ??
          Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: spacing.xs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                _listController.selectedIndices.contains(index)
                    ? _selectedRows().length > 1
                          ? '${_selectedRows().length} rows'
                          : '1 row'
                    : '1 row',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      delay: const Duration(milliseconds: 150),
      onDragStarted: () {
        if (!_listController.selectedIndices.contains(index)) {
          _selectSingle(index);
        }
      },
      child: rowContent,
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
    final surfaceBackground =
        widget.surfaceBackgroundColor ?? surface.background;

    if (_visibleRows.isEmpty && widget.emptyState != null) {
      return Container(
        decoration: BoxDecoration(
          color: surfaceBackground,
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
        final contentWidth =
            _tableContentWidth(columnWidths, gapWidth) +
            (widget.cellSelectionEnabled ? 0.0 : 1.0);
        final paddedWidth = contentWidth + 2 * max(headerPaddingX, rowPaddingX);
        final targetWidth =
            max(constraints.maxWidth, paddedWidth + verticalScrollbarSpace) +
            1.0;

        const verticalScrollbarWidth = 10.0;
        const horizontalScrollbarThickness = 10.0;
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final body = Column(
          children: [
            _buildHeader(context, columnWidths, gapWidth),
            if (hasBoundedHeight)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _buildBody(surface, columnWidths),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _buildBody(surface, columnWidths),
              ),
          ],
        );
        return Container(
          margin: surface.margin,
          decoration: BoxDecoration(
            color: surfaceBackground,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: surface.borderColor.withValues(alpha: 0.2),
              width: 0.4,
            ),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: hasBoundedHeight ? constraints.maxHeight : null,
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
                    height: hasBoundedHeight ? constraints.maxHeight : null,
                    child: body,
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
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              _touchDragPointer = event.pointer;
              _isTouchDragging = true;
              _beginMarqueeSelection(event.localPosition);
              return;
            }
            if (event.kind != PointerDeviceKind.mouse) return;
            if ((event.buttons & kPrimaryButton) == 0) return;
            _marqueePointer = event.pointer;
            _isMarqueeSelecting = true;
            _beginMarqueeSelection(event.localPosition);
          },
          onPointerMove: (event) {
            if (_isTouchDragging && _touchDragPointer == event.pointer) {
              _updateMarqueeSelection(event.localPosition);
              _applyEdgeScroll(event.localPosition);
              return;
            }
            if (!_isMarqueeSelecting || _marqueePointer != event.pointer) {
              return;
            }
            _updateMarqueeSelection(event.localPosition);
          },
          onPointerUp: (event) {
            if (_touchDragPointer == event.pointer) {
              _touchDragPointer = null;
              _isTouchDragging = false;
            }
            if (_marqueePointer == event.pointer) {
              _marqueePointer = null;
              _isMarqueeSelecting = false;
            }
          },
          onPointerCancel: (event) {
            if (_touchDragPointer == event.pointer) {
              _touchDragPointer = null;
              _isTouchDragging = false;
            }
            if (_marqueePointer == event.pointer) {
              _marqueePointer = null;
              _isMarqueeSelecting = false;
            }
          },
          child: Container(key: _bodyKey, child: listView),
        ),
      );
    }

    final listContent = widget.onBackgroundContextMenu == null
        ? listView
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapDown: (details) {
              final rowIndex = _rowIndexForOffset(details.localPosition);
              if (rowIndex != null) {
                return;
              }
              widget.onBackgroundContextMenu?.call(details.globalPosition);
            },
            child: listView,
          );
    final focusNode = widget.focusNode ?? _focusNode;
    final keyboardWrapped = widget.enableKeyboardNavigation
        ? SelectableListKeyboardHandler(
            controller: _listController,
            itemCount: _visibleRows.length,
            focusNode: focusNode,
            onActivate: (index) => _handleDoubleTap(index),
            child: listContent,
          )
        : Focus(
            focusNode: focusNode,
            onKeyEvent: widget.onKeyEvent,
            child: listContent,
          );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!widget.rowSelectionEnabled) return;
        if (event.kind != PointerDeviceKind.mouse) return;
        if ((event.buttons & kPrimaryButton) == 0) return;
        final rowIndex = _rowIndexForOffset(event.localPosition);
        if (rowIndex == null) return;
        final canDragRows = widget.rowDragPayloadBuilder != null;
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (canDragRows &&
            _listController.selectedIndices.contains(rowIndex) &&
            !isShift) {
          return;
        }
        _marqueePointer = event.pointer;
        _isMarqueeSelecting = true;
        if (isShift) {
          _listController.extendSelection(rowIndex);
        } else {
          _handleRowTapSelection(rowIndex);
        }
      },
      onPointerMove: (event) {
        if (!widget.rowSelectionEnabled) return;
        if (!_isMarqueeSelecting || _marqueePointer != event.pointer) return;
        final rowIndex = _rowIndexForOffset(event.localPosition);
        if (rowIndex == null) return;
        _listController.extendSelection(rowIndex);
      },
      onPointerUp: (event) {
        if (_marqueePointer == event.pointer) {
          _marqueePointer = null;
          _isMarqueeSelecting = false;
        }
      },
      onPointerCancel: (event) {
        if (_marqueePointer == event.pointer) {
          _marqueePointer = null;
          _isMarqueeSelecting = false;
        }
      },
      child: keyboardWrapped,
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
