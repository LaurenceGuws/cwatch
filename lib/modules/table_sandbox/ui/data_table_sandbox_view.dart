import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/data_table/structured_data_table.dart';
import 'widgets/generic_list.dart';

class DataTableSandboxView extends StatefulWidget {
  const DataTableSandboxView({super.key, required this.leading});

  final Widget leading;

  @override
  State<DataTableSandboxView> createState() => _DataTableSandboxViewState();
}

class _DataTableSandboxViewState extends State<DataTableSandboxView> {
  static const int _gridColumns = 20;
  static const int _initialRowCount = 20;
  static const double _rowSliderMin = 5;
  static const double _rowSliderMax = 60;
  static const String _columnVisibilityKey = 'table_sandbox.columns';

  late final List<StructuredDataColumn<WideRow>> _columns;
  late List<WideRow> _rows;
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;
  final _visibilityStore = _ColumnVisibilityStore();
  int _rowCountSetting = _initialRowCount;
  bool _cellSelectionEnabled = false;
  StructuredDataCellCoordinate? _selectedCell;
  Set<String> _hiddenColumnIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _columns = _wideColumns(columnCount: _gridColumns);
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _resetRows();
    unawaited(_loadColumnVisibility());
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadColumnVisibility() async {
    final stored = await _visibilityStore.load(_columnVisibilityKey);
    if (!mounted) return;
    if (stored.isEmpty) return;
    final validIds = _columns.map(_columnId).toSet();
    stored.retainAll(validIds);
    if (stored.isEmpty) return;
    setState(() {
      _hiddenColumnIds = stored;
    });
  }

  Future<void> _persistColumnVisibility() async {
    await _visibilityStore.save(_columnVisibilityKey, _hiddenColumnIds);
  }

  String _columnId(StructuredDataColumn<WideRow> column) => column.label.trim();

  void _toggleColumnVisibility(String columnId) {
    final visibleCount = _columns.length - _hiddenColumnIds.length;
    setState(() {
      final nextHidden = Set<String>.from(_hiddenColumnIds);
      if (nextHidden.contains(columnId)) {
        nextHidden.remove(columnId);
      } else if (visibleCount > 1) {
        nextHidden.add(columnId);
      }
      _hiddenColumnIds = nextHidden;
    });
    unawaited(_persistColumnVisibility());
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _shuffleMetrics() {
    final rand = math.Random();
    setState(() {
      _rows = _rows
          .map((row) => row.copyWith(seed: rand.nextInt(1000000)))
          .toList(growable: false);
    });
  }

  void _resetRows() {
    _rows = _buildSeedRows(
      rowCount: _rowCountSetting,
      columnCount: _gridColumns,
      prefix: 'R',
    );
  }

  Future<void> _editCell(StructuredDataCellCoordinate coordinate) async {
    if (coordinate.rowIndex < 0 || coordinate.rowIndex >= _rows.length) {
      return;
    }
    if (coordinate.columnIndex < 0 ||
        coordinate.columnIndex >= _rows[coordinate.rowIndex].cells.length) {
      return;
    }
    final row = _rows[coordinate.rowIndex];
    final existing = row.cells[coordinate.columnIndex];
    final controller = TextEditingController(text: existing);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit cell'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || updated == null || updated == existing) {
      return;
    }
    setState(() {
      final nextCells = List<String>.from(row.cells);
      nextCells[coordinate.columnIndex] = updated;
      final updatedRow = WideRow(cells: nextCells);
      _rows = List<WideRow>.from(_rows)..[coordinate.rowIndex] = updatedRow;
    });
    _notify('Updated ${_formatCellCoordinate(coordinate)}');
  }

  void _updateRowCount(double value) {
    final base = value.round();
    final next = math.min(
      _rowSliderMax.toInt(),
      math.max(_rowSliderMin.toInt(), base),
    );
    setState(() {
      _rowCountSetting = next;
      _resetRows();
      if (_cellSelectionEnabled) {
        _selectedCell = null;
      }
    });
  }

