import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart';

import '../../../../../../services/settings/app_settings_controller.dart';
import 'language_detection.dart';

class EditorState extends ChangeNotifier {
  EditorState({
    required this.path,
    required this.initialContent,
    required this.settingsController,
  }) {
    _normalizedInitialContent = _normalizeLineEndings(initialContent);
    _language = languageForKey(languageFromPath(path));
    _highlightEnabled = !_isLargeFile(_normalizedInitialContent);
    controller = CodeController(
      text: _normalizedInitialContent,
      language: _highlightEnabled ? _language : null,
      modifiers: _highlightEnabled
          ? CodeController.defaultCodeModifiers
          : const [],
    )..addListener(_handleTextChange);
    settingsController.addListener(_handleSettingsChanged);
  }

  static const int performanceCharLimit = 200000;
  static const int performanceLineLimit = 5000;

  final String path;
  final String initialContent;
  final AppSettingsController settingsController;

  late final CodeController controller;
  final FocusNode editorFocusNode = FocusNode();
  Mode? _language;
  late String _normalizedInitialContent;
  bool _dirty = false;
  bool _saving = false;
  late bool _highlightEnabled;
  bool _showLineNumbers = true;

  bool get dirty => _dirty;
  bool get saving => _saving;
  bool get highlightEnabled => _highlightEnabled;
  bool get showLineNumbers => _showLineNumbers;
  String get normalizedInitialContent => _normalizedInitialContent;
  Mode? get language => _language;

  void _handleSettingsChanged() {
    notifyListeners();
  }

  String? savedThemeForBrightness(Brightness brightness) {
    final settings = settingsController.settings;
    return brightness == Brightness.dark
        ? settings.editorThemeDark
        : settings.editorThemeLight;
  }

  void saveThemeForBrightness(Brightness brightness, String themeKey) {
    settingsController.update((current) {
      return brightness == Brightness.dark
          ? current.copyWith(editorThemeDark: themeKey)
          : current.copyWith(editorThemeLight: themeKey);
    });
  }

  void toggleHighlighting() {
    _highlightEnabled = !_highlightEnabled;
    controller.language = _highlightEnabled ? _language : null;
    notifyListeners();
  }

  void setLanguageByKey(String? languageId) {
    _language = languageForKey(languageId);
    if (_highlightEnabled) {
      controller.language = _language;
    }
    notifyListeners();
  }

  void toggleLineNumbers() {
    _showLineNumbers = !_showLineNumbers;
    notifyListeners();
  }

  Future<bool> save(Future<void> Function(String content) onSave) async {
    if (_saving) return false;
    _saving = true;
    notifyListeners();
    try {
      final contentToSave = controller.fullText;
      await onSave(contentToSave);
      _normalizedInitialContent = _normalizeLineEndings(contentToSave);
      _dirty = false;
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void updateLineNumbersVisibility(bool value) {
    _showLineNumbers = value;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_handleTextChange);
    controller.dispose();
    editorFocusNode.dispose();
    settingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  bool _isLargeFile(String content) {
    if (content.length > performanceCharLimit) {
      return true;
    }
    var lines = 1;
    for (final codeUnit in content.codeUnits) {
      if (codeUnit == 10) {
        lines++;
        if (lines > performanceLineLimit) {
          return true;
        }
      }
    }
    return false;
  }

  String _normalizeLineEndings(String text) {
    return text.replaceAll(RegExp(r'\r\n|\r'), '\n');
  }

  void _handleTextChange() {
    final currentText = _normalizeLineEndings(controller.fullText);
    final dirty = currentText != _normalizedInitialContent;
    if (dirty != _dirty) {
      _dirty = dirty;
      notifyListeners();
    }
  }

}
