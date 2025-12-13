enum InputModePreference { auto, gestures, shortcuts, both }

class InputModePreferenceParsing {
  static InputModePreference fromJson(String? raw) {
    switch (raw) {
      case 'gestures':
        return InputModePreference.gestures;
      case 'shortcuts':
        return InputModePreference.shortcuts;
      case 'both':
        return InputModePreference.both;
      case 'auto':
      default:
        return InputModePreference.auto;
    }
  }
}
