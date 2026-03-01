# Theme & Zoom Integration Analysis

## Current State

### Zoom Implementation
- **Location**: `lib/view/app/app_bootstrap.dart:60-62`
- **Current behavior**: Only affects text via `TextScaler.linear(zoom)`
- **Limitation**: Layout sizes (icons, spacing, borders, etc.) are NOT scaled
- **Range**: 0.5x to 2.0x

### Theme System
- **Spacing base**: 4.0 (compact) or 5.0 (comfy) - fixed, doesn't scale with zoom
- **Border radius**: Hardcoded `2` in `theme_factory.dart:12`
- **Typography**: Hardcoded font sizes in `app_theme.dart` (12, 14, 20)
- **Visual density**: Uses Flutter's `VisualDensity` but doesn't integrate with zoom

## Problem Areas: Hardcoded Sizes

### 1. Icon Sizes (58+ instances across 28 files)
**Common values**: 16, 18, 20, 30, 32, 48, 64

**Examples**:
- `lib/view/core/navigation/widgets/navigation_button.dart:51` - `size: 30`
- `lib/view/shared/widgets/port_forward_dialog.dart:135` - `size: 16`
- `lib/view/shared/widgets/port_forward_dialog.dart:277` - `size: 18`
- `lib/view/features/docker/widgets/docker_lists.dart:1411` - `size: 20`
- `lib/view/core/navigation/widgets/window_controls.dart:116` - `size: 18`
- `lib/view/shared/widgets/standard_empty_state.dart:30` - `size: 48`

### 2. Fixed Widths
**Common values**: 40, 44, 90, 100, 140, 180, 200, 360, 520, 560, 720, 2000

**Examples**:
- `lib/view/shared/widgets/port_forward_dialog.dart:211` - `width: 40`
- `lib/view/shared/widgets/port_forward_dialog.dart:231` - `width: 200`
- `lib/view/shared/widgets/port_forward_dialog.dart:238` - `width: 140`
- `lib/view/shared/widgets/port_forward_dialog.dart:323` - `width: 200`
- `lib/view/shared/widgets/port_forward_dialog.dart:330` - `width: 140`
- `lib/view/features/docker/widgets/docker_lists.dart:1431` - `width: 2000` (hardcoded large width)
- `lib/view/shared/widgets/style_picker_dialog.dart:132` - `width: 520, height: 460`
- `lib/view/shared/widgets/action_picker.dart:36` - `width: 360`
- `lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart:199` - `constraints.maxWidth < 720` (breakpoint)

### 3. Fixed Heights
**Common values**: 1, 4, 36, 56, 220, 240, 320, 460

**Examples**:
- `lib/view/core/navigation/widgets/navigation_button.dart:66` - `height: 56`
- `lib/view/core/navigation/widgets/navigation_button.dart:70` - `height: 56`
- `lib/view/core/navigation/widgets/navigation_button.dart:82` - `height: 4`
- `lib/view/features/docker/docker_view.dart:352` - `height: 36`
- `lib/view/features/wsl/wsl_view.dart:335` - `height: 36`
- `lib/view/shared/widgets/file_operation_progress_dialog.dart:521` - `height: 220`
- `lib/view/features/docker/widgets/docker_resources.dart:381` - `height: 240`
- `lib/view/features/docker/widgets/remote_scan_dialog.dart:58` - `height: 320`

### 4. Typography Font Sizes
**Location**: `lib/model/shared/theme/app_theme.dart:610-618`
- Section title: `fontSize: 20`
- Body: `fontSize: 14`
- Caption: `fontSize: 12`
- Tab label: `fontSize: 14`

**Note**: These are fallbacks, but the theme system doesn't scale them with zoom.

### 5. Border Radius
**Location**: `lib/model/shared/theme/theme_factory.dart:12`
- Hardcoded: `BorderRadius.circular(2)`

### 6. Spacing System
**Location**: `lib/model/shared/theme/app_theme.dart:119-138`
- Base: 4.0 (compact) or 5.0 (comfy)
- Multipliers: xs (0.5x), sm (1x), md (2x), lg (3x), xl (4x)
- **Issue**: Base doesn't scale with zoom factor

### 7. Dialog/Modal Sizes
**Examples**:
- `lib/view/shared/widgets/port_forward_dialog.dart:96-98` - Uses percentage of screen size (90%, 80%) but has hardcoded minimums
- `lib/view/shared/widgets/port_forward_dialog.dart:99` - `tableMinWidth = maxWidth < 720 ? 720.0 : maxWidth`

### 8. Scrollbar Thickness
**Location**: `lib/model/shared/theme/theme_factory.dart:116`
- Hardcoded: `thickness: WidgetStateProperty.all(4)`

## Recommendations

### 1. Extend AppSpacing to Support Zoom
**Approach**: Make spacing base scale with zoom factor

```dart
class AppSpacing {
  AppSpacing({this.base = 4, this.zoomFactor = 1.0});
  
  final double base;
  final double zoomFactor;
  
  double get effectiveBase => base * zoomFactor;
  
  double get xs => effectiveBase * 0.5;
  double get sm => effectiveBase;
  double get md => effectiveBase * 2;
  double get lg => effectiveBase * 3;
  double get xl => effectiveBase * 4;
  // ... rest of methods use effectiveBase
}
```

**Integration**: Pass zoom factor from `AppSettings` through `ThemeFactory` to `AppSpacing`.

### 2. Create Icon Size Tokens
**Approach**: Add icon size tokens to `AppThemeTokens`

