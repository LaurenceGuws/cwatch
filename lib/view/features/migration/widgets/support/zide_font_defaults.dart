import 'package:flutter/widgets.dart';

class ZideFontDefaults {
  const ZideFontDefaults._();

  // User-selected migration default: Iosevka non-mono first.
  // Keep broad fallbacks for local font-name variance.
  static const String primaryFamily = 'Iosevka Nerd Font';
  static const String monoFallbackFamily = 'IosevkaTerm Nerd Font';
  static const String jetbrainsFallbackFamily = 'JetBrainsMono Nerd Font';
  static const String jetbrainsMonoFallbackFamily =
      'JetBrainsMono Nerd Font Mono';

  static TextStyle applyTo(TextStyle style) {
    return style.copyWith(
      fontFamily: primaryFamily,
      fontFamilyFallback: const [
        monoFallbackFamily,
        jetbrainsFallbackFamily,
        jetbrainsMonoFallbackFamily,
      ],
    );
  }
}
