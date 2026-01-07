part of 'structured_data_table.dart';

/// Declarative column definition for [StructuredDataTable].
class StructuredDataColumn<T> {
  const StructuredDataColumn({
    required this.label,
    required this.cellBuilder,
    this.tooltip,
    this.flex = 0,
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
