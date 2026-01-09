import 'package:flutter/material.dart';

import 'nerd_fonts.dart';

/// Theme extension that exposes cascading styling primitives for the app.
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.spacing,
    required this.tabChip,
    required this.list,
    required this.section,
    required this.typography,
    required this.icons,
    required this.docker,
    required this.distroColors,
  });

  final AppSpacing spacing;
  final AppTabChipTokens tabChip;
  final AppListTokens list;
  final AppSectionTokens section;
  final AppTypographyTokens typography;
  final AppIcons icons;
  final AppDockerTokens docker;
  final DistroColors distroColors;

  factory AppThemeTokens.light(
    ColorScheme scheme, {
    String? fontFamily,
    BorderRadius? surfaceRadius,
    double? spacingBase,
  }) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );
    final radius = surfaceRadius ?? BorderRadius.circular(2);
    return AppThemeTokens(
      spacing: AppSpacing(base: spacingBase ?? 4),
      tabChip: AppTabChipTokens.fromScheme(scheme),
      list: AppListTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(scheme, surfaceRadius: radius),
      typography: AppTypographyTokens.fromTextTheme(baseTheme.textTheme),
      icons: AppIcons.nerd(),
      docker: AppDockerTokens.fromScheme(scheme),
      distroColors: DistroColors.standard(),
    );
  }

  factory AppThemeTokens.dark(
    ColorScheme scheme, {
    String? fontFamily,
    BorderRadius? surfaceRadius,
    double? spacingBase,
  }) {
    final baseTheme = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
    );
    final radius = surfaceRadius ?? BorderRadius.circular(2);
    return AppThemeTokens(
      spacing: AppSpacing(base: spacingBase ?? 4),
      tabChip: AppTabChipTokens.fromScheme(scheme),
      list: AppListTokens.fromScheme(scheme),
      section: AppSectionTokens.fromScheme(scheme, surfaceRadius: radius),
      typography: AppTypographyTokens.fromTextTheme(baseTheme.textTheme),
      icons: AppIcons.nerd(),
      docker: AppDockerTokens.fromScheme(scheme),
      distroColors: DistroColors.standard(),
    );
  }

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    AppSpacing? spacing,
    AppTabChipTokens? tabChip,
    AppListTokens? list,
    AppSectionTokens? section,
    AppTypographyTokens? typography,
    AppIcons? icons,
    AppDockerTokens? docker,
    DistroColors? distroColors,
  }) {
    return AppThemeTokens(
      spacing: spacing ?? this.spacing,
      tabChip: tabChip ?? this.tabChip,
      list: list ?? this.list,
      section: section ?? this.section,
      typography: typography ?? this.typography,
      icons: icons ?? this.icons,
      docker: docker ?? this.docker,
      distroColors: distroColors ?? this.distroColors,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
    ThemeExtension<AppThemeTokens>? other,
    double t,
  ) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      spacing: spacing,
      tabChip: AppTabChipTokens.lerp(tabChip, other.tabChip, t),
      list: AppListTokens.lerp(list, other.list, t),
      section: AppSectionTokens.lerp(section, other.section, t),
      typography: AppTypographyTokens.lerp(typography, other.typography, t),
      icons: icons,
      docker: AppDockerTokens.lerp(docker, other.docker, t),
      distroColors: DistroColors.lerp(distroColors, other.distroColors, t),
    );
  }
}

class AppSpacing {
  const AppSpacing({this.base = 4});

  final double base;

  double get xs => base * 0.5;
  double get sm => base;
  double get md => base * 2;
  double get lg => base * 3;
  double get xl => base * 4;

  EdgeInsets inset({double horizontal = 1, double vertical = 1}) {
    return EdgeInsets.symmetric(
      horizontal: base * horizontal,
      vertical: base * vertical,
    );
  }

  EdgeInsets all(double factor) => EdgeInsets.all(base * factor);
}

