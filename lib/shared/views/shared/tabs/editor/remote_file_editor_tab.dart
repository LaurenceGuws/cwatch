import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'dart:async';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:flutter_highlight/themes/agate.dart';
import 'package:flutter_highlight/themes/an-old-hope.dart';
import 'package:flutter_highlight/themes/androidstudio.dart';
import 'package:flutter_highlight/themes/arduino-light.dart';
import 'package:flutter_highlight/themes/arta.dart';
import 'package:flutter_highlight/themes/ascetic.dart';
import 'package:flutter_highlight/themes/atelier-cave-dark.dart';
import 'package:flutter_highlight/themes/atelier-cave-light.dart';
import 'package:flutter_highlight/themes/atelier-dune-dark.dart';
import 'package:flutter_highlight/themes/atelier-dune-light.dart';
import 'package:flutter_highlight/themes/atelier-estuary-dark.dart';
import 'package:flutter_highlight/themes/atelier-estuary-light.dart';
import 'package:flutter_highlight/themes/atelier-forest-dark.dart';
import 'package:flutter_highlight/themes/atelier-forest-light.dart';
import 'package:flutter_highlight/themes/atelier-heath-dark.dart';
import 'package:flutter_highlight/themes/atelier-heath-light.dart';
import 'package:flutter_highlight/themes/atelier-lakeside-dark.dart';
import 'package:flutter_highlight/themes/atelier-lakeside-light.dart';
import 'package:flutter_highlight/themes/atelier-plateau-dark.dart';
import 'package:flutter_highlight/themes/atelier-plateau-light.dart';
import 'package:flutter_highlight/themes/atelier-savanna-dark.dart';
import 'package:flutter_highlight/themes/atelier-savanna-light.dart';
import 'package:flutter_highlight/themes/atelier-seaside-dark.dart';
import 'package:flutter_highlight/themes/atelier-seaside-light.dart';
import 'package:flutter_highlight/themes/atelier-sulphurpool-dark.dart';
import 'package:flutter_highlight/themes/atelier-sulphurpool-light.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_highlight/themes/brown-paper.dart';
import 'package:flutter_highlight/themes/codepen-embed.dart';
import 'package:flutter_highlight/themes/color-brewer.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/dark.dart';
import 'package:flutter_highlight/themes/default.dart';
import 'package:flutter_highlight/themes/docco.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/far.dart';
import 'package:flutter_highlight/themes/foundation.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/github-gist.dart';
import 'package:flutter_highlight/themes/gml.dart';
import 'package:flutter_highlight/themes/googlecode.dart';
import 'package:flutter_highlight/themes/gradient-dark.dart';
import 'package:flutter_highlight/themes/grayscale.dart';
import 'package:flutter_highlight/themes/gruvbox-dark.dart';
import 'package:flutter_highlight/themes/gruvbox-light.dart';
import 'package:flutter_highlight/themes/hopscotch.dart';
import 'package:flutter_highlight/themes/hybrid.dart';
import 'package:flutter_highlight/themes/idea.dart';
import 'package:flutter_highlight/themes/ir-black.dart';
import 'package:flutter_highlight/themes/isbl-editor-dark.dart';
import 'package:flutter_highlight/themes/isbl-editor-light.dart';
import 'package:flutter_highlight/themes/kimbie.dark.dart';
import 'package:flutter_highlight/themes/kimbie.light.dart';
import 'package:flutter_highlight/themes/lightfair.dart';
import 'package:flutter_highlight/themes/magula.dart';
import 'package:flutter_highlight/themes/mono-blue.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/night-owl.dart';
import 'package:flutter_highlight/themes/nord.dart';
import 'package:flutter_highlight/themes/obsidian.dart';
import 'package:flutter_highlight/themes/ocean.dart';
import 'package:flutter_highlight/themes/paraiso-dark.dart';
import 'package:flutter_highlight/themes/paraiso-light.dart';
import 'package:flutter_highlight/themes/pojoaque.dart';
import 'package:flutter_highlight/themes/purebasic.dart';
import 'package:flutter_highlight/themes/qtcreator_dark.dart';
import 'package:flutter_highlight/themes/qtcreator_light.dart';
import 'package:flutter_highlight/themes/railscasts.dart';
import 'package:flutter_highlight/themes/rainbow.dart';
import 'package:flutter_highlight/themes/routeros.dart';
import 'package:flutter_highlight/themes/school-book.dart';
import 'package:flutter_highlight/themes/shades-of-purple.dart';
import 'package:flutter_highlight/themes/solarized-dark.dart';
import 'package:flutter_highlight/themes/solarized-light.dart';
import 'package:flutter_highlight/themes/sunburst.dart';
import 'package:flutter_highlight/themes/tomorrow.dart';
import 'package:flutter_highlight/themes/tomorrow-night.dart';
import 'package:flutter_highlight/themes/tomorrow-night-blue.dart';
import 'package:flutter_highlight/themes/tomorrow-night-bright.dart';
import 'package:flutter_highlight/themes/tomorrow-night-eighties.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_highlight/themes/xcode.dart';
import 'package:flutter_highlight/themes/xt256.dart';
import 'package:flutter_highlight/themes/zenburn.dart';
// Import all languages dynamically via all.dart
import 'package:highlight/languages/all.dart' as all_langs;
import 'package:highlight/highlight_core.dart';
import 'package:flutter/services.dart';

