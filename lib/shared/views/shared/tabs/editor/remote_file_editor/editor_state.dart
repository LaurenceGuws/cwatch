import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/highlight_core.dart';

import '../../../../../../services/settings/app_settings_controller.dart';
import 'language_detection.dart';
import 'search_match.dart';

class EditorState extends ChangeNotifier {
  EditorState({
    required this.path,
    required this.initialContent,
    required this.settingsController,
  }) {
    _normalizedInitialContent = _normalizeLineEndings(initialContent);
    _language = languageForKey(languageFromPath(path));
    _pagerMode = _isLargeFile(_normalizedInitialContent);
    _highlightEnabled = !_pagerMode;
    controller = CodeController(
      text: _normalizedInitialContent,
      language: _highlightEnabled ? _language : null,
      modifiers: _highlightEnabled
          ? CodeController.defaultCodeModifiers
          : const [],
    )..addListener(_handleTextChange);
    settingsController.addListener(_handleSettingsChanged);
    _updateSearchMatches('');
  }

  static const int performanceCharLimit = 200000;
  static const int performanceLineLimit = 5000;

  final String path;
  final String initialContent;
  final AppSettingsController settingsController;

  late final CodeController controller;
  final FocusNode plainViewerFocusNode = FocusNode();
  final FocusNode editorFocusNode = FocusNode();
  final TextEditingController searchController = TextEditingController();

  Mode? _language;
  late String _normalizedInitialContent;
  bool _dirty = false;
  bool _saving = false;
  late bool _pagerMode;
  late bool _highlightEnabled;
  bool _showLineNumbers = true;
  bool _showPagerControls = false;
  bool _searchVisible = false;
  String _lastSearchQuery = '';
  int _lastSearchIndex = -1;
  List<int> _searchMatchLines = const [];
  int _searchLineCount = 0;
  List<SearchMatch> _searchMatches = const [];
  int _activeMatch = -1;
  Future<void> Function(int lineNumber)? _pagerScrollToLine;

  bool get dirty => _dirty;
  bool get saving => _saving;
  bool get pagerMode => _pagerMode;
  bool get highlightEnabled => _highlightEnabled;
  bool get showLineNumbers => _showLineNumbers;
  bool get showPagerControls => _showPagerControls;
  bool get searchVisible => _searchVisible;
  List<int> get searchMatchLines => _searchMatchLines;
  int get searchLineCount => _searchLineCount;
  List<SearchMatch> get searchMatches => _searchMatches;
  int get activeMatch => _activeMatch;
  int? get activeMatchLine =>
      _activeMatch >= 0 && _activeMatch < _searchMatches.length
      ? _searchMatches[_activeMatch].lineNumber
      : null;
  bool get usePagerView => _pagerMode && !_highlightEnabled;
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

  void registerPagerScroller(Future<void> Function(int lineNumber) callback) {
    _pagerScrollToLine = callback;
  }

