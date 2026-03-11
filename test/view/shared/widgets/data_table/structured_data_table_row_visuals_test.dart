import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visuals = StructuredDataTableRowVisuals();
  final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
  final tokens = AppListTokens.fromScheme(scheme);

  test('selected row uses selected background and focus outline', () {
    final state = visuals.resolve(
      tokens: tokens,
      cellSelectionEnabled: false,
      useZebraStripes: true,
      rowIndex: 0,
      isSelected: true,
      isFocused: true,
      isHoveredRow: false,
      isHoveredCellRow: false,
    );

    expect(state.background, tokens.selectedBackground);
    expect(state.showFocusOutline, isTrue);
    expect(state.showHoverOutline, isFalse);
    expect(state.border(tokens).top.color, tokens.focusOutline);
  });

  test('unselected zebra row uses odd stripe background', () {
    final state = visuals.resolve(
      tokens: tokens,
      cellSelectionEnabled: false,
      useZebraStripes: true,
      rowIndex: 1,
      isSelected: false,
      isFocused: false,
      isHoveredRow: false,
      isHoveredCellRow: false,
    );

    expect(state.background, tokens.stripeOddBackground);
    expect(state.showFocusOutline, isFalse);
    expect(state.showHoverOutline, isFalse);
  });

  test('hovered row uses hover background and hover outline', () {
    final state = visuals.resolve(
      tokens: tokens,
      cellSelectionEnabled: false,
      useZebraStripes: true,
      rowIndex: 2,
      isSelected: false,
      isFocused: false,
      isHoveredRow: true,
      isHoveredCellRow: false,
    );

    expect(state.background, tokens.hoverBackground);
    expect(state.showFocusOutline, isFalse);
    expect(state.showHoverOutline, isTrue);
    expect(state.border(tokens).top.color, tokens.hoverBorder);
  });

  test('cell selection mode only highlights hovered cell row', () {
    final state = visuals.resolve(
      tokens: tokens,
      cellSelectionEnabled: true,
      useZebraStripes: true,
      rowIndex: 0,
      isSelected: true,
      isFocused: true,
      isHoveredRow: true,
      isHoveredCellRow: true,
    );

    expect(
      state.background,
      tokens.hoverBackground.withValues(alpha: 0.12),
    );
    expect(state.showFocusOutline, isFalse);
    expect(state.showHoverOutline, isFalse);
  });
}
