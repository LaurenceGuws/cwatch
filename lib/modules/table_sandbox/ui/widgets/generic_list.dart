import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/data_table/structured_data_table.dart';

class GenericList<T> extends StatefulWidget {
  const GenericList({
    super.key,
    required this.rows,
    required this.columns,
    this.hiddenColumnIds = const {},
    this.columnIdBuilder,
    this.actions = const [],
    this.metadataBuilder,
    this.searchQuery = '',
    this.rowSearchTextBuilder,
    this.onRowDoubleTap,
    this.rowHeight = 64,
    this.horizontalController,
    this.verticalController,
    this.paginationEnabled = false,
    this.rowsPerPage = 20,
    this.onPageChanged,
    this.onRowsPerPageChanged,
    this.cellSelectionEnabled = false,
    this.onCellTap,
    this.onCellEditRequested,
    this.onCellEditCommitted,
    this.onCellEditCanceled,
    this.onFillHandleCopy,
    this.rowDragPayloadBuilder,
    this.rowDragFeedbackBuilder,
  });

  final List<T> rows;
  final List<StructuredDataColumn<T>> columns;
  final Set<String> hiddenColumnIds;
  final String Function(StructuredDataColumn<T> column)? columnIdBuilder;
  final List<StructuredDataAction<T>> actions;
  final List<StructuredDataChip> Function(T row)? metadataBuilder;
  final String searchQuery;
  final String Function(T row)? rowSearchTextBuilder;
  final ValueChanged<T>? onRowDoubleTap;
  final double rowHeight;
  final ScrollController? horizontalController;
  final ScrollController? verticalController;
  final bool paginationEnabled;
  final int rowsPerPage;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onRowsPerPageChanged;
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
  State<GenericList<T>> createState() => _GenericListState<T>();
}

class _GenericListState<T> extends State<GenericList<T>> {
  int _currentPage = 0;
  late int _activeRowsPerPage;
  static const _rowsPerPagePresets = [20, 50, 100, 500, 1000];

  @override
  void initState() {
    super.initState();
    _activeRowsPerPage = math.max(1, widget.rowsPerPage);
  }

  int get _pageCount {
    if (!widget.paginationEnabled || _activeRowsPerPage <= 0) return 1;
    if (widget.rows.isEmpty) return 1;
    return ((widget.rows.length - 1) ~/ _activeRowsPerPage) + 1;
  }

  List<T> get _visibleRows {
    if (!widget.paginationEnabled || _activeRowsPerPage <= 0) {
      return widget.rows;
    }
    if (widget.rows.isEmpty) return const [];
    final start = _currentPage * _activeRowsPerPage;
    if (start >= widget.rows.length) return const [];
    final end = math.min(start + _activeRowsPerPage, widget.rows.length);
    return widget.rows.sublist(start, end);
  }

  void _setPage(int page) {
    final target = page.clamp(0, _pageCount - 1);
    if (target == _currentPage) return;
    setState(() => _currentPage = target);
    _scrollToTop();
    widget.onPageChanged?.call(target);
  }

  void _scrollToTop() {
    final controller = widget.verticalController;
    if (controller?.hasClients == true) {
      controller!.jumpTo(controller.position.minScrollExtent);
    }
  }

  void _setRowsPerPageFromUser(int value) {
    final clamped = _clampRowsPerPage(value);
    if (clamped == _activeRowsPerPage) return;
    setState(() {
      _activeRowsPerPage = clamped;
      _clampCurrentPage();
    });
    widget.onRowsPerPageChanged?.call(clamped);
    _scrollToTop();
  }

