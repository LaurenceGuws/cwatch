// ignore_for_file: annotate_overrides
part of 'structured_data_table.dart';

mixin _StructuredDataTableColumns<T> on _StructuredDataTableStateBase<T> {
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
    final minWidth = max(_minColumnWidth, column.minWidth ?? 0);
    final maxAllowed = _maxWidthForColumn(index);

    _autoFitCache[index] = maxWidth;

    setState(() {
      _columnWidthOverrides[index] = _clampWidth(target, minWidth, maxAllowed);
    });
  }

  double _tableContentWidth(List<double> columnWidths, double gapWidth) {
    final totalGaps = max(0, _columns.length - 1);
    final totalWidth =
        columnWidths.fold<double>(0, (sum, width) => sum + width) +
        totalGaps * gapWidth;
    return totalWidth.ceilToDouble();
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
    final flexIndices = <int>[];
    final effectiveFlexes = List<int>.filled(_columns.length, 0);
    var totalFlex = 0;
    var fixedWidth = 0.0;
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final override = i < _columnWidthOverrides.length
          ? _columnWidthOverrides[i]
          : null;
      final maxAllowed = _maxWidthForColumn(i);
      final hasExplicitWidth = override != null || column.width != null;
      var effectiveFlex = column.flex;
      if (widget.fitColumnsToWidth && effectiveFlex == 0 && !hasExplicitWidth) {
        effectiveFlex = 1;
      }
      effectiveFlexes[i] = effectiveFlex;
      final isFixed = hasExplicitWidth || effectiveFlex == 0;
      if (!isFixed) {
        flexIndices.add(i);
        totalFlex += effectiveFlex;
      } else {
        if (hasExplicitWidth) {
          final target = override ?? column.width ?? 0.0;
          final minWidth = max(column.minWidth ?? 0, target);
          fixedWidth += _clampWidth(minWidth, minWidth, maxAllowed);
        } else {
          // flex == 0, use minWidth or default
          final minWidth = max(_minColumnWidth, column.minWidth ?? 0);
          fixedWidth += _clampWidth(minWidth, minWidth, maxAllowed);
        }
      }
    }

    final minFlexWidth = flexIndices.fold<double>(
      0,
      (sum, index) => sum + max(_minColumnWidth, _columns[index].minWidth ?? 0),
    );
    final remainingForFlex = max(availableWidth - fixedWidth, minFlexWidth);
    final widths = <double>[];

    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final effectiveFlex = effectiveFlexes[i];
      final override = i < _columnWidthOverrides.length
          ? _columnWidthOverrides[i]
          : null;
      final maxAllowed = _maxWidthForColumn(i);
      if (override != null) {
        final minWidth = max(column.minWidth ?? 0, override);
        widths.add(_clampWidth(minWidth, minWidth, maxAllowed));
        continue;
      }
      if (column.width != null) {
        final minWidth = max(column.minWidth ?? 0, column.width!);
        widths.add(_clampWidth(minWidth, minWidth, maxAllowed));
        continue;
      }
      if (effectiveFlex == 0) {
        // Non-flexing column, use minWidth or default
        widths.add(max(_minColumnWidth, column.minWidth ?? 0));
        continue;
      }
      final flexShare = totalFlex == 0
          ? remainingForFlex
          : remainingForFlex / totalFlex;
      final target = totalFlex == 0
          ? remainingForFlex
          : flexShare * effectiveFlex;
      widths.add(max(_minColumnWidth, max(column.minWidth ?? 0, target)));
    }
    if (widget.fitColumnsToWidth && widths.isNotEmpty) {
      final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);
      if (totalWidth < availableWidth) {
        final extra = availableWidth - totalWidth;
        final targetIndex = _columns.length - 1;
        final maxAllowed = _maxWidthForColumn(targetIndex);
        widths[targetIndex] = _clampWidth(
          widths[targetIndex] + extra,
          widths[targetIndex],
          maxAllowed,
        );
      }
    }
    return widths;
  }
}
