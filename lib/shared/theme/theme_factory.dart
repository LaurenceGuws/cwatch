import 'package:flutter/material.dart';
import 'package:cwatch/models/app_settings.dart';
import 'app_theme.dart';

class ThemeFactory {
  /// Builds the ThemeData based on the current AppSettings and target brightness.
  static ThemeData build({
    required AppSettings settings,
    required Brightness brightness,
  }) {
    final appFontFamily = settings.appFontFamily;
    final baseRadius = BorderRadius.circular(2);
    final spacingBase = settings.uiDensity == AppUiDensity.comfy ? 5.0 : 4.0;
    final seed = seedForKey(settings.appThemeKey);

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final tokens = brightness == Brightness.light
        ? AppThemeTokens.light(
            scheme,
            fontFamily: appFontFamily,
            surfaceRadius: baseRadius,
            spacingBase: spacingBase,
          )
        : AppThemeTokens.dark(
            scheme,
            fontFamily: appFontFamily,
            surfaceRadius: baseRadius,
            spacingBase: spacingBase,
          );

    return _buildThemeData(
      scheme,
      tokens,
      appFontFamily,
      baseRadius: baseRadius,
      visualDensity: settings.uiDensity == AppUiDensity.comfy
          ? VisualDensity.standard
          : VisualDensity.compact,
    );
  }

  static ThemeData _buildThemeData(
    ColorScheme scheme,
    AppThemeTokens tokens,
    String? fontFamily, {
    required BorderRadius baseRadius,
    required VisualDensity visualDensity,
  }) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      visualDensity: visualDensity,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
        color: scheme.surfaceContainerHigh,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 0,
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: tokens.spacing.inset(horizontal: 2, vertical: 1),
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: baseRadius,
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: tokens.spacing.inset(horizontal: 2, vertical: 1.5),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: baseRadius),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(2),
        thickness: WidgetStateProperty.all(4),
        thumbVisibility: WidgetStateProperty.all(true),
        thumbColor: WidgetStateProperty.all(
          scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: baseRadius),
          ),
        ),
      ),
      extensions: [tokens],
    );
  }

  static Color seedForKey(String key) {
    switch (key) {
      case 'teal':
        return Colors.teal;
      case 'amber':
        return Colors.amber;
      case 'indigo':
        return Colors.indigo;
      case 'purple':
        return Colors.deepPurple;
      case 'green':
        return Colors.green;
      case 'blue-grey':
      default:
        return Colors.blueGrey;
    }
  }
}
