// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableColumns<T> on _StructuredDataTableStateBase<T> {
  StructuredDataTableProjection<T> get _projection =>
      StructuredDataTableProjection<T>();
  StructuredDataTableColumnWidthPlanner<T> get _columnWidthPlanner =>
      StructuredDataTableColumnWidthPlanner<T>();

  List<T> get _visibleRows {
    final filtered = _applySearch(widget.rows);
    return _projection.sortVisibleRows(
      rows: filtered,
      columns: _columns,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
    );
  }

  List<T> _applySearch(List<T> rows) {
    return _projection.applySearch(
      rows: rows,
      query: widget.searchQuery,
      columns: _columns,
      rowSearchTextBuilder: widget.rowSearchTextBuilder,
    );
  }

  List<StructuredDataColumn<T>> _buildVisibleColumns() {
    return _projection.buildVisibleColumns(
      columns: widget.columns,
      hiddenColumnIds: widget.hiddenColumnIds,
      columnIdBuilder: widget.columnIdBuilder,
    );
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
    return _projection.sortValueForColumn(_columns, index);
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
    final minWidth = max(_minColumnWidth, column.minWidth ?? 0);
    final maxAllowed = _maxWidthForColumn(index);

    _autoFitCache[index] = maxWidth;

    setState(() {
      _columnWidthOverrides[index] = _clampWidth(target, minWidth, maxAllowed);
    });
  }

  double _tableContentWidth(List<double> columnWidths, double gapWidth) {
    return _columnWidthPlanner.tableContentWidth(columnWidths, gapWidth);
  }

  double _minWidthForColumn(int index, {required bool respectOverride}) {
    final column = _columns[index];
    final override = index < _columnWidthOverrides.length
        ? _columnWidthOverrides[index]
        : null;
    if (respectOverride && override != null) {
      return max(column.minWidth ?? 0, override);
    }
    if (respectOverride && column.width != null) {
      return max(column.minWidth ?? 0, column.width!);
    }
    return max(_minColumnWidth, column.minWidth ?? 0);
  }

  double _clampWidth(double target, double minWidth, double maxWidth) {
    if (!maxWidth.isFinite) return max(minWidth, target);
    if (maxWidth <= minWidth) return minWidth;
    return target.clamp(minWidth, maxWidth);
  }

  double _maxWidthForColumn(int index) {
    if (!widget.fitColumnsToWidth) return double.infinity;
    if (_lastContentWidth <= 0) return double.infinity;
    var otherMinTotal = 0.0;
    for (var i = 0; i < _columns.length; i++) {
      if (i == index) continue;
      otherMinTotal += _minWidthForColumn(i, respectOverride: true);
    }
    final minWidth = _minWidthForColumn(index, respectOverride: false);
    final maxAllowed = _lastContentWidth - otherMinTotal;
    return max(minWidth, maxAllowed);
  }

  double get _minColumnWidth {
    return widget.fitColumnsToWidth
        ? _defaultMinFitColumnWidth
        : _defaultMinFlexColumnWidth;
  }

  void _handleExternalRefresh() {
    if (!mounted) return;
    AppLogger().debug(
      'StructuredDataTable refreshListenable fired: '
      'rows=${widget.rows.length} visible=${_visibleRows.length}',
      tag: 'StructuredDataTable',
    );
    setState(() {
      _listController.setItemCount(_visibleRows.length);
    });
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

  List<double> _computeColumnWidths(double availableWidth) {
    return _columnWidthPlanner.computeColumnWidths(
      StructuredDataTableColumnWidthPlanInput<T>(
        columns: _columns,
        columnWidthOverrides: _columnWidthOverrides,
        availableWidth: availableWidth,
        fitColumnsToWidth: widget.fitColumnsToWidth,
        minColumnWidth: _minColumnWidth,
        maxWidthForColumn: _maxWidthForColumn,
        gapWidth: widget.cellSelectionEnabled ? 0.0 : context.spacing.base * 1.5,
      ),
    );
  }
}
