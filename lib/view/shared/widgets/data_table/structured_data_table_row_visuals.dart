part of 'structured_data_table.dart';

class StructuredDataTableRowVisualState {
  const StructuredDataTableRowVisualState({
    required this.background,
    required this.showFocusOutline,
    required this.showHoverOutline,
  });

  final Color background;
  final bool showFocusOutline;
  final bool showHoverOutline;

  Border border(AppListTokens tokens) {
    final color = showFocusOutline
        ? tokens.focusOutline
        : (showHoverOutline ? tokens.hoverBorder : Colors.transparent);
    final width = showFocusOutline ? 0.9 : (showHoverOutline ? 0.9 : 0.4);
    return Border.all(color: color, width: width);
  }
}

class StructuredDataTableRowVisuals {
  const StructuredDataTableRowVisuals();

  StructuredDataTableRowVisualState resolve({
    required AppListTokens tokens,
    required bool cellSelectionEnabled,
    required bool useZebraStripes,
    required int rowIndex,
    required bool isSelected,
    required bool isFocused,
    required bool isHoveredRow,
    required bool isHoveredCellRow,
  }) {
    final stripeBackground = cellSelectionEnabled
        ? Colors.transparent
        : (useZebraStripes
              ? (rowIndex.isEven
                    ? tokens.stripeEvenBackground
                    : tokens.stripeOddBackground)
              : Colors.transparent);
    final rowHoverBackground = cellSelectionEnabled
        ? (isHoveredCellRow
              ? tokens.hoverBackground.withValues(alpha: 0.12)
              : Colors.transparent)
        : (isHoveredRow ? tokens.hoverBackground : Colors.transparent);
    final background = cellSelectionEnabled
        ? rowHoverBackground
        : (isSelected
              ? tokens.selectedBackground
              : (isHoveredRow ? rowHoverBackground : stripeBackground));

    return StructuredDataTableRowVisualState(
      background: background,
      showFocusOutline: isFocused && !cellSelectionEnabled,
      showHoverOutline: !cellSelectionEnabled && isHoveredRow,
    );
  }
}