class AppListTokens {
  const AppListTokens({
    required this.hoverBackground,
    required this.focusOutline,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.unselectedForeground,
    required this.stripeEvenBackground,
    required this.stripeOddBackground,
  });

  final Color hoverBackground;
  final Color focusOutline;
  final Color selectedBackground;
  final Color selectedForeground;
  final Color unselectedForeground;
  final Color stripeEvenBackground;
  final Color stripeOddBackground;

  factory AppListTokens.fromScheme(ColorScheme scheme) {
    return AppListTokens(
      hoverBackground: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      focusOutline: scheme.primary,
      selectedBackground: scheme.primary.withValues(alpha: 0.08),
      selectedForeground: scheme.primary,
      unselectedForeground: scheme.onSurface,
      stripeEvenBackground: scheme.surface,
      stripeOddBackground: scheme.surfaceContainerHigh,
    );
  }

  static AppListTokens lerp(AppListTokens a, AppListTokens b, double t) {
    return AppListTokens(
      hoverBackground:
          Color.lerp(a.hoverBackground, b.hoverBackground, t) ??
          a.hoverBackground,
      focusOutline:
          Color.lerp(a.focusOutline, b.focusOutline, t) ?? a.focusOutline,
      selectedBackground:
          Color.lerp(a.selectedBackground, b.selectedBackground, t) ??
          a.selectedBackground,
      selectedForeground:
          Color.lerp(a.selectedForeground, b.selectedForeground, t) ??
          a.selectedForeground,
      unselectedForeground:
          Color.lerp(a.unselectedForeground, b.unselectedForeground, t) ??
          a.unselectedForeground,
      stripeEvenBackground:
          Color.lerp(a.stripeEvenBackground, b.stripeEvenBackground, t) ??
          a.stripeEvenBackground,
      stripeOddBackground:
          Color.lerp(a.stripeOddBackground, b.stripeOddBackground, t) ??
          a.stripeOddBackground,
    );
  }
}

class AppIcons {
  const AppIcons({
    required this.cloud,
    required this.cloudOutline,
    required this.folderOpen,
    required this.edit,
    required this.delete,
    required this.settings,
    required this.search,
    required this.dns,
    required this.arrowRight,
    required this.arrowDown,
    required this.refresh,
    required this.copy,
    required this.container,
    required this.image,
    required this.network,
    required this.volume,
  });

  final IconData cloud;
  final IconData cloudOutline;
  final IconData folderOpen;
  final IconData edit;
  final IconData delete;
  final IconData settings;
  final IconData search;
  final IconData dns;
  final IconData arrowRight;
  final IconData arrowDown;
  final IconData refresh;
  final IconData copy;
  final IconData container;
  final IconData image;
  final IconData network;
  final IconData volume;

  factory AppIcons.nerd() = _NerdIcons;
}

class _NerdIcons extends AppIcons {
  _NerdIcons()
    : super(
        cloud: nerdIconData[NerdIcon.cloud]!,
        cloudOutline: nerdIconData[NerdIcon.cloud]!,
        folderOpen: nerdIconData[NerdIcon.folderOpen]!,
        edit: nerdIconData[NerdIcon.pencil]!,
        delete: nerdIconData[NerdIcon.delete]!,
        settings: nerdIconData[NerdIcon.settings]!,
        search: nerdIconData[NerdIcon.search]!,
        dns: nerdIconData[NerdIcon.servers]!,
        arrowRight: nerdIconData[NerdIcon.arrowRight]!,
        arrowDown: nerdIconData[NerdIcon.arrowDown]!,
        refresh: nerdIconData[NerdIcon.refresh]!,
        copy: nerdIconData[NerdIcon.copy]!,
        container: nerdIconData[NerdIcon.docker]!,
        image: nerdIconData[NerdIcon.fileImage]!,
        network: nerdIconData[NerdIcon.accessPoint]!,
        volume: nerdIconData[NerdIcon.database]!,
      );
}