  @override
  void didUpdateWidget(covariant GenericList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rowsPerPage != oldWidget.rowsPerPage) {
      _applyRowsPerPageFromParent(widget.rowsPerPage);
    }
    if (widget.rows != oldWidget.rows ||
        widget.paginationEnabled != oldWidget.paginationEnabled) {
      final maxPage = _pageCount - 1;
      if (_currentPage > maxPage) {
        setState(() => _currentPage = math.max(0, maxPage));
      }
    }
  }

  void _applyRowsPerPageFromParent(int value) {
    final clamped = _clampRowsPerPage(value);
    final needsUpdate = clamped != _activeRowsPerPage;
    final valueChanged = clamped != value;
    if (needsUpdate) {
      setState(() {
        _activeRowsPerPage = clamped;
        _clampCurrentPage();
      });
    } else if (_clampCurrentPage()) {
      setState(() {});
    }
    if (valueChanged) {
      widget.onRowsPerPageChanged?.call(clamped);
    }
  }

  bool _clampCurrentPage() {
    final maxPage = _pageCount - 1;
    if (_currentPage > maxPage) {
      _currentPage = math.max(0, maxPage);
      return true;
    }
    return false;
  }

  int _clampRowsPerPage(int value) {
    if (value < 1) return 1;
    final maxRows = math.max(1, widget.rows.length);
    return math.min(value, maxRows);
  }

  @override
  Widget build(BuildContext context) {
    const paginationBarHeight = 48.0;
    final verticalInset = widget.paginationEnabled ? paginationBarHeight : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: widget.paginationEnabled ? paginationBarHeight : 0,
            ),
            child: StructuredDataTable<T>(
              rows: _visibleRows,
              rowHeight: widget.rowHeight,
              shrinkToContent: false,
              columns: widget.columns,
              hiddenColumnIds: widget.hiddenColumnIds,
              columnIdBuilder: widget.columnIdBuilder,
              metadataBuilder: widget.metadataBuilder,
              searchQuery: widget.searchQuery,
              rowSearchTextBuilder: widget.rowSearchTextBuilder,
              rowActions: widget.actions,
              onRowDoubleTap: widget.onRowDoubleTap,
              horizontalController: widget.horizontalController,
              verticalController: widget.verticalController,
              verticalScrollbarBottomInset: verticalInset,
              cellSelectionEnabled: widget.cellSelectionEnabled,
              onCellTap: widget.onCellTap,
              onCellEditRequested: widget.onCellEditRequested,
              onCellEditCommitted: widget.onCellEditCommitted,
              onCellEditCanceled: widget.onCellEditCanceled,
              onFillHandleCopy: widget.onFillHandleCopy,
              rowDragPayloadBuilder: widget.rowDragPayloadBuilder,
              rowDragFeedbackBuilder: widget.rowDragFeedbackBuilder,
              emptyState: const Text('No entries match this filter.'),
            ),
          ),
        ),
        if (widget.paginationEnabled)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: paginationBarHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.appTheme.spacing.base,
              ),
              child: _buildPaginationControls(context),
            ),
          ),
      ],
    );
  }

  Widget _buildPaginationControls(BuildContext context) {
    if (!widget.paginationEnabled) {
      return const SizedBox.shrink();
    }
    final spacing = context.appTheme.spacing;
    final showNav = _pageCount > 1;
    return Padding(
      padding: EdgeInsets.only(top: spacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
            onPressed: showNav && _currentPage > 0
                ? () => _setPage(_currentPage - 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
            onPressed: showNav && _currentPage < _pageCount - 1
                ? () => _setPage(_currentPage + 1)
                : null,
          ),
          SizedBox(width: spacing.base),
          Text(
            'Page ${_currentPage + 1} of $_pageCount',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          PopupMenuButton<int>(
            tooltip: 'Change rows per page preset',
            onSelected: _setRowsPerPageFromUser,
            itemBuilder: (context) {
              final maxRows = math.max(1, widget.rows.length);
              final presetOptions = _rowsPerPagePresets
                  .where((option) => option <= maxRows)
                  .toSet();
              final options = {...presetOptions, _activeRowsPerPage}.toList()
                ..sort();
              return options
                  .map(
                    (option) => PopupMenuItem<int>(
                      value: option,
                      child: Row(
                        children: [
                          if (_activeRowsPerPage == option)
                            const Icon(Icons.check, size: 16)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('$option per page'),
                        ],
                      ),
                    ),
                  )
                  .toList();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.rows.length} rows total',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
