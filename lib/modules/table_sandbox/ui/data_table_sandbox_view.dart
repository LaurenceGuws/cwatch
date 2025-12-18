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
  static const int _defaultRowsPerPage = 5;
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
  int _rowCountSetting = _initialRowCount;
  int _rowsPerPageSetting = _defaultRowsPerPage;

  @override
  void initState() {
    super.initState();
    _columns = _wideColumns(columnCount: _gridColumns);
    _paginatedHorizontal = ScrollController();
    _paginatedVertical = ScrollController();
    _fullHorizontal = ScrollController();
    _fullVertical = ScrollController();
    _resetRows();
  }

  @override
  void dispose() {
    _paginatedHorizontal.dispose();
    _paginatedVertical.dispose();
    _fullHorizontal.dispose();
    _fullVertical.dispose();
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

  int _rowsPerPageMaxForCount(int count) {
    final maxLimit = _rowSliderMax.toInt();
    return math.max(1, math.min(count, maxLimit));
  }

  void _updateRowCount(double value) {
    final base = value.round();
    final next = math.min(
      _rowSliderMax.toInt(),
      math.max(_rowSliderMin.toInt(), base),
    );
    setState(() {
      _rowCountSetting = next;
      _rowsPerPageSetting =
          math.min(_rowsPerPageSetting, _rowsPerPageMaxForCount(next));
      _resetRows();
    });
  }

  void _updateRowsPerPage(double value) {
    final maxPerPage = _rowsPerPageMaxForCount(_rowCountSetting);
    final next = value.round().clamp(1, maxPerPage);
    if (next == _rowsPerPageSetting) return;
    setState(() {
      _rowsPerPageSetting = next;
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final typography = context.appTheme.typography;
    final scheme = Theme.of(context).colorScheme;
    final rowsPerPageMax = _rowsPerPageMaxForCount(_rowCountSetting);
    final rowsPerPageDivisions =
        rowsPerPageMax > 1 ? rowsPerPageMax - 1 : null;
    final rowsPerPageValue = math.max(
      1.0,
      math.min(rowsPerPageMax.toDouble(), _rowsPerPageSetting.toDouble()),
    );

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
                      _rowsPerPageSetting = _defaultRowsPerPage;
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
                  'Rows per page: $_rowsPerPageSetting',
                  style: typography.body,
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Slider(
                    value: rowsPerPageValue,
                    min: 1,
                    max: rowsPerPageMax.toDouble(),
                    divisions: rowsPerPageDivisions,
                    label: '$_rowsPerPageSetting per page',
                    onChanged: _updateRowsPerPage,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                  child: _buildGridPanel(
                    title: 'Paginated grid',
                    subtitle:
                        'Page size: $_rowsPerPageSetting • $_rowCountSetting rows total',
                    rows: _paginatedRows,
                    paginationEnabled: true,
                    horizontalController: _paginatedHorizontal,
                    verticalController: _paginatedVertical,
                    actionsPrefix: 'A',
                    rowsPerPage: _rowsPerPageSetting,
                    onRowsPerPageChanged: (selection) => setState(() {
                      _rowsPerPageSetting = selection;
                    }),
                  ),
                ),
                  SizedBox(width: spacing.md),
                  Expanded(
                  child: _buildGridPanel(
                    title: 'Full grid',
                    subtitle: 'All rows visible ($_rowCountSetting)',
                    rows: _fullRows,
                    paginationEnabled: false,
                    horizontalController: _fullHorizontal,
                    verticalController: _fullVertical,
                    actionsPrefix: 'B',
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
    ValueChanged<int>? onRowsPerPageChanged,
    int rowsPerPage = _defaultRowsPerPage,
  }) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;

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
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
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
            rowsPerPage: rowsPerPage,
            onRowsPerPageChanged: onRowsPerPageChanged,
          ),
        ),
        ],
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
