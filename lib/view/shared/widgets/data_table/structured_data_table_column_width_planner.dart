part of 'structured_data_table.dart';

class StructuredDataTableColumnWidthPlanInput<T> {
  const StructuredDataTableColumnWidthPlanInput({
    required this.columns,
    required this.columnWidthOverrides,
    required this.availableWidth,
    required this.fitColumnsToWidth,
    required this.minColumnWidth,
    required this.maxWidthForColumn,
    required this.gapWidth,
  });

  final List<StructuredDataColumn<T>> columns;
  final List<double?> columnWidthOverrides;
  final double availableWidth;
  final bool fitColumnsToWidth;
  final double minColumnWidth;
  final double Function(int index) maxWidthForColumn;
  final double gapWidth;
}

class StructuredDataTableColumnWidthPlanner<T> {
  const StructuredDataTableColumnWidthPlanner();

  double tableContentWidth(List<double> columnWidths, double gapWidth) {
    final totalGaps = max(0, columnWidths.length - 1);
    final totalWidth =
        columnWidths.fold<double>(0, (sum, width) => sum + width) +
        totalGaps * gapWidth;
    return totalWidth.ceilToDouble();
  }

  List<double> computeColumnWidths(
    StructuredDataTableColumnWidthPlanInput<T> input,
  ) {
    final columns = input.columns;
    final columnWidthOverrides = input.columnWidthOverrides;
    final availableWidth = input.availableWidth;
    final fitColumnsToWidth = input.fitColumnsToWidth;
    final minColumnWidth = input.minColumnWidth;

    double clampWidth(double target, double minWidth, double maxWidth) {
      if (!maxWidth.isFinite) return max(minWidth, target);
      if (maxWidth <= minWidth) return minWidth;
      return target.clamp(minWidth, maxWidth);
    }

    final flexIndices = <int>[];
    final effectiveFlexes = List<int>.filled(columns.length, 0);
    var totalFlex = 0;
    var fixedWidth = 0.0;
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final override = i < columnWidthOverrides.length
          ? columnWidthOverrides[i]
          : null;
      final maxAllowed = input.maxWidthForColumn(i);
      final hasExplicitWidth = override != null || column.width != null;
      var effectiveFlex = column.flex;
      if (fitColumnsToWidth && effectiveFlex == 0 && !hasExplicitWidth) {
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
          fixedWidth += clampWidth(target, minWidth, maxAllowed);
        } else {
          final minWidth = max(minColumnWidth, column.minWidth ?? 0);
          fixedWidth += clampWidth(minWidth, minWidth, maxAllowed);
        }
      }
    }

    final minFlexWidth = flexIndices.fold<double>(
      0,
      (sum, index) => sum + max(minColumnWidth, columns[index].minWidth ?? 0),
    );
    final remainingForFlex = max(availableWidth - fixedWidth, minFlexWidth);
    final widths = <double>[];

    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final effectiveFlex = effectiveFlexes[i];
      final override = i < columnWidthOverrides.length
          ? columnWidthOverrides[i]
          : null;
      final maxAllowed = input.maxWidthForColumn(i);
      if (override != null) {
        final minWidth = max(column.minWidth ?? 0, override);
        widths.add(clampWidth(override, minWidth, maxAllowed));
        continue;
      }
      if (column.width != null) {
        final minWidth = max(column.minWidth ?? 0, column.width!);
        widths.add(clampWidth(column.width!, minWidth, maxAllowed));
        continue;
      }
      if (effectiveFlex == 0) {
        widths.add(max(minColumnWidth, column.minWidth ?? 0));
        continue;
      }
      final flexShare = totalFlex == 0
          ? remainingForFlex
          : remainingForFlex / totalFlex;
      final target = totalFlex == 0
          ? remainingForFlex
          : flexShare * effectiveFlex;
      widths.add(max(minColumnWidth, max(column.minWidth ?? 0, target)));
    }

    if (fitColumnsToWidth && widths.isNotEmpty) {
      final totalWidth = widths.fold<double>(0, (sum, width) => sum + width);
      if (totalWidth < availableWidth) {
        final extra = availableWidth - totalWidth;
        final targetIndex = columns.length - 1;
        final maxAllowed = input.maxWidthForColumn(targetIndex);
        widths[targetIndex] = clampWidth(
          widths[targetIndex] + extra,
          widths[targetIndex],
          maxAllowed,
        );
      }
    }

    return widths;
  }
}
