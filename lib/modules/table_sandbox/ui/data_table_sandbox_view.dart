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

  late final List<StructuredDataColumn<WideRow>> _columns;
  late List<WideRow> _paginatedRows;
  late List<WideRow> _fullRows;
  late final ScrollController _paginatedHorizontal;
  late final ScrollController _paginatedVertical;
  late final ScrollController _fullHorizontal;
  late final ScrollController _fullVertical;
  late final ScrollController _containerHorizontal;
  late final ScrollController _containerVertical;
  int _rowCountSetting = _initialRowCount;
  bool _cellSelectionEnabled = false;
  final Map<String, StructuredDataCellCoordinate?> _cellSelections = {};
  final Map<String, _DropState> _dropStates = {};

  @override
  void initState() {
    super.initState();
    _columns = _wideColumns(columnCount: _gridColumns);
    _paginatedHorizontal = ScrollController();
    _paginatedVertical = ScrollController();
    _fullHorizontal = ScrollController();
    _fullVertical = ScrollController();
    _containerHorizontal = ScrollController();
    _containerVertical = ScrollController();
    _resetRows();
  }

  @override
  void dispose() {
    _paginatedHorizontal.dispose();
    _paginatedVertical.dispose();
    _fullHorizontal.dispose();
    _fullVertical.dispose();
    _containerHorizontal.dispose();
    _containerVertical.dispose();
    super.dispose();
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
      _paginatedRows = _paginatedRows
          .map((row) => row.copyWith(seed: rand.nextInt(1000000)))
          .toList(growable: false);
      _fullRows = _fullRows
          .map((row) => row.copyWith(seed: rand.nextInt(1000000)))
          .toList(growable: false);
    });
  }

  void _resetRows() {
    _paginatedRows = _buildSeedRows(
      rowCount: _rowCountSetting,
      columnCount: _gridColumns,
      prefix: 'P',
    );
    _fullRows = _buildSeedRows(
      rowCount: _rowCountSetting,
      columnCount: _gridColumns,
      prefix: 'F',
    );
  }

  Future<void> _editCell(
    String panelId,
    StructuredDataCellCoordinate coordinate,
  ) async {
    final rows = panelId == 'A' ? _paginatedRows : _fullRows;
    if (coordinate.rowIndex < 0 || coordinate.rowIndex >= rows.length) {
      return;
    }
    if (coordinate.columnIndex < 0 ||
        coordinate.columnIndex >= rows[coordinate.rowIndex].cells.length) {
      return;
    }
    final row = rows[coordinate.rowIndex];
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
      if (panelId == 'A') {
        _paginatedRows = List<WideRow>.from(_paginatedRows)
          ..[coordinate.rowIndex] = updatedRow;
      } else {
        _fullRows = List<WideRow>.from(_fullRows)
          ..[coordinate.rowIndex] = updatedRow;
      }
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
        _cellSelections.clear();
      }
    });
  }

  List<StructuredDataAction<WideRow>> _actions(String labelPrefix) => [
    StructuredDataAction<WideRow>(
      label: '$labelPrefix Open',
      icon: Icons.open_in_new,
      onSelected: (row) => _notify('Open → ${row.cells.first}'),
    ),
    StructuredDataAction<WideRow>(
      label: '$labelPrefix Inspect',
      icon: Icons.search,
      onSelected: (row) => _notify('Inspect → ${row.cells.first}'),
    ),
  ];

  _DropState _dropStateFor(String panelId) =>
      _dropStates[panelId] ?? const _DropState();

  bool _acceptsPayload(String panelId, _RowDragPayload payload) {
    if (panelId == 'containers') {
      return payload.sourceType is ContainerEntryType;
    }
    return payload.sourceType is ExplorerEntryType;
  }

  String _dropMessage(String panelId, _RowDragPayload payload, bool accepts) {
    final label = payload.sourceLabel;
    if (!accepts) {
      return panelId == 'containers'
          ? 'Container list does not accept explorer items'
          : 'Explorer list does not accept container items';
    }
    return 'Copy $label here';
  }

  void _setDropState(
    String panelId, {
    required bool isOver,
    required bool accepts,
    String? message,
  }) {
    setState(() {
      _dropStates[panelId] = _DropState(
        isOver: isOver,
        accepts: accepts,
        message: message ?? '',
      );
    });
  }

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
                FilledButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Shuffle data'),
                  onPressed: _shuffleMetrics,
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Text(
              'Diff-style demo with 20 columns using two grid configurations '
              'to showcase pagination on and off.',
              style: typography.body.copyWith(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Text(
                  'Rows visible: $_rowCountSetting',
                  style: typography.body,
                ),
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
                Text(
                  'Enable cell selection',
                  style: typography.body,
                ),
                SizedBox(width: spacing.md),
                Switch(
                  value: _cellSelectionEnabled,
                  onChanged: (value) => setState(() {
                    _cellSelectionEnabled = value;
                    if (!value) {
                      _cellSelections.clear();
                    }
                  }),
                ),
                if (_cellSelectionEnabled)
                  SizedBox(width: spacing.md),
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
                  'Selected coordinates appear under each grid.',
                  style: textTheme.bodySmall,
                ),
              ),
            if (_cellSelectionEnabled)
              Padding(
                padding: EdgeInsets.only(top: spacing.xs),
                child: Text(
                  'Row selection is disabled while cell selection is active.',
                  style: textTheme.bodySmall,
                ),
              ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildGridPanel(
                            title: 'Explorer Files (A)',
                            subtitle: '$_rowCountSetting rows visible',
                            rows: _paginatedRows,
                            paginationEnabled: false,
                            horizontalController: _paginatedHorizontal,
                            verticalController: _paginatedVertical,
                            actionsPrefix: 'A',
                            panelId: 'A',
                            cellSelectionEnabled: _cellSelectionEnabled,
                          ),
                        ),
                        SizedBox(width: spacing.md),
                        Expanded(
                          child: _buildGridPanel(
                            title: 'Explorer Files (B)',
                            subtitle: '$_rowCountSetting rows visible',
                            rows: _fullRows,
                            paginationEnabled: false,
                            horizontalController: _fullHorizontal,
                            verticalController: _fullVertical,
                            actionsPrefix: 'B',
                            panelId: 'B',
                            cellSelectionEnabled: _cellSelectionEnabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: _buildGridPanel(
                      title: 'Containers',
                      subtitle: '$_rowCountSetting rows visible',
                      rows: _fullRows,
                      paginationEnabled: false,
                      horizontalController: _containerHorizontal,
                      verticalController: _containerVertical,
                      actionsPrefix: 'C',
                      panelId: 'containers',
                      cellSelectionEnabled: _cellSelectionEnabled,
                    ),
                  ),
                ],
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
    required bool paginationEnabled,
    required ScrollController horizontalController,
    required ScrollController verticalController,
    required String actionsPrefix,
    required String panelId,
    required bool cellSelectionEnabled,
  }) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dropState = _dropStateFor(panelId);
    final selectionLabel =
        cellSelectionEnabled ? _selectedCellLabel(panelId) : null;
    final selectionInfo = cellSelectionEnabled
        ? (selectionLabel != null
            ? 'Selected cell: $selectionLabel'
            : 'Tap any cell to highlight it')
        : null;

    return DragTarget<_RowDragPayload>(
      onWillAcceptWithDetails: (details) {
        final accepts = _acceptsPayload(panelId, details.data);
        _setDropState(
          panelId,
          isOver: true,
          accepts: accepts,
          message: _dropMessage(panelId, details.data, accepts),
        );
        return accepts;
      },
      onAcceptWithDetails: (details) {
        final accepts = _acceptsPayload(panelId, details.data);
        _setDropState(panelId, isOver: false, accepts: accepts);
        _notify(_dropMessage(panelId, details.data, accepts));
      },
      onLeave: (details) {
        _setDropState(panelId, isOver: false, accepts: true, message: '');
      },
      builder: (context, candidateData, rejectedData) {
        final borderColor = dropState.isOver
            ? (dropState.accepts
                ? scheme.primary
                : scheme.error.withValues(alpha: 0.7))
            : scheme.outlineVariant;
        final dropOverlayColor = dropState.isOver
            ? (dropState.accepts
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.error.withValues(alpha: 0.08))
            : Colors.transparent;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: dropState.isOver ? 1.2 : 1),
          ),
          padding: EdgeInsets.all(spacing.base * 1.2),
          child: Stack(
            children: [
              Column(
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
                      actions: _actions(actionsPrefix),
                      horizontalController: horizontalController,
                      verticalController: verticalController,
                      onRowDoubleTap: (row) => _notify('Open ${row.cells.first}'),
                      rowHeight: 48,
                      paginationEnabled: paginationEnabled,
                      cellSelectionEnabled: cellSelectionEnabled,
                      onCellTap: cellSelectionEnabled
                          ? (coordinate) => _handleCellSelection(
                                panelId,
                                coordinate,
                              )
                          : null,
                      onCellEditRequested: cellSelectionEnabled
                          ? (coordinate) => _editCell(panelId, coordinate)
                          : null,
                      onCellEditCommitted: cellSelectionEnabled
                          ? (coordinate) => _notify(
                                'Committed ${_formatCellCoordinate(coordinate)}',
                              )
                          : null,
                      onCellEditCanceled: cellSelectionEnabled
                          ? (coordinate) => _notify(
                                'Canceled ${_formatCellCoordinate(coordinate)}',
                              )
                          : null,
                      onFillHandleCopy: cellSelectionEnabled
                          ? (sourceRange, targetRange) => _applyFillHandleCopy(
                                panelId,
                                sourceRange,
                                targetRange,
                              )
                          : null,
                      rowDragPayloadBuilder: (row, selected) => _RowDragPayload(
                        sourceType: panelId == 'containers'
                            ? ContainerEntryType.container
                            : ExplorerEntryType.file,
                        sourceLocation: panelId == 'A'
                            ? 'server:prod_db'
                            : panelId == 'B'
                                ? 'server:staging_fs'
                                : 'docker:local',
                        rows: selected,
                      ),
                      rowDragFeedbackBuilder: (context, row, selected) =>
                          _DragFeedbackChip(
                        label: _RowDragPayload(
                          sourceType: panelId == 'containers'
                              ? ContainerEntryType.container
                              : ExplorerEntryType.file,
                          sourceLocation: panelId == 'A'
                              ? 'server:prod_db'
                              : panelId == 'B'
                                  ? 'server:staging_fs'
                                  : 'docker:local',
                          rows: selected,
                        ).sourceLabel,
                        count: selected.length,
                      ),
                    ),
                  ),
                  if (selectionInfo != null) ...[
                    SizedBox(height: spacing.sm),
                    Text(selectionInfo, style: textTheme.bodySmall),
                  ],
                ],
              ),
              if (dropState.isOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: dropOverlayColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.only(top: spacing.sm),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          dropState.message,
                          style: textTheme.bodySmall?.copyWith(
                            color: dropState.accepts
                                ? scheme.primary
                                : scheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleCellSelection(
    String panelId,
    StructuredDataCellCoordinate coordinate,
  ) {
    setState(() {
      _cellSelections[panelId] = coordinate;
    });
  }

  String? _selectedCellLabel(String panelId) {
    final selection = _cellSelections[panelId];
    if (selection == null) return null;
    return _formatCellCoordinate(selection);
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
    String panelId,
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange,
  ) {
    if (panelId == 'containers') {
      _copyCellsInList(_fullRows, sourceRange, targetRange, updateFull: true);
      return;
    }
    if (panelId == 'A') {
      _copyCellsInList(_paginatedRows, sourceRange, targetRange, updatePaginated: true);
      return;
    }
    _copyCellsInList(_fullRows, sourceRange, targetRange, updateFull: true);
  }

  void _copyCellsInList(
    List<WideRow> rows,
    StructuredDataCellRange sourceRange,
    StructuredDataCellRange targetRange, {
    bool updatePaginated = false,
    bool updateFull = false,
  }) {
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
      if (updatePaginated) {
        _paginatedRows = updatedRows;
      }
      if (updateFull) {
        _fullRows = updatedRows;
      }
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

enum ExplorerEntryType { file, folder }

enum ContainerEntryType { container }

class _RowDragPayload {
  const _RowDragPayload({
    required this.sourceType,
    required this.sourceLocation,
    required this.rows,
  });

  final Object sourceType;
  final String sourceLocation;
  final List<WideRow> rows;

  String get sourceLabel {
    final typeLabel = switch (sourceType) {
      ExplorerEntryType.file => 'explorer file',
      ExplorerEntryType.folder => 'explorer folder',
      ContainerEntryType.container => 'container',
      _ => 'item',
    };
    return '$typeLabel - $sourceLocation';
  }
}

class _DropState {
  const _DropState({
    this.isOver = false,
    this.accepts = true,
    this.message = '',
  });

  final bool isOver;
  final bool accepts;
  final String message;
}

class _DragFeedbackChip extends StatelessWidget {
  const _DragFeedbackChip({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.base,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(width: spacing.sm),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${count.clamp(1, 999)}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
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
      (c) => '$prefix R$r-C$c',
      growable: false,
    );
    rows.add(WideRow(cells: cells));
  }
  return rows;
}

List<StructuredDataColumn<WideRow>> _wideColumns({
  required int columnCount,
}) {
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
