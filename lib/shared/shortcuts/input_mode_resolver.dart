import 'package:flutter/foundation.dart';

import 'package:cwatch/models/input_mode_preference.dart';

class InputModeConfig {
  const InputModeConfig({
    required this.enableGestures,
    required this.enableShortcuts,
  });

  final bool enableGestures;
  final bool enableShortcuts;
}

InputModeConfig resolveInputMode(
  InputModePreference preference,
  TargetPlatform platform,
) {
  final isMobile =
      !kIsWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);

  final defaultGestures = isMobile;
  final defaultShortcuts = !isMobile;

  switch (preference) {
    case InputModePreference.gestures:
      return const InputModeConfig(
        enableGestures: true,
        enableShortcuts: false,
      );
    case InputModePreference.shortcuts:
      return const InputModeConfig(
        enableGestures: false,
        enableShortcuts: true,
      );
    case InputModePreference.both:
      return const InputModeConfig(enableGestures: true, enableShortcuts: true);
    case InputModePreference.auto:
      return InputModeConfig(
        enableGestures: defaultGestures,
        enableShortcuts: defaultShortcuts,
      );
  }
}