import '../../../../../models/ssh_host.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../theme/nerd_fonts.dart';
import '../../../../widgets/style_picker_dialog.dart';
import '../tab_chip.dart';

class RemoteFileEditorTab extends StatefulWidget {
  const RemoteFileEditorTab({
    super.key,
    required this.host,
    required this.shellService,
    required this.path,
    required this.initialContent,
    required this.onSave,
    required this.settingsController,
    this.helperText,
    this.optionsController,
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final String initialContent;
  final Future<void> Function(String content) onSave;
  final AppSettingsController settingsController;
  final String? helperText;
  final TabOptionsController? optionsController;

  @override
  State<RemoteFileEditorTab> createState() => _RemoteFileEditorTabState();
}

class _RemoteFileEditorTabState extends State<RemoteFileEditorTab> {
  static const int _performanceCharLimit = 200000;
  static const int _performanceLineLimit = 5000;

  late final CodeController _controller;
  final FocusNode _plainViewerFocusNode = FocusNode();
  final GlobalKey<_PlainTextViewerState> _plainViewerKey =
      GlobalKey<_PlainTextViewerState>();
  final FocusNode _editorFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  Mode? _language;
  late String _normalizedInitialContent;
  bool _dirty = false;
  bool _saving = false;
  late bool _performanceMode;
  late bool _highlightEnabled;
  bool _showLineNumbers = true;
  bool _showPagerControls = false;
  String _lastSearchQuery = '';
  int _lastSearchIndex = -1;
  bool _searchVisible = false;
  List<int> _searchMatchLines = const [];
  int _searchLineCount = 0;
  List<_SearchMatch> _searchMatches = const [];
  int _activeMatch = -1;

  @override
  void initState() {
    super.initState();
    // Normalize line endings to avoid false positives
    _normalizedInitialContent = _normalizeLineEndings(widget.initialContent);
    _language = _getLanguageForKey(_languageFromPath(widget.path));
    _performanceMode = _isLargeFile(_normalizedInitialContent);
    _highlightEnabled = !_performanceMode;
    _controller = CodeController(
      text: _normalizedInitialContent,
      language: _highlightEnabled ? _language : null,
      // Skip editor modifiers in performance mode to keep edits snappy.
      modifiers: _highlightEnabled
          ? CodeController.defaultCodeModifiers
          : const [],
    )..addListener(_handleTextChange);
    widget.settingsController.addListener(_handleSettingsChanged);
    _updateTabOptions();
  }

  bool _isLargeFile(String content) {
    if (content.length > _performanceCharLimit) {
      return true;
    }
    var lines = 1;
    for (final codeUnit in content.codeUnits) {
      if (codeUnit == 10) {
        lines++;
        if (lines > _performanceLineLimit) {
          return true;
        }
      }
    }
    return false;
  }

  String _normalizeLineEndings(String text) {
    // Normalize all line endings to \n (Unix style)
    return text.replaceAll(RegExp(r'\r\n|\r'), '\n');
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_handleSettingsChanged);
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _plainViewerFocusNode.dispose();
    _editorFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSettingsChanged() {
    // Update theme when settings change (e.g., app theme mode changes)
    if (mounted) {
      setState(() {});
    }
  }

  String? _getSavedThemeForBrightness(Brightness brightness) {
    final settings = widget.settingsController.settings;
    return brightness == Brightness.dark
        ? settings.editorThemeDark
        : settings.editorThemeLight;
  }

  void _saveThemeForBrightness(Brightness brightness, String themeKey) {
    widget.settingsController.update((current) {
      return brightness == Brightness.dark
          ? current.copyWith(editorThemeDark: themeKey)
          : current.copyWith(editorThemeLight: themeKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = colorScheme.brightness;
    final savedTheme = _getSavedThemeForBrightness(brightness);
    final theme = _getThemeForColorScheme(colorScheme, savedTheme);
    final settings = widget.settingsController.settings;
    final usePlainViewer = _performanceMode && !_highlightEnabled;
    final baseTextStyle = TextStyle(
      fontFamily: NerdFonts.effectiveFamily(settings.editorFontFamily),
      fontSize: settings.editorFontSize.clamp(8, 32).toDouble(),
      height: settings.editorLineHeight.clamp(1.0, 2.0).toDouble(),
    );
    final matchColor =
        colorScheme.primaryContainer.withValues(alpha: 0.28);
    final activeMatchColor = colorScheme.primary.withValues(alpha: 0.45);
    final activeLine =
        _activeMatch >= 0 && _activeMatch < _searchMatches.length
            ? _searchMatches[_activeMatch].lineNumber
            : null;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_searchVisible) _buildSearchBar(),
          Expanded(
            child: usePlainViewer
                ? _PlainTextViewer(
                    key: _plainViewerKey,
                    text: _controller.fullText,
                    style: baseTextStyle,
                    focusNode: _plainViewerFocusNode,
                    showLineNumbers: _showLineNumbers,
                    showControls: _showPagerControls,
                    matchLines: _searchMatchLines,
                    matches: _searchMatches,
                    activeMatchIndex: _activeMatch,
                    matchColor: matchColor,
                    activeMatchColor: activeMatchColor,
                  )
                : CodeTheme(
                    data: CodeThemeData(styles: theme),
                    child: Stack(
                      children: [
                        CodeField(
                          controller: _controller,
                          focusNode: _editorFocusNode,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textStyle: baseTextStyle,
                          gutterStyle: GutterStyle(
                            showLineNumbers: _showLineNumbers,
                            showErrors: _highlightEnabled,
                            showFoldingHandles: _highlightEnabled,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          width: 8,
                          child: IgnorePointer(
                              child: CustomPaint(
                                painter: _MatchMarkersPainter(
                                  lineCount: _searchLineCount,
                                  matches: _searchMatchLines,
                                  color: matchColor,
                                  activeColor: activeMatchColor,
                                  activeLine: activeLine,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    _updateTabOptions();
    try {
      // Use fullText to save the complete content including folded blocks
      final contentToSave = _controller.fullText;
      await widget.onSave(contentToSave);
      if (!mounted) return;
      // Update the normalized initial content to match what was saved
      _normalizedInitialContent = _normalizeLineEndings(contentToSave);
      setState(() {
        _dirty = false;
        _saving = false;
      });
      _updateTabOptions();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved ${widget.path}')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      _updateTabOptions();
    }
  }

  void _handleTextChange() {
    // Use fullText to get the complete text including folded blocks
    // Normalize line endings for comparison
    final currentText = _normalizeLineEndings(_controller.fullText);
    final dirty = currentText != _normalizedInitialContent;
    if (dirty != _dirty) {
      setState(() {
        _dirty = dirty;
      });
      _updateTabOptions();
    }
  }

  void _toggleHighlighting() {
    setState(() {
      _highlightEnabled = !_highlightEnabled;
      _controller.language = _highlightEnabled ? _language : null;
    });
    _updateTabOptions();
  }

  void _toggleLineNumbers() {
    setState(() {
      _showLineNumbers = !_showLineNumbers;
    });
    _updateTabOptions();
  }

  void _toggleSearchBar() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (_searchVisible && _lastSearchQuery.isNotEmpty) {
        _searchController.text = _lastSearchQuery;
        _updateSearchMatches(_lastSearchQuery);
      } else if (!_searchVisible) {
        _searchMatchLines = const [];
        _searchLineCount = 0;
        _searchMatches = const [];
        _activeMatch = -1;
        _lastSearchIndex = -1;
      }
    });
    _updateTabOptions();
  }

  void _togglePerformanceMode() {
    setState(() {
      _performanceMode = !_performanceMode;
      if (_performanceMode) {
        _highlightEnabled = false;
      }
    });
    _updateTabOptions();
  }

  void _togglePagerControls() {
    setState(() {
      _showPagerControls = !_showPagerControls;
    });
    _updateTabOptions();
  }

  void _performSearch(String query, {required bool forward}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _updateSearchMatches('');
      setState(() {
        _lastSearchIndex = -1;
        _activeMatch = -1;
      });
      return;
    }
    final text = _controller.fullText;
    if (text.isEmpty) {
      _updateSearchMatches('');
      return;
    }
    _lastSearchQuery = trimmed;
    _updateSearchMatches(trimmed);
    final currentSelectionStart = _controller.selection.isValid
        ? _controller.selection.start
        : -1;
    final startIndex = _lastSearchIndex >= 0
        ? _lastSearchIndex
        : currentSelectionStart;
    final matchIndex = forward
        ? _findNext(text, trimmed, startIndex)
        : _findPrevious(text, trimmed, startIndex);
    if (matchIndex == -1) {
      setState(() {
        _activeMatch = -1;
        _lastSearchIndex = -1;
      });
      return;
    }
    final activeMatchIndex =
        _searchMatches.indexWhere((match) => match.start == matchIndex);
    setState(() {
      _lastSearchIndex = matchIndex;
      _activeMatch = activeMatchIndex;
    });
    _focusOnMatch(matchIndex, trimmed.length);
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

  List<_SearchMatch> _collectMatches(
    String text,
    String query,
    List<int> lineStarts,
  ) {
    if (query.isEmpty) return const [];
    final matches = <_SearchMatch>[];
    var idx = text.indexOf(query, 0);
    while (idx != -1) {
      final lineIndex = _lineIndexForOffset(idx, lineStarts);
      final lineNumber = lineIndex + 1;
      final startColumn = idx - lineStarts[lineIndex];
      matches.add(
        _SearchMatch(
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

  void _updateSearchMatches(String query) {
    final trimmed = query.trim();
    final text = _controller.fullText;
    final lineStarts = _collectLineStarts(text);
    final lineCount =
        lineStarts.isEmpty ? 0 : lineStarts.length + (text.endsWith('\n') ? 1 : 0);
    if (trimmed.isEmpty || text.isEmpty) {
      setState(() {
        _searchMatchLines = const [];
        _searchMatches = const [];
        _searchLineCount = lineCount;
        _activeMatch = -1;
      });
      return;
    }
    final matches = _collectMatches(text, trimmed, lineStarts);
    final matchLines = matches.map((m) => m.lineNumber).toSet().toList();
    setState(() {
      _searchMatchLines = matchLines;
      _searchMatches = matches;
      _searchLineCount = lineCount;
      if (_activeMatch >= matches.length) {
        _activeMatch = -1;
      }
    });
  }

  void _focusOnMatch(int matchIndex, int length) {
    final usePlainViewer = _performanceMode && !_highlightEnabled;
    if (!usePlainViewer) {
      _editorFocusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: matchIndex,
        extentOffset: matchIndex + length,
      );
      return;
    }
    final prefix = _controller.fullText.substring(0, matchIndex);
    final line = prefix.split('\n').length;
    _plainViewerKey.currentState?.scrollToLine(line);
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search',
                border: InputBorder.none,
              ),
              onSubmitted: (value) => _performSearch(value, forward: true),
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () =>
                _performSearch(_searchController.text, forward: false),
          ),
          IconButton(
            tooltip: 'Next',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () =>
                _performSearch(_searchController.text, forward: true),
          ),
          IconButton(
            tooltip: 'Close search',
            icon: const Icon(Icons.close),
            onPressed: _toggleSearchBar,
          ),
        ],
      ),
    );
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final themes = _getAllThemes();
    final brightness = Theme.of(context).colorScheme.brightness;
    final defaultTheme = brightness == Brightness.dark
        ? 'dracula'
        : 'color-brewer';
    final savedTheme = _getSavedThemeForBrightness(brightness);
    final initialKey = savedTheme ?? defaultTheme;
    final options = themes.entries
        .map((e) => StyleOption(key: e.key, label: e.value))
        .toList();

    final chosen = await showStylePickerDialog(
      context: context,
      title: 'Select editor theme',
      options: options,
      selectedKey: initialKey,
      onPreview: (key) {
        _saveThemeForBrightness(brightness, key);
        setState(() {});
      },
    );

    // If dialog cancelled, restore the saved choice or default.
    if (chosen == null) {
      _saveThemeForBrightness(brightness, savedTheme ?? defaultTheme);
    } else {
      _saveThemeForBrightness(brightness, chosen);
    }
    if (mounted) {
      setState(() {});
      _updateTabOptions();
    }
  }

  List<TabChipOption>? _pendingTabOptions;
  bool _optionsScheduled = false;

  void _updateTabOptions() {
    final options = [
      TabChipOption(
        label: 'Save',
        icon: NerdIcon.cloudUpload.data,
        enabled: _dirty && !_saving,
        onSelected: _handleSave,
      ),
      TabChipOption(
        label: _searchVisible ? 'Hide search' : 'Find',
        icon: Icons.search,
        onSelected: _toggleSearchBar,
      ),
      TabChipOption(
        label: _performanceMode
            ? 'Disable performance mode'
            : 'Enable performance',
        icon: Icons.speed,
        color: _performanceMode ? Colors.amber : null,
        onSelected: _togglePerformanceMode,
      ),
      if (_performanceMode)
        TabChipOption(
          label: _showPagerControls
              ? 'Hide pager controls'
              : 'Show pager controls',
          icon: Icons.view_headline,
          onSelected: _togglePagerControls,
        ),
      TabChipOption(
        label: _highlightEnabled
            ? 'Disable highlighting'
            : 'Enable highlighting',
        icon: Icons.speed,
        color: _performanceMode && _highlightEnabled ? Colors.amber : null,
        onSelected: _toggleHighlighting,
      ),
      TabChipOption(
        label: _showLineNumbers ? 'Hide line numbers' : 'Show line numbers',
        icon: Icons.format_list_numbered,
        onSelected: _toggleLineNumbers,
      ),
      TabChipOption(
        label: 'File info',
        icon: Icons.info_outline,
        onSelected: () => _showFileInfo(context),
      ),
      TabChipOption(
        label: 'Theme',
        icon: Icons.palette,
        onSelected: () => _showThemeDialog(context),
      ),
    ];
    final controller = widget.optionsController;
    if (controller == null) {
      return;
    }
    _pendingTabOptions = options;
    if (_optionsScheduled) {
      return;
    }
    _optionsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _optionsScheduled = false;
      final pending = _pendingTabOptions;
      if (pending == null) {
        return;
      }
      _pendingTabOptions = null;
      controller.update(pending);
    });
  }

  void _showFileInfo(BuildContext context) {
    final content = _controller.text;
    final lines = content.isEmpty ? 0 : content.split('\n').length;
    final language = _languageFromPath(widget.path);
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('File Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Path', value: widget.path),
            const SizedBox(height: 8),
            _InfoRow(label: 'Lines', value: '$lines'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Characters', value: '${content.length}'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Language', value: language ?? 'Unknown'),
            if (_controller.language != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Parser',
                value: _controller.language.runtimeType.toString(),
              ),
            ],
            if (widget.helperText != null) ...[
              const SizedBox(height: 16),
              Text('Notes', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(widget.helperText!, style: textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Mode? _getLanguageForKey(String? languageId) {
    if (languageId == null) return null;

    // Map language IDs to highlight language objects using dynamic lookup
    // Handle aliases and special cases
    String? lookupKey = languageId;

    // Handle common aliases
    switch (languageId) {
      case 'js':
        lookupKey = 'javascript';
        break;
      case 'ts':
        lookupKey = 'typescript';
        break;
      case 'py':
        lookupKey = 'python';
        break;
      case 'sh':
        lookupKey = 'bash';
        break;
      case 'c':
      case 'cxx':
      case 'cc':
        lookupKey = 'cpp';
        break;
      case 'csharp':
        lookupKey = 'cs';
        break;
      case 'rs':
        lookupKey = 'rust';
        break;
      case 'rb':
        lookupKey = 'ruby';
        break;
      case 'kt':
        lookupKey = 'kotlin';
        break;
      case 'yml':
        lookupKey = 'yaml';
        break;
      case 'html':
        lookupKey = 'xml';
        break;
      case 'md':
        lookupKey = 'markdown';
        break;
      case 'pl':
        lookupKey = 'perl';
        break;
      case 'docker':
        lookupKey = 'dockerfile';
        break;
      case 'git':
        return null; // Git not available in highlight package
      case 'toml':
        return null; // TOML not available in highlight package
      default:
        lookupKey = languageId;
    }

    // Dynamically look up the language from allLanguages map
    return all_langs.allLanguages[lookupKey];
  }

  String? _languageFromPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;
    final baseName = trimmed.split('/').last.toLowerCase();
    switch (baseName) {
      case '.bashrc':
      case '.bash_profile':
      case '.profile':
      case '.zshrc':
      case '.zprofile':
        return 'bash';
      case 'dockerfile':
      case 'containerfile':
        return 'dockerfile';
      default:
        break;
    }
    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == trimmed.length - 1) return null;
    final ext = trimmed.substring(dotIndex + 1).toLowerCase();
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'json':
        return 'json';
      case 'yml':
      case 'yaml':
        return 'yaml';
      case 'md':
      case 'markdown':
        return 'markdown';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'go':
        return 'go';
      case 'rs':
        return 'rust';
      case 'py':
        return 'python';
      case 'rb':
        return 'ruby';
      case 'php':
        return 'php';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'c':
        return 'c';
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'hpp':
      case 'hh':
      case 'hxx':
        return 'cpp';
      case 'cs':
        return 'csharp';
      case 'html':
      case 'htm':
        return 'html';
      case 'css':
        return 'css';
      case 'xml':
        return 'xml';
      case 'toml':
        return 'toml';
      case 'dockerfile':
        return 'dockerfile';
      default:
        return null;
    }
  }

  Map<String, String> _getAllThemes() {
    return {
      'a11y-dark': 'A11y Dark',
      'a11y-light': 'A11y Light',
      'agate': 'Agate',
      'an-old-hope': 'An Old Hope',
      'androidstudio': 'Android Studio',
      'arduino-light': 'Arduino Light',
      'arta': 'Arta',
      'ascetic': 'Ascetic',
      'atelier-cave-dark': 'Atelier Cave Dark',
      'atelier-cave-light': 'Atelier Cave Light',
      'atelier-dune-dark': 'Atelier Dune Dark',
      'atelier-dune-light': 'Atelier Dune Light',
      'atelier-estuary-dark': 'Atelier Estuary Dark',
      'atelier-estuary-light': 'Atelier Estuary Light',
      'atelier-forest-dark': 'Atelier Forest Dark',
      'atelier-forest-light': 'Atelier Forest Light',
      'atelier-heath-dark': 'Atelier Heath Dark',
      'atelier-heath-light': 'Atelier Heath Light',
      'atelier-lakeside-dark': 'Atelier Lakeside Dark',
      'atelier-lakeside-light': 'Atelier Lakeside Light',
      'atelier-plateau-dark': 'Atelier Plateau Dark',
      'atelier-plateau-light': 'Atelier Plateau Light',
      'atelier-savanna-dark': 'Atelier Savanna Dark',
      'atelier-savanna-light': 'Atelier Savanna Light',
      'atelier-seaside-dark': 'Atelier Seaside Dark',
      'atelier-seaside-light': 'Atelier Seaside Light',
      'atelier-sulphurpool-dark': 'Atelier Sulphurpool Dark',
      'atelier-sulphurpool-light': 'Atelier Sulphurpool Light',
      'atom-one-dark': 'Atom One Dark',
      'atom-one-dark-reasonable': 'Atom One Dark Reasonable',
      'atom-one-light': 'Atom One Light',
      'brown-paper': 'Brown Paper',
      'codepen-embed': 'CodePen Embed',
      'color-brewer': 'Color Brewer',
      'darcula': 'Darcula',
      'dark': 'Dark',
      'default': 'Default',
      'docco': 'Docco',
      'dracula': 'Dracula',
      'far': 'Far',
      'foundation': 'Foundation',
      'github': 'GitHub',
      'github-gist': 'GitHub Gist',
      'gml': 'GML',
      'googlecode': 'Google Code',
      'gradient-dark': 'Gradient Dark',
      'grayscale': 'Grayscale',
      'gruvbox-dark': 'Gruvbox Dark',
      'gruvbox-light': 'Gruvbox Light',
      'hopscotch': 'Hopscotch',
      'hybrid': 'Hybrid',
      'idea': 'IDEA',
      'ir-black': 'IR Black',
      'isbl-editor-dark': 'ISBL Editor Dark',
      'isbl-editor-light': 'ISBL Editor Light',
      'kimbie.dark': 'Kimbie Dark',
      'kimbie.light': 'Kimbie Light',
      'lightfair': 'Lightfair',
      'magula': 'Magula',
      'mono-blue': 'Mono Blue',
      'monokai': 'Monokai',
      'monokai-sublime': 'Monokai Sublime',
      'night-owl': 'Night Owl',
      'nord': 'Nord',
      'obsidian': 'Obsidian',
      'ocean': 'Ocean',
      'paraiso-dark': 'Paraiso Dark',
      'paraiso-light': 'Paraiso Light',
      'pojoaque': 'Pojoaque',
      'purebasic': 'PureBasic',
      'qtcreator_dark': 'Qt Creator Dark',
      'qtcreator_light': 'Qt Creator Light',
      'railscasts': 'RailsCasts',
      'rainbow': 'Rainbow',
      'routeros': 'RouterOS',
      'school-book': 'School Book',
      'shades-of-purple': 'Shades of Purple',
      'solarized-dark': 'Solarized Dark',
      'solarized-light': 'Solarized Light',
      'sunburst': 'Sunburst',
      'tomorrow': 'Tomorrow',
      'tomorrow-night': 'Tomorrow Night',
      'tomorrow-night-blue': 'Tomorrow Night Blue',
      'tomorrow-night-bright': 'Tomorrow Night Bright',
      'tomorrow-night-eighties': 'Tomorrow Night Eighties',
      'vs': 'VS',
      'vs2015': 'VS 2015',
      'xcode': 'Xcode',
      'xt256': 'XT256',
      'zenburn': 'Zenburn',
    };
  }

  Map<String, TextStyle> _getThemeForColorScheme(
    ColorScheme scheme,
    String? savedTheme,
  ) {
    final themeKey =
        savedTheme ??
        (scheme.brightness == Brightness.dark ? 'dracula' : 'color-brewer');

    return _getThemeMap(themeKey);
  }

  Map<String, TextStyle> _getThemeMap(String themeKey) {
    switch (themeKey) {
      case 'a11y-dark':
        return a11yDarkTheme;
      case 'a11y-light':
        return a11yLightTheme;
      case 'agate':
        return agateTheme;
      case 'an-old-hope':
        return anOldHopeTheme;
      case 'androidstudio':
        return androidstudioTheme;
      case 'arduino-light':
        return arduinoLightTheme;
      case 'arta':
        return artaTheme;
      case 'ascetic':
        return asceticTheme;
      case 'atelier-cave-dark':
        return atelierCaveDarkTheme;
      case 'atelier-cave-light':
        return atelierCaveLightTheme;
      case 'atelier-dune-dark':
        return atelierDuneDarkTheme;
      case 'atelier-dune-light':
        return atelierDuneLightTheme;
      case 'atelier-estuary-dark':
        return atelierEstuaryDarkTheme;
      case 'atelier-estuary-light':
        return atelierEstuaryLightTheme;
      case 'atelier-forest-dark':
        return atelierForestDarkTheme;
      case 'atelier-forest-light':
        return atelierForestLightTheme;
      case 'atelier-heath-dark':
        return atelierHeathDarkTheme;
      case 'atelier-heath-light':
        return atelierHeathLightTheme;
      case 'atelier-lakeside-dark':
        return atelierLakesideDarkTheme;
      case 'atelier-lakeside-light':
        return atelierLakesideLightTheme;
      case 'atelier-plateau-dark':
        return atelierPlateauDarkTheme;
      case 'atelier-plateau-light':
        return atelierPlateauLightTheme;
      case 'atelier-savanna-dark':
        return atelierSavannaDarkTheme;
      case 'atelier-savanna-light':
        return atelierSavannaLightTheme;
      case 'atelier-seaside-dark':
        return atelierSeasideDarkTheme;
      case 'atelier-seaside-light':
        return atelierSeasideLightTheme;
      case 'atelier-sulphurpool-dark':
        return atelierSulphurpoolDarkTheme;
      case 'atelier-sulphurpool-light':
        return atelierSulphurpoolLightTheme;
      case 'atom-one-dark':
        return atomOneDarkTheme;
      case 'atom-one-dark-reasonable':
        return atomOneDarkReasonableTheme;
      case 'atom-one-light':
        return atomOneLightTheme;
      case 'brown-paper':
        return brownPaperTheme;
      case 'codepen-embed':
        return codepenEmbedTheme;
      case 'color-brewer':
        return colorBrewerTheme;
      case 'darcula':
        return darculaTheme;
      case 'dark':
        return darkTheme;
      case 'default':
        return defaultTheme;
      case 'docco':
        return doccoTheme;
      case 'dracula':
        return draculaTheme;
      case 'far':
        return farTheme;
      case 'foundation':
        return foundationTheme;
      case 'github':
        return githubTheme;
      case 'github-gist':
        return githubGistTheme;
      case 'gml':
        return gmlTheme;
      case 'googlecode':
        return googlecodeTheme;
      case 'gradient-dark':
        return gradientDarkTheme;
      case 'grayscale':
        return grayscaleTheme;
      case 'gruvbox-dark':
        return gruvboxDarkTheme;
      case 'gruvbox-light':
        return gruvboxLightTheme;
      case 'hopscotch':
        return hopscotchTheme;
      case 'hybrid':
        return hybridTheme;
      case 'idea':
        return ideaTheme;
      case 'ir-black':
        return irBlackTheme;
      case 'isbl-editor-dark':
        return isblEditorDarkTheme;
      case 'isbl-editor-light':
        return isblEditorLightTheme;
      case 'kimbie.dark':
        return kimbieDarkTheme;
      case 'kimbie.light':
        return kimbieLightTheme;
      case 'lightfair':
        return lightfairTheme;
      case 'magula':
        return magulaTheme;
      case 'mono-blue':
        return monoBlueTheme;
      case 'monokai':
        return monokaiTheme;
      case 'monokai-sublime':
        return monokaiSublimeTheme;
      case 'night-owl':
        return nightOwlTheme;
      case 'nord':
        return nordTheme;
      case 'obsidian':
        return obsidianTheme;
      case 'ocean':
        return oceanTheme;
      case 'paraiso-dark':
        return paraisoDarkTheme;
      case 'paraiso-light':
        return paraisoLightTheme;
      case 'pojoaque':
        return pojoaqueTheme;
      case 'purebasic':
        return purebasicTheme;
      case 'qtcreator_dark':
        return qtcreatorDarkTheme;
      case 'qtcreator_light':
        return qtcreatorLightTheme;
      case 'railscasts':
        return railscastsTheme;
      case 'rainbow':
        return rainbowTheme;
      case 'routeros':
        return routerosTheme;
      case 'school-book':
        return schoolBookTheme;
      case 'shades-of-purple':
        return shadesOfPurpleTheme;
      case 'solarized-dark':
        return solarizedDarkTheme;
      case 'solarized-light':
        return solarizedLightTheme;
      case 'sunburst':
        return sunburstTheme;
      case 'tomorrow':
        return tomorrowTheme;
      case 'tomorrow-night':
        return tomorrowNightTheme;
      case 'tomorrow-night-blue':
        return tomorrowNightBlueTheme;
      case 'tomorrow-night-bright':
        return tomorrowNightBrightTheme;
      case 'tomorrow-night-eighties':
        return tomorrowNightEightiesTheme;
      case 'vs':
        return vsTheme;
      case 'vs2015':
        return vs2015Theme;
      case 'xcode':
        return xcodeTheme;
      case 'xt256':
        return xt256Theme;
      case 'zenburn':
        return zenburnTheme;
      default:
        final isDark =
            Theme.of(context).colorScheme.brightness == Brightness.dark;
        return isDark ? monokaiSublimeTheme : githubTheme;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.color?.withValues(alpha: 0.7);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: theme.bodySmall?.copyWith(color: muted)),
        ),
        Expanded(child: Text(value, style: theme.bodyMedium)),
      ],
    );
  }
}

class _SearchMatch {
  const _SearchMatch({
    required this.start,
    required this.end,
    required this.lineNumber,
    required this.startColumn,
  });

  final int start;
  final int end;
  final int lineNumber; // 1-based
  final int startColumn;

  int get endColumn => startColumn + (end - start);
}

class _PlainTextViewer extends StatefulWidget {
  const _PlainTextViewer({
    super.key,
    required this.text,
    required this.style,
    required this.focusNode,
    required this.showLineNumbers,
    required this.showControls,
    required this.matchLines,
    required this.matches,
    required this.activeMatchIndex,
    required this.matchColor,
    required this.activeMatchColor,
  });

  final String text;
  final TextStyle style;
  final FocusNode focusNode;
  final bool showLineNumbers;
  final bool showControls;
  final List<int> matchLines;
  final List<_SearchMatch> matches;
  final int activeMatchIndex;
  final Color matchColor;
  final Color activeMatchColor;

  @override
  State<_PlainTextViewer> createState() => _PlainTextViewerState();
}

class _PlainTextViewerState extends State<_PlainTextViewer> {
  final ScrollController _scrollController = ScrollController();
  double _progress = 0;
  late List<String> _lines;
  double _lineHeight = 16;

  @override
  void initState() {
    super.initState();
    _lines = widget.text.split('\n');
    _updateLineHeight();
    _scrollController.addListener(_updateProgress);
  }

  @override
  void didUpdateWidget(covariant _PlainTextViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lines = widget.text.split('\n');
    }
    if (oldWidget.style != widget.style) {
      _updateLineHeight();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) {
      setState(() => _progress = 0);
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || position.maxScrollExtent == 0) {
      setState(() => _progress = 0);
      return;
    }
    final value = (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    setState(() => _progress = value);
  }

  Future<void> _scrollTo(double offset) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final target = offset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pageBy(double multiplier) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final delta = position.viewportDimension * multiplier;
    await _scrollTo(position.pixels + delta);
  }

  void _updateLineHeight() {
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    _lineHeight = painter.height;
  }

  Future<void> scrollToLine(int lineNumber) async {
    if (!_scrollController.hasClients) return;
    final index = (lineNumber - 1).clamp(0, _lines.length - 1);
    final targetOffset = index * _lineHeight;
    await _scrollTo(targetOffset);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100);
    final gutterWidth = widget.showLineNumbers
        ? (_lines.length.toString().length * 9.0)
        : 0.0;
    final activeLine =
        widget.activeMatchIndex >= 0 &&
                widget.activeMatchIndex < widget.matches.length
            ? widget.matches[widget.activeMatchIndex].lineNumber
            : null;
    final textOffsetX = widget.showLineNumbers ? gutterWidth + 12 : 0.0;
    return FocusableActionDetector(
      autofocus: true,
      focusNode: widget.focusNode,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.home): const _JumpIntent(toTop: true),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.home):
            const _JumpIntent(toTop: true),
        LogicalKeySet(LogicalKeyboardKey.end): const _JumpIntent(toTop: false),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.end):
            const _JumpIntent(toTop: false),
      },
      actions: {
        _JumpIntent: CallbackAction<_JumpIntent>(
          onInvoke: (intent) async {
            if (intent.toTop) {
              await _scrollTo(0);
            } else if (_scrollController.hasClients) {
              await _scrollTo(_scrollController.position.maxScrollExtent);
            }
            return null;
          },
        ),
      },
      child: Column(
        children: [
          if (widget.showControls) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Top',
                    icon: const Icon(Icons.vertical_align_top, size: 18),
                    onPressed: () => _scrollTo(0),
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                    onPressed: () => _pageBy(-0.9),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: () => _pageBy(0.9),
                  ),
                  IconButton(
                    tooltip: 'Bottom',
                    icon: const Icon(Icons.vertical_align_bottom, size: 18),
                    onPressed: () async {
                      if (_scrollController.hasClients) {
                        await _scrollTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Text('${percent.toStringAsFixed(0)}%'),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 14),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _InlineMatchPainter(
                                    lines: _lines,
                                    textStyle: widget.style,
                                    lineHeight: _lineHeight,
                                    textOffsetX: textOffsetX,
                                    matches: widget.matches,
                                    activeMatchIndex: widget.activeMatchIndex,
                                    matchColor: widget.matchColor,
                                    activeMatchColor: widget.activeMatchColor,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.showLineNumbers)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: gutterWidth,
                                      ),
                                      child: Text(
                                        List.generate(
                                          _lines.length,
                                          (index) => '${index + 1}',
                                        ).join('\n'),
                                        textAlign: TextAlign.right,
                                        style: widget.style.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.7),
                                          height: widget.style.height ?? 1.2,
                                        ),
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: SelectableRegion(
                                    selectionControls:
                                        materialTextSelectionControls,
                                    child: Text(
                                      widget.text,
                                      style: widget.style.copyWith(
                                        height: widget.style.height ?? 1.2,
                                      ),
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      width: 8,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MatchMarkersPainter(
                            lineCount: _lines.length,
                            matches: widget.matchLines,
                            color: widget.matchColor,
                            activeColor: widget.activeMatchColor,
                            activeLine: activeLine,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpIntent extends Intent {
  const _JumpIntent({required this.toTop});

  final bool toTop;
}

class _MatchMarkersPainter extends CustomPainter {
  _MatchMarkersPainter({
    required this.lineCount,
    required this.matches,
    required this.color,
    required this.activeColor,
    required this.activeLine,
  });

  final int lineCount;
  final List<int> matches;
  final Color color;
  final Color activeColor;
  final int? activeLine;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount == 0 || matches.isEmpty) return;
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    final activePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    for (final match in matches) {
      final safeLine = match.clamp(1, lineCount);
      final frac = (safeLine - 0.5) / lineCount;
      final dy = (size.height - 6) * frac.clamp(0.0, 1.0);
      final isActive = activeLine != null && safeLine == activeLine;
      canvas.drawLine(
        Offset(size.width - 1.5, dy),
        Offset(size.width - 1.5, dy + 8),
        isActive ? activePaint : basePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MatchMarkersPainter oldDelegate) {
    return lineCount != oldDelegate.lineCount ||
        color != oldDelegate.color ||
        activeColor != oldDelegate.activeColor ||
        activeLine != oldDelegate.activeLine ||
        matches.length != oldDelegate.matches.length ||
        !_listEquals(matches, oldDelegate.matches);
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _InlineMatchPainter extends CustomPainter {
  _InlineMatchPainter({
    required this.lines,
    required this.textStyle,
    required this.lineHeight,
    required this.textOffsetX,
    required this.matches,
    required this.activeMatchIndex,
    required this.matchColor,
    required this.activeMatchColor,
  });

  final List<String> lines;
  final TextStyle textStyle;
  final double lineHeight;
  final double textOffsetX;
  final List<_SearchMatch> matches;
  final int activeMatchIndex;
  final Color matchColor;
  final Color activeMatchColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty || lines.isEmpty) return;
    final effectiveStyle = textStyle.copyWith(
      height: textStyle.height ?? 1.2,
    );
    final direction = TextDirection.ltr;
    final matchPaint = Paint()..color = matchColor;
    final activePaint = Paint()..color = activeMatchColor;

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final lineIndex = match.lineNumber - 1;
      if (lineIndex < 0 || lineIndex >= lines.length) continue;
      final lineText = lines[lineIndex];
      final endColumn =
          match.endColumn > lineText.length ? lineText.length : match.endColumn;
      final painter = TextPainter(
        text: TextSpan(text: lineText, style: effectiveStyle),
        textDirection: direction,
      )..layout();
      final boxes = painter.getBoxesForSelection(
        TextSelection(
          baseOffset: match.startColumn,
          extentOffset: endColumn,
        ),
      );
      final paint = i == activeMatchIndex ? activePaint : matchPaint;
      for (final box in boxes) {
        final width = box.right - box.left;
        final height = box.bottom - box.top;
        final rect = Rect.fromLTWH(
          textOffsetX + box.left,
          (lineIndex * lineHeight) + box.top,
          width,
          height,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InlineMatchPainter oldDelegate) {
    return lineHeight != oldDelegate.lineHeight ||
        textOffsetX != oldDelegate.textOffsetX ||
        textStyle != oldDelegate.textStyle ||
        lines.length != oldDelegate.lines.length ||
        matchColor != oldDelegate.matchColor ||
        activeMatchColor != oldDelegate.activeMatchColor ||
        activeMatchIndex != oldDelegate.activeMatchIndex ||
        matches.length != oldDelegate.matches.length ||
        !_matchesEqual(matches, oldDelegate.matches);
  }

  bool _matchesEqual(List<_SearchMatch> a, List<_SearchMatch> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.start != right.start ||
          left.end != right.end ||
          left.lineNumber != right.lineNumber ||
          left.startColumn != right.startColumn) {
        return false;
      }
    }
    return true;
  }
}
