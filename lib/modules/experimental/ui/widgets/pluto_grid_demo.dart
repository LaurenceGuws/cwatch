import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

class PlutoGridDemo extends StatefulWidget {
  const PlutoGridDemo({super.key});

  @override
  State<PlutoGridDemo> createState() => _PlutoGridDemoState();
}

class _PlutoGridDemoState extends State<PlutoGridDemo> {
  late final List<PlutoColumn> _columns;
  late final List<PlutoRow> _rows;

  @override
  void initState() {
    super.initState();
    _columns = List.generate(
      5,
      (index) => PlutoColumn(
        title: 'C${index + 1}',
        field: 'c$index',
        type: PlutoColumnType.text(),
      ),
    );
    _rows = List.generate(
      300,
      (row) => PlutoRow(
        cells: {
          for (var col = 0; col < _columns.length; col++)
            'c$col': PlutoCell(value: 'R${row + 1}C${col + 1}'),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PlutoGrid demo (300x5)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 400,
          child: PlutoGrid(
            columns: _columns,
            rows: _rows,
            onLoaded: (event) {
              event.stateManager.setShowColumnFilter(false);
            },
            configuration: PlutoGridConfiguration(
              style: PlutoGridStyleConfig(
                gridBackgroundColor: scheme.surface,
                gridBorderColor: scheme.outlineVariant,
                gridBorderRadius: BorderRadius.circular(12),
                columnHeight: 44,
                rowHeight: 44,
                activatedColor: scheme.primary.withValues(alpha: 0.08),
                activatedBorderColor: scheme.primary,
                cellTextStyle: textTheme.bodyMedium!,
                columnTextStyle: textTheme.labelMedium!,
                cellColorInReadOnlyState: scheme.surface,
                cellColorInEditState: scheme.surface,
                rowColor: scheme.surface,
                oddRowColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
                enableCellBorderHorizontal: false,
                enableCellBorderVertical: false,
              ),
              columnSize: const PlutoGridColumnSizeConfig(
                autoSizeMode: PlutoAutoSizeMode.scale,
                resizeMode: PlutoResizeMode.normal,
              ),
              columnFilter: PlutoGridColumnFilterConfig(
                resolveDefaultColumnFilter: (column, resolver) =>
                    resolver<PlutoFilterTypeContains>()!,
              ),
              scrollbar: PlutoGridScrollbarConfig(
                isAlwaysShown: true,
                onlyDraggingThumb: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