```dart
class AppIconsTokens {
  final double small;    // 16 * zoom
  final double medium;   // 18 * zoom
  final double large;    // 20 * zoom
  final double xlarge;   // 24 * zoom
  final double xxlarge;  // 30 * zoom
  final double navigation; // 30 * zoom (for nav buttons)
  final double emptyState;  // 48 * zoom
}
```

**Usage**: Replace all hardcoded icon sizes with theme tokens.

### 3. Scale Typography with Zoom
**Approach**: Ensure typography scales properly

```dart
factory AppTypographyTokens.fromTextTheme(
  TextTheme textTheme, {
  required double zoomFactor,
}) {
  return AppTypographyTokens(
    sectionTitle: (textTheme.titleLarge ?? const TextStyle(fontSize: 20))
        .copyWith(fontSize: 20 * zoomFactor),
    body: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
        .copyWith(fontSize: 14 * zoomFactor),
    // ... etc
  );
}
```

**Note**: Flutter's `TextScaler` should handle this, but ensure fallback sizes also scale.

### 4. Scale Border Radius
**Approach**: Make border radius scale with zoom

```dart
final baseRadius = BorderRadius.circular(2 * zoomFactor);
```

### 5. Create Dimension Tokens for Common Sizes
**Approach**: Add dimension tokens for common fixed sizes

```dart
class AppDimensionsTokens {
  final double navigationButtonHeight;  // 56 * zoom
  final double navigationIndicatorWidth; // 4 * zoom
  final double dividerHeight;          // 1 * zoom
  final double dialogMinWidth;          // 360 * zoom
  final double dialogMinHeight;        // 240 * zoom
  final double tableMinWidth;          // 720 * zoom
  final double scrollbarThickness;     // 4 * zoom
  // ... etc
}
```

### 6. Use MediaQuery for Responsive Breakpoints
**Approach**: Scale breakpoints with zoom

```dart
// Instead of: constraints.maxWidth < 720
final breakpoint = 720 * zoomFactor;
final narrow = constraints.maxWidth < breakpoint;
```

### 7. Scale Dialog Sizes
**Approach**: Make dialog sizes scale with zoom while maintaining aspect ratios

```dart
// In port_forward_dialog.dart
final zoom = MediaQuery.of(context).textScaler.scale(1.0);
final dialogWidth = (size.width * 0.9).clamp(360 * zoom, double.infinity);
final tableMinWidth = maxWidth < (720 * zoom) ? (720 * zoom) : maxWidth;
```

### 8. Update MediaQuery to Scale All Dimensions
**Approach**: Use `MediaQuery.textScaleFactor` or create custom scaling

**Current** (only text):
```dart
MediaQuery(
  data: mediaQuery.copyWith(textScaler: TextScaler.linear(zoom)),
  child: child,
)
```

**Enhanced** (consider devicePixelRatio for high-DPI):
```dart
// Option 1: Use textScaler for everything (simpler)
// Option 2: Create custom MediaQuery extension with dimensionScaler
// Option 3: Use LayoutBuilder with zoom-aware constraints
```

### 9. Migration Strategy

#### Phase 1: Core Theme System
1. Add zoom factor to `AppThemeTokens`
2. Update `AppSpacing` to scale with zoom
3. Add `AppIconsTokens` and `AppDimensionsTokens`
4. Update `ThemeFactory` to pass zoom factor

#### Phase 2: High-Impact Areas
1. Navigation buttons and sidebar
2. Dialogs and modals
3. Data tables
4. Form inputs

#### Phase 3: Remaining Components
1. Replace hardcoded icon sizes
2. Replace hardcoded widths/heights
3. Update breakpoints
4. Scale border radius and scrollbars

### 10. Helper Extension
**Approach**: Create extension for easy access to scaled values

```dart
extension BuildContextZoom on BuildContext {
  double get zoomFactor => MediaQuery.of(this).textScaler.scale(1.0);
  
  double scale(double value) => value * zoomFactor;
  
  AppThemeTokens get appTheme => Theme.of(this).extension<AppThemeTokens>()!;
}
```

**Usage**:
```dart
// Instead of: Icon(Icons.add, size: 18)
Icon(Icons.add, size: context.appTheme.icons.medium)

// Instead of: SizedBox(width: 200)
SizedBox(width: context.scale(200))

// Instead of: height: 56
height: context.appTheme.dimensions.navigationButtonHeight
```

## Priority Areas

### High Priority (Most Visible)
1. **Navigation sidebar** - `navigation_button.dart` (icon size 30, height 56)
2. **Dialogs** - `port_forward_dialog.dart`, `style_picker_dialog.dart`
3. **Data tables** - `docker_lists.dart`, `structured_data_table_rendering.dart`
4. **Form inputs** - All text fields and buttons

### Medium Priority
1. **Icons throughout app** - 58+ instances
2. **Spacing system** - Used everywhere
3. **Typography** - Text sizes
4. **Breakpoints** - Responsive layouts

### Low Priority (Less Visible)
1. **Scrollbar thickness**
2. **Border radius** (subtle but should scale)
3. **Divider heights**

## Testing Considerations

1. **Test at different zoom levels**: 0.5x, 1.0x, 1.5x, 2.0x
2. **Test on high-DPI displays**: Ensure proper scaling
3. **Test responsive breakpoints**: Ensure they scale correctly
4. **Test pinch zoom**: Ensure smooth transitions
5. **Performance**: Ensure scaling doesn't cause performance issues

## Implementation Notes

- Flutter's `TextScaler` only affects text, not layout
- Need to manually scale layout dimensions
- Consider using `LayoutBuilder` for responsive scaling
- May need to cache scaled values to avoid recalculation
- Consider adding a `zoomFactor` field to `AppSettings` if not already present (it is: `zoomFactor`)
