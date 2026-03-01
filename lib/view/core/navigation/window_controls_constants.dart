import 'package:flutter/material.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

/// Constants for window controls dimensions.
/// Made public so other widgets can account for window control button space.
class WindowControlsConstants {
  WindowControlsConstants._();

  static const double height = 32;
  static const double buttonWidth = 46;
  static const double totalWidth = buttonWidth * 3;
  static const double dragRegionWidth = 32;
  
  /// Tab bar height - use context.appTheme.dimensions.tabBarHeight for zoom-aware value
  static const double tabBarHeight = 36;
  
  /// Get zoom-aware tab bar height from context
  static double tabBarHeightFor(BuildContext context) {
    return context.appTheme.dimensions.tabBarHeight;
  }
}