  void unregisterPagerScroller() {
    _pagerScrollToLine = null;
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

  void toggleSearchBar() {
    _searchVisible = !_searchVisible;
    if (_searchVisible && _lastSearchQuery.isNotEmpty) {
      searchController.text = _lastSearchQuery;
      _updateSearchMatches(_lastSearchQuery);
    } else if (!_searchVisible) {
      _resetSearchState();
    }
    notifyListeners();
  }

  void togglePagerMode() {
    _pagerMode = !_pagerMode;
    if (_pagerMode) {
      _highlightEnabled = false;
      controller.language = null;
    } else {
      controller.language = _language;
    }
    notifyListeners();
  }

  void togglePagerControls() {
    _showPagerControls = !_showPagerControls;
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

  void performSearch(String query, {required bool forward}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _updateSearchMatches('');
      _lastSearchIndex = -1;
      _activeMatch = -1;
      notifyListeners();
      return;
    }
    final text = controller.fullText;
    if (text.isEmpty) {
      _updateSearchMatches('');
      notifyListeners();
      return;
    }
    _lastSearchQuery = trimmed;
    _updateSearchMatches(trimmed);
    final currentSelectionStart = controller.selection.isValid
        ? controller.selection.start
        : -1;
    final startIndex = _lastSearchIndex >= 0
        ? _lastSearchIndex
        : currentSelectionStart;
    final matchIndex = forward
        ? _findNext(text, trimmed, startIndex)
        : _findPrevious(text, trimmed, startIndex);
    if (matchIndex == -1) {
      _activeMatch = -1;
      _lastSearchIndex = -1;
      notifyListeners();
      return;
    }
    final activeMatchIndex = _searchMatches.indexWhere(
      (match) => match.start == matchIndex,
    );
    _lastSearchIndex = matchIndex;
    _activeMatch = activeMatchIndex;
    notifyListeners();
    _focusOnMatch(matchIndex, trimmed.length);
  }

  void updateLineNumbersVisibility(bool value) {
    _showLineNumbers = value;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_handleTextChange);
    controller.dispose();
    plainViewerFocusNode.dispose();
    editorFocusNode.dispose();
    searchController.dispose();
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

  void _updateSearchMatches(String query) {
    final trimmed = query.trim();
    final text = controller.fullText;
    final lineStarts = _collectLineStarts(text);
    final lineCount = lineStarts.isEmpty
        ? 0
        : lineStarts.length + (text.endsWith('\n') ? 1 : 0);
    if (trimmed.isEmpty || text.isEmpty) {
      _searchMatchLines = const [];
      _searchMatches = const [];
      _searchLineCount = lineCount;
      _activeMatch = -1;
      return;
    }
    final matches = _collectMatches(text, trimmed, lineStarts);
    final matchLines = matches.map((m) => m.lineNumber).toSet().toList();
    _searchMatchLines = matchLines;
    _searchMatches = matches;
    _searchLineCount = lineCount;
    if (_activeMatch >= matches.length) {
      _activeMatch = -1;
    }
  }

  void _focusOnMatch(int matchIndex, int length) {
    if (!usePagerView) {
      editorFocusNode.requestFocus();
      controller.selection = TextSelection(
        baseOffset: matchIndex,
        extentOffset: matchIndex + length,
      );
      return;
    }
    final prefix = controller.fullText.substring(0, matchIndex);
    final line = prefix.split('\n').length;
    final pagerScroll = _pagerScrollToLine;
    if (pagerScroll != null) {
      unawaited(pagerScroll(line));
    }
  }

  void _resetSearchState() {
    _searchMatchLines = const [];
    _searchLineCount = 0;
    _searchMatches = const [];
    _activeMatch = -1;
    _lastSearchIndex = -1;
  }

  int _findNext(String text, String query, int startIndex) {
    final start = startIndex >= 0 ? startIndex + 1 : 0;
    final forwardIndex = text.indexOf(query, start);
    if (forwardIndex != -1) {
      return forwardIndex;
    }
    return text.indexOf(query);
  }

  int _findPrevious(String text, String query, int startIndex) {
    final start = startIndex > 0 ? startIndex - 1 : text.length;
    final backIndex = text.lastIndexOf(query, start);
    if (backIndex != -1) {
      return backIndex;
    }
    return text.lastIndexOf(query);
  }

  List<int> _collectLineStarts(String text) {
    if (text.isEmpty) return const [];
    final starts = <int>[0];
    for (int i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 10 && i + 1 < text.length) {
        starts.add(i + 1);
      }
    }
    return starts;
  }

  int _lineIndexForOffset(int offset, List<int> lineStarts) {
    var low = 0;
    var high = lineStarts.length - 1;
    var result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lineStarts[mid] <= offset) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  List<SearchMatch> _collectMatches(
    String text,
    String query,
    List<int> lineStarts,
  ) {
    if (query.isEmpty) return const [];
    final matches = <SearchMatch>[];
    var idx = text.indexOf(query, 0);
    while (idx != -1) {
      final lineIndex = _lineIndexForOffset(idx, lineStarts);
      final lineNumber = lineIndex + 1;
      final startColumn = idx - lineStarts[lineIndex];
      matches.add(
        SearchMatch(
          start: idx,
          end: idx + query.length,
          lineNumber: lineNumber,
          startColumn: startColumn,
        ),
      );
      idx = text.indexOf(query, idx + query.length);
    }
    return matches;
  }
}
