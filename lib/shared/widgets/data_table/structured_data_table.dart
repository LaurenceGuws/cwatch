import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
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
    this.autoFitWidth,
    this.autoFitExtraWidth,
  });

  final String label;
  final String? tooltip;
  final int flex;
  final Alignment alignment;
  final double? width;
  final double? minWidth;
  final Comparable<Object?>? Function(T row)? sortValue;
  final String Function(T row)? autoFitText;
  final double Function(BuildContext context, T row)? autoFitWidth;
  final double? autoFitExtraWidth;
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
  const StructuredDataChip({
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;
}

/// A flexible, list-backed data table with keyboard navigation, selection, and
/// contextual actions. Designed for complex lists like servers, clusters, and
/// explorer entries that need rich metadata and right-click menus.
class StructuredDataTable<T> extends StatefulWidget {
  StructuredDataTable({
    super.key,
    required this.rows,
    required this.columns,
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
  }) : assert(columns.isNotEmpty, 'At least one column is required');

  final List<T> rows;
  final List<StructuredDataColumn<T>> columns;
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

  @override
  State<StructuredDataTable<T>> createState() => _StructuredDataTableState<T>();
}

class _StructuredDataTableState<T> extends State<StructuredDataTable<T>> {
  late SelectableListController _listController;
  late FocusNode _focusNode;
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  static const double _defaultMinFlexColumnWidth = 180;
  late List<StructuredDataColumn<T>> _columns;
  late List<double?> _columnWidthOverrides;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<T> get _visibleRows {
    final sortIndex = _sortColumnIndex;
    if (sortIndex == null) return widget.rows;
    if (sortIndex < 0 || sortIndex >= _columns.length) return widget.rows;
    final sortValue = _columns[sortIndex].sortValue;
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
    final sortable = index >= 0 &&
        index < _columns.length &&
        _columns[index].sortValue != null;
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

    final spacing = context.appTheme.spacing;
    final headerStyle = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    final cellStyle = Theme.of(context).textTheme.bodyMedium;

    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    double headerWidth() {
      // Account for: label + sort icon (if present) + drag handle + small gaps.
      // Auto-fit is triggered via the resize handle, so the header row widgets
      // are a meaningful minimum.
      final sortable = column.sortValue != null;
      final sorted = _sortColumnIndex == index;
      final sortIconWidth = (sortable && sorted) ? 14.0 + spacing.xs : 0.0;
      final dragHandleWidth = 16.0 + spacing.xs;
      return measure(column.label, headerStyle) + sortIconWidth + dragHandleWidth;
    }

    var maxWidth = headerWidth();

    // Sample rows to keep this fast on large datasets.
    const maxSamples = 200;
    final rows = _visibleRows;
    final count = min(rows.length, maxSamples);
    for (var i = 0; i < count; i++) {
      final row = rows[i];
      if (widthExtractor != null) {
        maxWidth = max(maxWidth, widthExtractor(context, row));
      } else {
        maxWidth = max(maxWidth, measure(extractor!(row), cellStyle));
      }
    }

    // Padding budget: a conservative baseline for unknown "chrome" inside a
    // cell (pill padding, icons, chip gaps). If a column provides an explicit
    // width model via autoFitWidth, keep the baseline much smaller.
    final baselineChrome = widthExtractor != null
        ? (spacing.base * 1.5 + 8)
        : (spacing.base * 7 + 64);
    final chrome = baselineChrome + (column.autoFitExtraWidth ?? 0);
    final target = maxWidth + chrome;
    final minWidth = max(_defaultMinFlexColumnWidth, column.minWidth ?? 0);

    setState(() {
      _columnWidthOverrides[index] = max(minWidth, target);
    });
  }

  double _tableContentWidth(List<double> columnWidths) {
    final spacing = context.appTheme.spacing;
    final totalGaps = max(0, _columns.length - 1);
    final gapWidth = spacing.base * 1.5;
    return columnWidths.fold<double>(0, (sum, width) => sum + width) +
        totalGaps * gapWidth;
  }

  @override
  void initState() {
    super.initState();
    _columns = List.of(widget.columns);
    _columnWidthOverrides =
        List<double?>.filled(_columns.length, null, growable: true);
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
      _columnWidthOverrides =
          List<double?>.filled(_columns.length, null, growable: true);
      _sortColumnIndex = null;
      _sortAscending = true;
      _listController.clearSelection();
    }
    if (oldWidget.allowMultiSelect != widget.allowMultiSelect) {
      _listController
        ..removeListener(_handleSelectionChanged)
        ..dispose();
      _listController = SelectableListController(
        allowMultiSelect: widget.allowMultiSelect,
      )..addListener(_handleSelectionChanged);
    }
    _listController.setItemCount(_visibleRows.length);
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

  @override
  void dispose() {
    _listController.removeListener(_handleSelectionChanged);
    _listController.dispose();
    _focusNode.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  void _handleSelectionChanged() {
    setState(() {});
    widget.onSelectionChanged?.call(_selectedRows());
  }

  List<T> _selectedRows() => _listController.selectedIndices
      .where((index) => index < _visibleRows.length)
      .map((index) => _visibleRows[index])
      .toList(growable: false);

  void _selectSingle(int index) {
    _listController.selectSingle(index);
  }

  void _handleDoubleTap(int index) {
    if (_visibleRows.isEmpty) return;
    _selectSingle(index);
    widget.onRowDoubleTap?.call(_visibleRows[index]);
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
    _selectSingle(index);
    _showContextMenu(_visibleRows[index], position);
  }

  List<Widget> _buildRowCells(
    BuildContext context, {
    T? row,
    required bool header,
    required List<double> columnWidths,
  }) {
    assert(header || row != null, 'Row is required when rendering cells');
    final spacing = context.appTheme.spacing;
    final cells = <Widget>[];
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final content = header
          ? Text(
              column.label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              softWrap: false,
              overflow: TextOverflow.clip,
            )
          : column.cellBuilder(context, row as T);
      final aligned = Align(
        alignment: column.alignment,
        child: content,
      );
      final cell = SizedBox(width: columnWidths[i], child: aligned);
      cells.add(cell);
      if (i != _columns.length - 1) {
        cells.add(SizedBox(width: spacing.base * 1.5));
      }
    }
    return cells;
  }

  Widget _buildHeader(BuildContext context, List<double> columnWidths) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    return Container(
      height: widget.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: spacing.base * 1.2),
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
          final sortable = column.sortValue != null;
          final sorted = _sortColumnIndex == index;
          final icon =
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward;

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
                Icon(
                  icon,
                  size: 14,
                  color: scheme.primary,
                ),
              ],
            ],
          );

          final headerCell = Align(
            alignment: column.alignment,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.xs),
              child: headerContent,
            ),
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

          final dragHandle = Draggable<int>(
            data: index,
            axis: Axis.horizontal,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.base,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: DefaultTextStyle(
                  style: textStyle ?? const TextStyle(),
                  child: headerContent,
                ),
              ),
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          );

          Offset? downPosition;
          var didMove = false;

          final headerWithHandle = Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              downPosition = event.position;
              didMove = false;
            },
            onPointerMove: (event) {
              final down = downPosition;
              if (down == null || didMove) return;
              if ((event.position - down).distance > 6) {
                didMove = true;
              }
            },
            onPointerUp: (event) {
              final down = downPosition;
              if (down == null) return;
              // Treat long-press-without-move as a click: sort on pointer-up
              // as long as the user didn't drag.
              if (!didMove) _toggleSort(index);
              downPosition = null;
            },
            onPointerCancel: (_) {
              downPosition = null;
              didMove = false;
            },
            child: MouseRegion(
              cursor: sortable
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: Row(
                children: [
                  Expanded(child: headerCell),
                  SizedBox(width: spacing.xs),
                  dragHandle,
                ],
              ),
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
                child: headerWithHandle,
              );
            },
          );

          final cell = SizedBox(
            key: ValueKey('structured_data_table.header_cell.$index'),
            width: columnWidths[index],
            child: target,
          );
          if (index == _columns.length - 1) return cell;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              cell,
              SizedBox(
                width: spacing.base * 1.5,
                child: _HeaderResizeHandle(
                  key: ValueKey('structured_data_table.resize.$index'),
                  height: widget.headerHeight,
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                  onResize: (delta) {
                    setState(() {
                      final column = _columns[index];
                      final current = _columnWidthOverrides[index] ??
                          column.width ??
                          columnWidths[index];
                      final minWidth = max(
                        _defaultMinFlexColumnWidth,
                        column.minWidth ?? 0,
                      );
                      _columnWidthOverrides[index] =
                          max(minWidth, current + delta);
                    });
                  },
                  onAutoFit: () => _autoFitColumn(index),
                ),
              ),
            ],
          );
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
    final verticalPadding = spacing.base * 0.7;

    final background = selected
        ? listTokens.selectedBackground
        : Colors.transparent;
    final overlayColor = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.pressed)) {
        return listTokens.hoverBackground;
      }
      return null;
    });

    final border = focused
        ? Border.all(color: listTokens.focusOutline, width: 0.9)
        : Border.all(color: Colors.transparent, width: 0.4);

    Offset? tapPosition;

    return Material(
      color: background,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          tapPosition = event.position;
          if ((event.buttons & kPrimaryButton) != 0) {
            _selectSingle(index);
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
              final position = tapPosition ??
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
              constraints: BoxConstraints(minHeight: widget.rowHeight),
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: border,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ..._buildRowCells(
                        context,
                        row: row,
                        header: false,
                        columnWidths: columnWidths,
                      ),
                    ],
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
    final spacing = context.appTheme.spacing;

    final totalGaps = max(0, _columns.length - 1);
    final gapWidth = spacing.base * 1.5;

    var fixedWidth = 0.0;
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final override = i < _columnWidthOverrides.length
          ? _columnWidthOverrides[i]
          : null;
      fixedWidth += override ?? column.width ?? 0;
    }
    final fixedAndGaps = fixedWidth + totalGaps * gapWidth;

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

    final minFlexWidth = flexIndices.fold<double>(
      0,
      (sum, index) => sum +
          max(
            _defaultMinFlexColumnWidth,
            _columns[index].minWidth ?? 0,
          ),
    );
    final minTableWidth = fixedAndGaps + minFlexWidth;

    final tableWidth = availableWidth < minTableWidth
        ? minTableWidth
        : availableWidth;

    final remainingForFlex = tableWidth -
        fixedAndGaps;
    final widths = <double>[];

    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final override =
          i < _columnWidthOverrides.length ? _columnWidthOverrides[i] : null;
      if (override != null) {
        widths.add(max(column.minWidth ?? 0, override));
        continue;
      }
      if (column.width != null) {
        widths.add(max(column.minWidth ?? 0, column.width!));
        continue;
      }
      final flexShare =
          totalFlex == 0 ? remainingForFlex : remainingForFlex / totalFlex;
      final target = totalFlex == 0 ? 0.0 : flexShare * column.flex;
      widths.add(
        max(
          _defaultMinFlexColumnWidth,
          max(column.minWidth ?? 0, target),
        ),
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
          borderRadius: BorderRadius.circular(3),
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
        final columnWidths = _computeColumnWidths(constraints.maxWidth);
        final headerPaddingX = context.appTheme.spacing.base * 1.2;
        final rowPaddingX = context.appTheme.spacing.base;
        final contentWidth = _tableContentWidth(columnWidths);
        final paddedWidth =
            contentWidth + 2 * max(headerPaddingX, rowPaddingX);

        return Container(
          margin: surface.margin,
          decoration: BoxDecoration(
            color: surface.background,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: surface.borderColor.withValues(alpha: 0.2),
              width: 0.4,
            ),
          ),
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: max(constraints.maxWidth, paddedWidth),
                height: constraints.maxHeight,
                child: Column(
                  children: [
                    _buildHeader(context, columnWidths),
                    Expanded(
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: _buildBody(surface, columnWidths),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(AppSurfaceStyle surface, List<double> columnWidths) {
    return SelectableListKeyboardHandler(
      controller: _listController,
      itemCount: _visibleRows.length,
      focusNode: _focusNode,
      onActivate: (index) => _handleDoubleTap(index),
      child: ListView.separated(
        controller: _verticalController,
        padding: EdgeInsets.zero,
        shrinkWrap: widget.shrinkToContent,
        primary: false,
        physics: const ClampingScrollPhysics(),
        itemCount: _visibleRows.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: surface.borderColor.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) =>
            _buildRow(context, index, columnWidths),
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