class AppDockerTokens {
  const AppDockerTokens({
    required this.running,
    required this.stopped,
    required this.images,
    required this.networks,
    required this.volumes,
    required this.chartPalette,
    required this.chartGrid,
    required this.chartGridAlt,
  });

  final Color running;
  final Color stopped;
  final Color images;
  final Color networks;
  final Color volumes;
  final List<Color> chartPalette;
  final Color chartGrid;
  final Color chartGridAlt;

  factory AppDockerTokens.fromScheme(ColorScheme scheme) {
    return AppDockerTokens(
      running: Colors.green,
      stopped: Colors.orange,
      images: Colors.blueGrey,
      networks: Colors.teal,
      volumes: Colors.deepPurple,
      chartPalette: const [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.red,
        Colors.indigo,
        Colors.pink,
        Colors.cyan,
        Colors.brown,
      ],
      chartGrid: Colors.grey,
      chartGridAlt: Colors.grey,
    );
  }

  static AppDockerTokens lerp(AppDockerTokens a, AppDockerTokens b, double t) {
    return AppDockerTokens(
      running: Color.lerp(a.running, b.running, t) ?? a.running,
      stopped: Color.lerp(a.stopped, b.stopped, t) ?? a.stopped,
      images: Color.lerp(a.images, b.images, t) ?? a.images,
      networks: Color.lerp(a.networks, b.networks, t) ?? a.networks,
      volumes: Color.lerp(a.volumes, b.volumes, t) ?? a.volumes,
      chartPalette: List<Color>.generate(
        a.chartPalette.length,
        (index) =>
            Color.lerp(a.chartPalette[index], b.chartPalette[index], t) ??
            a.chartPalette[index],
      ),
      chartGrid: Color.lerp(a.chartGrid, b.chartGrid, t) ?? a.chartGrid,
      chartGridAlt:
          Color.lerp(a.chartGridAlt, b.chartGridAlt, t) ?? a.chartGridAlt,
    );
  }
}

class DistroColors {
  const DistroColors({
    required this.ubuntu,
    required this.debian,
    required this.arch,
    required this.fedora,
    required this.centos,
    required this.redhat,
    required this.alpine,
    required this.opensuse,
    required this.oracle,
    required this.pop,
    required this.mint,
    required this.nixos,
    required this.raspbian,
    required this.android,
    required this.windows,
    required this.macos,
    required this.linux,
    required this.unknown,
  });

  final Color ubuntu;
  final Color debian;
  final Color arch;
  final Color fedora;
  final Color centos;
  final Color redhat;
  final Color alpine;
  final Color opensuse;
  final Color oracle;
  final Color pop;
  final Color mint;
  final Color nixos;
  final Color raspbian;
  final Color android;
  final Color windows;
  final Color macos;
  final Color linux;
  final Color unknown;

  factory DistroColors.standard() {
    // Baseline palette; tweak here to adjust brand hues globally.
    return const DistroColors(
      ubuntu: Color(0xFFE95420),
      debian: Color(0xFFD70A53),
      arch: Color(0xFF1793D1),
      fedora: Color(0xFF294172),
      centos: Color(0xFF932279),
      redhat: Color(0xFFCC0000),
      alpine: Color(0xFF0D597F),
      opensuse: Color(0xFF73BA25),
      oracle: Color(0xFFC74634),
      pop: Color(0xFF48B9C7),
      mint: Color(0xFF4CAF50),
      nixos: Color(0xFF7EBAE4),
      raspbian: Color(0xFFC7053D),
      android: Color(0xFF3DDC84),
      windows: Color(0xFF00A4EF),
      macos: Color(0xFF545454),
      linux: Color(0xFF4DB6AC),
      unknown: Color(0xFF9E9E9E),
    );
  }

