import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/controllers/settings_update_support.dart';
import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/input_mode_preference.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

void main() {
  group('SettingsUpdateSupport', () {
    test('trims blank app font family to null', () {
      final updated = SettingsUpdateSupport.setAppFontFamily(
        const AppSettings(appFontFamily: 'Mono'),
        '   ',
      );

      expect(updated.appFontFamily, isNull);
    });

    test('updates terminal preferences without changing other settings', () {
      final current = const AppSettings(
        zoomFactor: 1.25,
        terminalPreferences: TerminalPreferences(
          fontFamily: 'Old Font',
          fontSize: 14,
          lineHeight: 1.1,
          paddingX: 8,
          paddingY: 10,
          themeDark: 'dark-old',
          themeLight: 'light-old',
        ),
      );

      final updated = SettingsUpdateSupport.setTerminalFontFamily(
        SettingsUpdateSupport.setTerminalFontSize(
          SettingsUpdateSupport.setTerminalLineHeight(
            SettingsUpdateSupport.setTerminalPaddingX(
              SettingsUpdateSupport.setTerminalPaddingY(
                SettingsUpdateSupport.setTerminalDarkTheme(
                  SettingsUpdateSupport.setTerminalLightTheme(
                    current,
                    'light-next',
                  ),
                  'dark-next',
                ),
                18,
              ),
              16,
            ),
            1.35,
          ),
          15,
        ),
        '  JetBrains Mono  ',
      );

      expect(updated.zoomFactor, 1.25);
      expect(updated.terminalPreferences.fontFamily, 'JetBrains Mono');
      expect(updated.terminalPreferences.fontSize, 15);
      expect(updated.terminalPreferences.lineHeight, 1.35);
      expect(updated.terminalPreferences.paddingX, 16);
      expect(updated.terminalPreferences.paddingY, 18);
      expect(updated.terminalPreferences.themeDark, 'dark-next');
      expect(updated.terminalPreferences.themeLight, 'light-next');
    });

    test('updates editor preferences and trims blank font family to null', () {
      final current = const AppSettings(
        editorPreferences: EditorPreferences(
          fontFamily: 'Source Code Pro',
          fontSize: 13,
          lineHeight: 1.2,
          themeLight: 'github',
          themeDark: 'monokai',
        ),
      );

      final updated = SettingsUpdateSupport.setEditorFontFamily(
        SettingsUpdateSupport.setEditorFontSize(
          SettingsUpdateSupport.setEditorLineHeight(
            SettingsUpdateSupport.setEditorLightTheme(
              SettingsUpdateSupport.setEditorDarkTheme(
                current,
                'atom-one-dark',
              ),
              'atom-one-light',
            ),
            1.5,
          ),
          16,
        ),
        ' ',
      );

      expect(updated.editorPreferences.fontFamily, isNull);
      expect(updated.editorPreferences.fontSize, 16);
      expect(updated.editorPreferences.lineHeight, 1.5);
      expect(updated.editorPreferences.themeLight, 'atom-one-light');
      expect(updated.editorPreferences.themeDark, 'atom-one-dark');
    });

    test('updates top-level settings fields', () {
      final current = const AppSettings();

      final updated = SettingsUpdateSupport.setDockerLogsTail(
        SettingsUpdateSupport.setInputModePreference(
          SettingsUpdateSupport.setUiDensity(
            SettingsUpdateSupport.setAppThemeKey(
              SettingsUpdateSupport.setZoomFactor(
                SettingsUpdateSupport.setDebugMode(
                  SettingsUpdateSupport.setThemeMode(current, ThemeMode.dark),
                  true,
                ),
                1.4,
              ),
              'teal',
            ),
            AppUiDensity.comfy,
          ),
          InputModePreference.shortcuts,
        ),
        500,
      );

      expect(updated.themeMode, ThemeMode.dark);
      expect(updated.debugMode, isTrue);
      expect(updated.zoomFactor, 1.4);
      expect(updated.appThemeKey, 'teal');
      expect(updated.uiDensity, AppUiDensity.comfy);
      expect(updated.inputModePreference, InputModePreference.shortcuts);
      expect(updated.dockerLogsTailClamped, 500);
    });
  });
}
