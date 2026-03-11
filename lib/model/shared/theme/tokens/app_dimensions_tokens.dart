part of app_theme;

class AppDimensionsTokens {
  const AppDimensionsTokens({this.zoomFactor = 1.0});

  final double zoomFactor;

  /// Navigation button height (56px base)
  double get navigationButtonHeight => 56 * zoomFactor;

  /// Navigation indicator width (4px base)
  double get navigationIndicatorWidth => 4 * zoomFactor;

  /// Divider height (1px base)
  double get dividerHeight => 1 * zoomFactor;

  /// Dialog minimum width (360px base)
  double get dialogMinWidth => 360 * zoomFactor;

  /// Dialog minimum height (240px base)
  double get dialogMinHeight => 240 * zoomFactor;

  /// Table minimum width breakpoint (720px base)
  double get tableMinWidth => 720 * zoomFactor;

  /// Scrollbar thickness (4px base)
  double get scrollbarThickness => 4 * zoomFactor;

  /// Explorer row height (36px base)
  double get explorerRowHeight => 36 * zoomFactor;

  /// Tab bar height (36px base)
  double get tabBarHeight => 36 * zoomFactor;

  /// Data table row height (60px base)
  double get dataTableRowHeight => 60 * zoomFactor;

  /// Data table header height (38px base)
  double get dataTableHeaderHeight => 38 * zoomFactor;

  /// Data table scrollbar space (14px base)
  double get dataTableScrollbarSpace => 14 * zoomFactor;

  /// Common small spacing (4px base)
  double get spacingSmall => 4 * zoomFactor;

  /// Common medium spacing (8px base)
  double get spacingMedium => 8 * zoomFactor;

  /// Common large spacing (16px base)
  double get spacingLarge => 16 * zoomFactor;

  /// Port forward dialog column widths
  double get portForwardUseColumnWidth => 40 * zoomFactor;
  double get portForwardServiceColumnWidth => 200 * zoomFactor;
  double get portForwardStatusColumnWidth => 140 * zoomFactor;

  /// Docker table column widths
  double get dockerTableCpuColumnWidth => 80 * zoomFactor;
  double get dockerTableRamColumnWidth => 80 * zoomFactor;

  static AppDimensionsTokens lerp(
    AppDimensionsTokens a,
    AppDimensionsTokens b,
    double t,
  ) {
    return AppDimensionsTokens(
      zoomFactor: lerpDouble(a.zoomFactor, b.zoomFactor, t),
    );
  }
}

