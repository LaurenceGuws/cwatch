import 'package:flutter/material.dart';

import 'package:cwatch/model/models/app_settings.dart';
import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/input_mode_preference.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

class SettingsUpdateSupport {
  const SettingsUpdateSupport._();

  static AppSettings setThemeMode(AppSettings current, ThemeMode value) {
    return current.copyWith(themeMode: value);
  }

  static AppSettings setDebugMode(AppSettings current, bool value) {
    return current.copyWith(debugMode: value);
  }

  static AppSettings setZoomFactor(AppSettings current, double value) {
    return current.copyWith(zoomFactor: value);
  }

  static AppSettings setAppFontFamily(AppSettings current, String value) {
    final trimmed = value.trim();
    return _copyAppSettings(
      current,
      appFontFamily: trimmed.isEmpty ? null : trimmed,
    );
  }

  static AppSettings setAppThemeKey(AppSettings current, String value) {
    return current.copyWith(appThemeKey: value);
  }

  static AppSettings setUiDensity(AppSettings current, AppUiDensity value) {
    return current.copyWith(uiDensity: value);
  }

  static AppSettings setInputModePreference(
    AppSettings current,
    InputModePreference value,
  ) {
    return current.copyWith(inputModePreference: value);
  }

  static AppSettings setDockerLogsTail(AppSettings current, int value) {
    return current.copyWith(
      dockerPreferences: current.dockerPreferences.copyWith(logsTail: value),
    );
  }

  static AppSettings setTerminalFontFamily(AppSettings current, String value) {
    final trimmed = value.trim();
    return current.copyWith(
      terminalPreferences: _copyTerminalPreferences(
        current.terminalPreferences,
        fontFamily: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  static AppSettings setTerminalFontSize(AppSettings current, double value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        fontSize: value,
      ),
    );
  }

  static AppSettings setTerminalLineHeight(AppSettings current, double value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        lineHeight: value,
      ),
    );
  }

  static AppSettings setTerminalPaddingX(AppSettings current, double value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        paddingX: value,
      ),
    );
  }

  static AppSettings setTerminalPaddingY(AppSettings current, double value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        paddingY: value,
      ),
    );
  }

  static AppSettings setTerminalDarkTheme(AppSettings current, String value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        themeDark: value,
      ),
    );
  }

  static AppSettings setTerminalLightTheme(AppSettings current, String value) {
    return current.copyWith(
      terminalPreferences: current.terminalPreferences.copyWith(
        themeLight: value,
      ),
    );
  }

  static AppSettings setEditorFontFamily(AppSettings current, String value) {
    final trimmed = value.trim();
    return current.copyWith(
      editorPreferences: _copyEditorPreferences(
        current.editorPreferences,
        fontFamily: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  static AppSettings setEditorFontSize(AppSettings current, double value) {
    return current.copyWith(
      editorPreferences: current.editorPreferences.copyWith(fontSize: value),
    );
  }

  static AppSettings setEditorLineHeight(AppSettings current, double value) {
    return current.copyWith(
      editorPreferences: current.editorPreferences.copyWith(lineHeight: value),
    );
  }

  static AppSettings setEditorLightTheme(AppSettings current, String value) {
    return current.copyWith(
      editorPreferences: current.editorPreferences.copyWith(themeLight: value),
    );
  }

  static AppSettings setEditorDarkTheme(AppSettings current, String value) {
    return current.copyWith(
      editorPreferences: current.editorPreferences.copyWith(themeDark: value),
    );
  }

  static AppSettings _copyAppSettings(
    AppSettings current, {
    required String? appFontFamily,
  }) {
    return AppSettings(
      themeMode: current.themeMode,
      debugMode: current.debugMode,
      zoomFactor: current.zoomFactor,
      serverAutoRefresh: current.serverAutoRefresh,
      serverShowOffline: current.serverShowOffline,
      shellPreferences: current.shellPreferences,
      appFontFamily: appFontFamily,
      appThemeKey: current.appThemeKey,
      uiDensity: current.uiDensity,
      inputModePreference: current.inputModePreference,
      sshPreferences: current.sshPreferences,
      serverDistroMap: current.serverDistroMap,
      dockerDistroMap: current.dockerDistroMap,
      kubernetesPreferences: current.kubernetesPreferences,
      serverWorkspace: current.serverWorkspace,
      kubernetesWorkspace: current.kubernetesWorkspace,
      wslWorkspace: current.wslWorkspace,
      shortcutBindings: current.shortcutBindings,
      editorPreferences: current.editorPreferences,
      dockerPreferences: current.dockerPreferences,
      dockerWorkspace: current.dockerWorkspace,
      terminalPreferences: current.terminalPreferences,
      fileTransferUploadConcurrency: current.fileTransferUploadConcurrency,
      fileTransferDownloadConcurrency: current.fileTransferDownloadConcurrency,
      explorerPreferences: current.explorerPreferences,
    );
  }

  static TerminalPreferences _copyTerminalPreferences(
    TerminalPreferences current, {
    required String? fontFamily,
  }) {
    return TerminalPreferences(
      fontFamily: fontFamily,
      fontSize: current.fontSize,
      lineHeight: current.lineHeight,
      paddingX: current.paddingX,
      paddingY: current.paddingY,
      themeDark: current.themeDark,
      themeLight: current.themeLight,
    );
  }

  static EditorPreferences _copyEditorPreferences(
    EditorPreferences current, {
    required String? fontFamily,
  }) {
    return EditorPreferences(
      themeLight: current.themeLight,
      themeDark: current.themeDark,
      fontFamily: fontFamily,
      fontSize: current.fontSize,
      lineHeight: current.lineHeight,
    );
  }
}