  static DistroColors lerp(DistroColors a, DistroColors b, double t) {
    Color blend(Color x, Color y) => Color.lerp(x, y, t) ?? x;
    return DistroColors(
      ubuntu: blend(a.ubuntu, b.ubuntu),
      debian: blend(a.debian, b.debian),
      arch: blend(a.arch, b.arch),
      fedora: blend(a.fedora, b.fedora),
      centos: blend(a.centos, b.centos),
      redhat: blend(a.redhat, b.redhat),
      alpine: blend(a.alpine, b.alpine),
      opensuse: blend(a.opensuse, b.opensuse),
      oracle: blend(a.oracle, b.oracle),
      pop: blend(a.pop, b.pop),
      mint: blend(a.mint, b.mint),
      nixos: blend(a.nixos, b.nixos),
      raspbian: blend(a.raspbian, b.raspbian),
      android: blend(a.android, b.android),
      windows: blend(a.windows, b.windows),
      macos: blend(a.macos, b.macos),
      linux: blend(a.linux, b.linux),
      unknown: blend(a.unknown, b.unknown),
    );
  }
}

class AppTabChipTokens {
  const AppTabChipTokens({
    required this.selectedBackground,
    required this.unselectedBackground,
    required this.selectedForeground,
    required this.unselectedForeground,
    required this.selectedBorder,
    required this.unselectedBorder,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  final Color selectedBackground;
  final Color unselectedBackground;
  final Color selectedForeground;
  final Color unselectedForeground;
  final Color selectedBorder;
  final Color unselectedBorder;
  final BorderRadius borderRadius;
  final double horizontalPadding;
  final double verticalPadding;

  factory AppTabChipTokens.fromScheme(ColorScheme scheme) {
    return AppTabChipTokens(
      selectedBackground: scheme.primaryContainer,
      unselectedBackground: Colors.transparent,
      selectedForeground: scheme.onPrimaryContainer,
      unselectedForeground: scheme.onSurfaceVariant,
      selectedBorder: scheme.primary,
      unselectedBorder: scheme.outlineVariant,
      borderRadius: BorderRadius.circular(2),
      horizontalPadding: 0.4,
      verticalPadding: 0.12,
    );
  }

  AppTabChipStyle style({required bool selected, required AppSpacing spacing}) {
    return AppTabChipStyle(
      background: selected ? selectedBackground : unselectedBackground,
      foreground: selected ? selectedForeground : unselectedForeground,
      borderColor: selected ? selectedBorder : unselectedBorder,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.base * horizontalPadding,
        vertical: spacing.base * verticalPadding,
      ),
      borderRadius: borderRadius,
    );
  }

  static AppTabChipTokens lerp(
    AppTabChipTokens a,
    AppTabChipTokens b,
    double t,
  ) {
    return AppTabChipTokens(
      selectedBackground:
          Color.lerp(a.selectedBackground, b.selectedBackground, t) ??
          a.selectedBackground,
      unselectedBackground:
          Color.lerp(a.unselectedBackground, b.unselectedBackground, t) ??
          a.unselectedBackground,
      selectedForeground:
          Color.lerp(a.selectedForeground, b.selectedForeground, t) ??
          a.selectedForeground,
      unselectedForeground:
          Color.lerp(a.unselectedForeground, b.unselectedForeground, t) ??
          a.unselectedForeground,
      selectedBorder:
          Color.lerp(a.selectedBorder, b.selectedBorder, t) ?? a.selectedBorder,
      unselectedBorder:
          Color.lerp(a.unselectedBorder, b.unselectedBorder, t) ??
          a.unselectedBorder,
      borderRadius:
          BorderRadius.lerp(a.borderRadius, b.borderRadius, t) ??
          a.borderRadius,
      horizontalPadding: lerpDouble(
        a.horizontalPadding,
        b.horizontalPadding,
        t,
      ),
      verticalPadding: lerpDouble(a.verticalPadding, b.verticalPadding, t),
    );
  }
}

class AppTabChipStyle {
  const AppTabChipStyle({
    required this.background,
    required this.foreground,
    required this.borderColor,
    required this.padding,
    required this.borderRadius,
  });