  List<StructuredDataAction<WideRow>> get _actions => [
    StructuredDataAction<WideRow>(
      label: 'Open',
      icon: Icons.open_in_new,
      onSelected: (row) => _notify('Open → ${row.cells.first}'),
    ),
    StructuredDataAction<WideRow>(
      label: 'Inspect',
      icon: Icons.search,
      onSelected: (row) => _notify('Inspect → ${row.cells.first}'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final typography = context.appTheme.typography;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: spacing.xs),
          const Text('Sandbox'),
        ],
      ),
    );
    final visibleCount = _columns.length - _hiddenColumnIds.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.base * 0.6,
          vertical: spacing.base * 0.6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                widget.leading,
                SizedBox(width: spacing.md),
                Text('Data table lab', style: typography.sectionTitle),
                SizedBox(width: spacing.sm),
                badge,
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Toggle columns',
                  icon: const Icon(Icons.view_column),
                  onSelected: _toggleColumnVisibility,
                  itemBuilder: (context) => _columns
                      .map(
                        (column) => CheckedPopupMenuItem<String>(
                          value: _columnId(column),
                          checked: !_hiddenColumnIds.contains(
                            _columnId(column),
                          ),
                          enabled: !_hiddenColumnIds.contains(_columnId(column))
                              ? visibleCount > 1
                              : true,
                          child: Text(column.label),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(width: spacing.sm),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Shuffle data'),
                  onPressed: _shuffleMetrics,
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Diff-style demo with 20 columns to exercise selection, edit, and '
              'column visibility controls.',
              style: typography.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Text('Rows visible: $_rowCountSetting', style: typography.body),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Slider(
                    value: _rowCountSetting.toDouble(),
                    min: _rowSliderMin,
                    max: _rowSliderMax,
                    divisions: (_rowSliderMax - _rowSliderMin).toInt(),
                    label: '$_rowCountSetting rows',
                    onChanged: _updateRowCount,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _rowCountSetting = _initialRowCount;
                    _resetRows();
                  }),
                  child: const Text('Reset'),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search rows',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _searchQuery = '';
                              }),
                            ),
                    ),
                    onChanged: (value) => setState(() {
                      _searchQuery = value;
                    }),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Text('Enable cell selection', style: typography.body),
                SizedBox(width: spacing.md),
                Switch(
                  value: _cellSelectionEnabled,
                  onChanged: (value) => setState(() {
                    _cellSelectionEnabled = value;
                    if (!value) {
                      _selectedCell = null;
                    }
                  }),
                ),
                if (_cellSelectionEnabled) SizedBox(width: spacing.md),
                if (_cellSelectionEnabled)
                  Text(
                    'Tap any cell (A1-style) to highlight it.',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
            if (_cellSelectionEnabled)
              Padding(
                padding: EdgeInsets.only(top: spacing.xs),
                child: Text(
                  'Selected coordinates appear under the grid.',
                  style: textTheme.bodySmall,
                ),
              ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: _buildGridPanel(
                title: 'Explorer Files',
                subtitle: '$_rowCountSetting rows visible',
                rows: _rows,
                horizontalController: _horizontalController,
                verticalController: _verticalController,
                cellSelectionEnabled: _cellSelectionEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridPanel({
    required String title,
    required String subtitle,
    required List<WideRow> rows,
    required ScrollController horizontalController,
    required ScrollController verticalController,
    required bool cellSelectionEnabled,
  }) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selectionLabel = cellSelectionEnabled ? _selectedCellLabel() : null;
    final selectionInfo = cellSelectionEnabled
        ? (selectionLabel != null
              ? 'Selected cell: $selectionLabel'
              : 'Tap any cell to highlight it')
        : null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: EdgeInsets.all(spacing.base * 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: spacing.xs),
          Text(subtitle, style: textTheme.bodySmall),
          SizedBox(height: spacing.sm),
          Expanded(
            child: GenericList<WideRow>(
              rows: rows,
              columns: _columns,
              hiddenColumnIds: _hiddenColumnIds,
              actions: _actions,
              searchQuery: _searchQuery,
              horizontalController: horizontalController,
              verticalController: verticalController,
              onRowDoubleTap: (row) => _notify('Open ${row.cells.first}'),
              rowHeight: 48,
              paginationEnabled: false,
              cellSelectionEnabled: cellSelectionEnabled,
              onCellTap: cellSelectionEnabled
                  ? (coordinate) => _handleCellSelection(coordinate)
                  : null,
              onCellEditRequested: cellSelectionEnabled
                  ? (coordinate) => _editCell(coordinate)
                  : null,
              onCellEditCommitted: cellSelectionEnabled
                  ? (coordinate) => _notify(
                      'Committed ${_formatCellCoordinate(coordinate)}',
                    )
                  : null,
              onCellEditCanceled: cellSelectionEnabled
                  ? (coordinate) =>
                        _notify('Canceled ${_formatCellCoordinate(coordinate)}')
                  : null,
              onFillHandleCopy: cellSelectionEnabled
                  ? (sourceRange, targetRange) =>
                        _applyFillHandleCopy(sourceRange, targetRange)
                  : null,
            ),
          ),
          if (selectionInfo != null) ...[
            SizedBox(height: spacing.sm),
            Text(selectionInfo, style: textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  void _handleCellSelection(StructuredDataCellCoordinate coordinate) {
    setState(() {
      _selectedCell = coordinate;
    });
  }

  String? _selectedCellLabel() {
    if (_selectedCell == null) return null;
    return _formatCellCoordinate(_selectedCell!);
  }

  String _formatCellCoordinate(StructuredDataCellCoordinate coordinate) {
    final column = _columnLabel(coordinate.columnIndex);
    final rowNumber = coordinate.rowIndex + 1;
    return '$column$rowNumber';
  }

  String _columnLabel(int columnIndex) {
    var value = columnIndex + 1;
    final buffer = StringBuffer();
    while (value > 0) {
      final remainder = (value - 1) % 26;
      buffer.writeCharCode('A'.codeUnitAt(0) + remainder);
      value = (value - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  void _applyFillHandleCopy(
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange,
  ) {
    _copyCellsInList(_rows, sourceRange, targetRange);
  }

  void _copyCellsInList(
    List<WideRow> rows,
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange,
  ) {
    final sourceCoords = _coordsInRange(sourceRange);
    if (sourceCoords.isEmpty) return;
    final sourceValues = <String>[];
    for (final coord in sourceCoords) {
      if (coord.rowIndex >= rows.length) continue;
      final row = rows[coord.rowIndex];
      if (coord.columnIndex >= row.cells.length) continue;
      sourceValues.add(row.cells[coord.columnIndex]);
    }
    if (sourceValues.isEmpty) return;

    final targetCoords = _coordsInRange(targetRange);
    if (targetCoords.isEmpty) return;

    final updatedRows = List<WideRow>.from(rows);
    var valueIndex = 0;
    for (final coord in targetCoords) {
      if (_isWithinRange(coord, sourceRange)) {
        continue;
      }
      if (coord.rowIndex >= updatedRows.length) continue;
      final row = updatedRows[coord.rowIndex];
      if (coord.columnIndex >= row.cells.length) continue;
      final nextCells = List<String>.from(row.cells);
      nextCells[coord.columnIndex] =
          sourceValues[valueIndex % sourceValues.length];
      valueIndex += 1;
      updatedRows[coord.rowIndex] = WideRow(cells: nextCells);
    }

    setState(() {
      _rows = updatedRows;
    });
  }

  List<StructuredDataCellCoordinate> _coordsInRange(
    StructuredDataCellRange range,
  ) {
    final coords = <StructuredDataCellCoordinate>[];
    for (var r = range.top; r <= range.bottom; r++) {
      for (var c = range.left; c <= range.right; c++) {
        coords.add(StructuredDataCellCoordinate(rowIndex: r, columnIndex: c));
      }
    }
    return coords;
  }

  bool _isWithinRange(
    StructuredDataCellCoordinate coord,
    StructuredDataCellRange range,
  ) {
    return coord.rowIndex >= range.top &&
        coord.rowIndex <= range.bottom &&
        coord.columnIndex >= range.left &&
        coord.columnIndex <= range.right;
  }
}

class _ColumnVisibilityStore {
  static final Map<String, Set<String>> _store = {};

  Future<Set<String>> load(String key) async {
    final stored = _store[key];
    if (stored == null) return {};
    return Set<String>.from(stored);
  }

  Future<void> save(String key, Set<String> hiddenIds) async {
    _store[key] = Set<String>.from(hiddenIds);
  }
}

class WideRow {
  const WideRow({required this.cells});

  final List<String> cells;

  WideRow copyWith({int? seed}) {
    if (seed == null) return this;
    final rand = math.Random(seed);
    final updated = cells
        .map((value) => '$value-${rand.nextInt(999)}')
        .toList(growable: false);
    return WideRow(cells: updated);
  }
}

List<WideRow> _buildSeedRows({
  required int rowCount,
  required int columnCount,
  String prefix = '',
}) {
  final rows = <WideRow>[];
  for (var r = 0; r < rowCount; r++) {
    final cells = List<String>.generate(
      columnCount,
      (c) => '$prefix$r-C$c',
      growable: false,
    );
    rows.add(WideRow(cells: cells));
  }
  return rows;
}

List<StructuredDataColumn<WideRow>> _wideColumns({required int columnCount}) {
  return List.generate(
    columnCount,
    (index) => StructuredDataColumn<WideRow>(
      label: 'Col $index',
      autoFitText: (row) => row.cells[index],
      cellBuilder: (context, row) => Text(row.cells[index]),
    ),
    growable: false,
  );
}