  final Color background;
  final Color foreground;
  final Color borderColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
}

class AppSectionTokens {
  const AppSectionTokens({
    required this.toolbarBackground,
    required this.divider,
    required this.surface,
  });

  final Color toolbarBackground;
  final Color divider;
  final AppSurfaceStyle surface;

  BorderRadius get cardRadius => surface.radius;

  factory AppSectionTokens.fromScheme(
    ColorScheme scheme, {
    required BorderRadius surfaceRadius,
  }) {
    return AppSectionTokens(
      toolbarBackground: scheme.surface,
      divider: scheme.outlineVariant,
      surface: AppSurfaceStyle(
        background: scheme.surfaceContainerHigh,
        borderColor: scheme.outlineVariant.withValues(alpha: 0.6),
        radius: surfaceRadius,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: EdgeInsets.zero,
        elevation: 0.5,
      ),
    );
  }

  static AppSectionTokens lerp(
    AppSectionTokens a,
    AppSectionTokens b,
    double t,
  ) {
    return AppSectionTokens(
      toolbarBackground:
          Color.lerp(a.toolbarBackground, b.toolbarBackground, t) ??
          a.toolbarBackground,
      divider: Color.lerp(a.divider, b.divider, t) ?? a.divider,
      surface: AppSurfaceStyle.lerp(a.surface, b.surface, t),
    );
  }
}

class AppSurfaceStyle {
  const AppSurfaceStyle({
    required this.background,
    required this.borderColor,
    required this.radius,
    required this.padding,
    required this.margin,
    required this.elevation,
  });

  final Color background;
  final Color borderColor;
  final BorderRadius radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double elevation;

  static AppSurfaceStyle lerp(AppSurfaceStyle a, AppSurfaceStyle b, double t) {
    return AppSurfaceStyle(
      background: Color.lerp(a.background, b.background, t) ?? a.background,
      borderColor: Color.lerp(a.borderColor, b.borderColor, t) ?? a.borderColor,
      radius: BorderRadius.lerp(a.radius, b.radius, t) ?? a.radius,
      padding: EdgeInsets.lerp(a.padding, b.padding, t) ?? a.padding,
      margin: EdgeInsets.lerp(a.margin, b.margin, t) ?? a.margin,
      elevation: lerpDouble(a.elevation, b.elevation, t),
    );
  }
}

class AppTypographyTokens {
  const AppTypographyTokens({
    required this.sectionTitle,
    required this.body,
    required this.caption,
    required this.code,
    required this.tabLabel,
  });

  final TextStyle sectionTitle;
  final TextStyle body;
  final TextStyle caption;
  final TextStyle code;
  final TextStyle tabLabel;

  factory AppTypographyTokens.fromTextTheme(TextTheme textTheme) {
    return AppTypographyTokens(
      sectionTitle:
          textTheme.titleLarge ??
          const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      body: textTheme.bodyMedium ?? const TextStyle(fontSize: 14),
      caption: textTheme.bodySmall ?? const TextStyle(fontSize: 12),
      code: (textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontFamily: 'monospace',
      ),
      tabLabel:
          textTheme.labelLarge ??
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  static AppTypographyTokens lerp(
    AppTypographyTokens a,
    AppTypographyTokens b,
    double t,
  ) {
    return AppTypographyTokens(
      sectionTitle:
          TextStyle.lerp(a.sectionTitle, b.sectionTitle, t) ?? a.sectionTitle,
      body: TextStyle.lerp(a.body, b.body, t) ?? a.body,
      caption: TextStyle.lerp(a.caption, b.caption, t) ?? a.caption,
      code: TextStyle.lerp(a.code, b.code, t) ?? a.code,
      tabLabel: TextStyle.lerp(a.tabLabel, b.tabLabel, t) ?? a.tabLabel,
    );
  }
}

extension BuildContextAppTheme on BuildContext {
  AppThemeTokens get appTheme => Theme.of(this).extension<AppThemeTokens>()!;
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
