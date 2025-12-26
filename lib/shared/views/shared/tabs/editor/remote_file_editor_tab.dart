import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../models/ssh_host.dart';
import '../../../../../services/settings/app_settings_controller.dart';
import '../../../../../services/ssh/remote_shell_service.dart';
import '../../../../../shared/gestures/gesture_activators.dart';
import '../../../../../shared/gestures/gesture_service.dart';
import '../../../../../shared/shortcuts/input_mode_resolver.dart';
import '../../../../../shared/shortcuts/shortcut_actions.dart';
import '../../../../../shared/shortcuts/shortcut_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../theme/nerd_fonts.dart';
import '../../../../mixins/tab_options_mixin.dart';
import '../../../../widgets/inline_search_bar.dart';
import '../tab_chip.dart';
import 'remote_file_editor/code_editor_view.dart';
import 'remote_file_editor/editor_state.dart';
import 'remote_file_editor/editor_theme_utils.dart';
import 'remote_file_editor/file_info_dialog.dart';
import 'remote_file_editor/language_detection.dart';
import 'remote_file_editor/plain_pager_view.dart';
import 'remote_file_editor/theme_picker.dart';

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

class _RemoteFileEditorTabState extends State<RemoteFileEditorTab>
    with TabOptionsMixin {
  late final EditorState _state;
  final GlobalKey<PlainPagerViewState> _plainViewerKey =
      GlobalKey<PlainPagerViewState>();
  ShortcutSubscription? _shortcutSub;
  ShortcutSubscription? _pagerShortcutSub;
  GestureSubscription? _gestureSub;
  GestureSubscription? _pagerGestureSub;
  late final VoidCallback _settingsListener;
  double? _scaleStartFontSize;

  @override
  void initState() {
    super.initState();
    _state =
        EditorState(
            path: widget.path,
            initialContent: widget.initialContent,
            settingsController: widget.settingsController,
          )
          ..addListener(_handleStateChanged)
          ..registerPagerScroller((line) async {
            final viewer = _plainViewerKey.currentState;
            if (viewer != null) {
              await viewer.scrollToLine(line);
            }
          });
    _settingsListener = _configureInputMode;
    widget.settingsController.addListener(_settingsListener);
    _configureInputMode();
    _updateTabOptions();
  }

  @override
  void dispose() {
    _shortcutSub?.dispose();
    _pagerShortcutSub?.dispose();
    _gestureSub?.dispose();
    _pagerGestureSub?.dispose();
    widget.settingsController.removeListener(_settingsListener);
    _state.removeListener(_handleStateChanged);
    _state.unregisterPagerScroller();
    _state.dispose();
    super.dispose();
  }

  void _handleStateChanged() {
    if (!mounted) return;
    setState(() {});
    _updateTabOptions();
  }

  Future<void> _handleSave() async {
    final saved = await _state.save(widget.onSave);
    _updateTabOptions();
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved ${widget.path}')));
  }

  Widget _wrapWithGestures(Widget child, InputModeConfig inputMode) {
    if (!inputMode.enableGestures) return child;
    return GestureDetector(
      onScaleStart: (details) {
        if (details.pointerCount < 2) return;
        _scaleStartFontSize = widget.settingsController.settings.editorFontSize;
      },
      onScaleUpdate: (details) {
        if (_scaleStartFontSize == null || details.pointerCount < 2) return;
        final target = (_scaleStartFontSize! * details.scale)
            .clamp(8, 32)
            .toDouble();
        _dispatchEditorPinch(target);
      },
      onScaleEnd: (_) => _scaleStartFontSize = null,
      child: child,
    );
  }

  void _configureInputMode() {
    final inputMode = resolveInputMode(
      widget.settingsController.settings.inputModePreference,
      defaultTargetPlatform,
    );
    _configureShortcuts(inputMode);
    _configureGestures(inputMode);
  }

  void _configureShortcuts(InputModeConfig inputMode) {
    if (!inputMode.enableShortcuts) {
      _shortcutSub?.dispose();
      _shortcutSub = null;
      _pagerShortcutSub?.dispose();
      _pagerShortcutSub = null;
      return;
    }
    if (_shortcutSub != null && _pagerShortcutSub != null) return;
    _shortcutSub?.dispose();
    _pagerShortcutSub?.dispose();
    _registerShortcuts();
  }

  void _configureGestures(InputModeConfig inputMode) {
    if (!inputMode.enableGestures) {
      _gestureSub?.dispose();
      _gestureSub = null;
      _pagerGestureSub?.dispose();
      _pagerGestureSub = null;
      return;
    }
    _gestureSub ??= GestureService.instance.registerScope(
      id: 'editor_gestures',
      handlers: {
        Gestures.editorPinchZoom: (invocation) {
          final next = invocation.payloadAs<double>();
          if (next != null) {
            unawaited(_setEditorFontSize(next));
          }
        },
      },
      focusNode: _state.editorFocusNode,
      priority: 5,
    );
    _pagerGestureSub ??= GestureService.instance.registerScope(
      id: 'editor_pager_gestures',
      handlers: {
        Gestures.editorPinchZoom: (invocation) {
          final next = invocation.payloadAs<double>();
          if (next != null) {
            unawaited(_setEditorFontSize(next));
          }
        },
      },
      focusNode: _state.plainViewerFocusNode,
      priority: 5,
    );
  }

  Map<String, TextStyle> _getThemeForColorScheme(ColorScheme scheme) {
    final savedTheme = _state.savedThemeForBrightness(scheme.brightness);
    final themeKey =
        savedTheme ??
        (scheme.brightness == Brightness.dark ? 'dracula' : 'color-brewer');
    return editorThemeStyles(themeKey);
  }

  Future<void> _showThemeDialog(BuildContext context) async {
    final brightness = Theme.of(context).colorScheme.brightness;
    final savedTheme = _state.savedThemeForBrightness(brightness);
    await showEditorThemeDialog(
      context: context,
      brightness: brightness,
      savedTheme: savedTheme,
      onPreview: (key) => _state.saveThemeForBrightness(brightness, key),
      onSelect: (key) => _state.saveThemeForBrightness(brightness, key),
    );
  }

  void _showFileInfo(BuildContext context) {
    final language = languageFromPath(widget.path);
    final parser = _state.controller.language?.runtimeType.toString();
    showFileInfoDialog(
      context: context,
      path: widget.path,
      content: _state.controller.text,
      language: language,
      parserName: parser,
      helperText: widget.helperText,
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final languages = availableLanguageKeys();
    final currentKey = languageFromPath(widget.path);
    String? selected = currentKey;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select language'),
          content: SizedBox(
            width: 360,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              hint: const Text('Auto-detect'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Auto-detect')),
                ...languages.map(
                  (key) => DropdownMenuItem(value: key, child: Text(key)),
                ),
              ],
              onChanged: (value) {
                selected = value;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _state.setLanguageByKey(selected);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _updateTabOptions() {
    final options = [
      TabChipOption(
        label: 'Save',
        icon: NerdIcon.cloudUpload.data,
        enabled: _state.dirty && !_state.saving,
        onSelected: _handleSave,
      ),
      TabChipOption(
        label: _state.searchVisible ? 'Hide search' : 'Find',
        icon: Icons.search,
        onSelected: _state.toggleSearchBar,
      ),
      TabChipOption(
        label: _state.pagerMode ? 'Use editor' : 'Use pager',
        icon: Icons.view_headline,
        color: _state.pagerMode ? Colors.amber : null,
        onSelected: _state.togglePagerMode,
      ),
      if (_state.pagerMode)
        TabChipOption(
          label: _state.showPagerControls
              ? 'Hide pager controls'
              : 'Show pager controls',
          icon: Icons.view_headline,
          onSelected: _state.togglePagerControls,
        ),
      TabChipOption(
        label: _state.highlightEnabled
            ? 'Disable highlighting'
            : 'Enable highlighting',
        icon: Icons.speed,
        color: _state.pagerMode && _state.highlightEnabled
            ? Colors.amber
            : null,
        onSelected: _state.toggleHighlighting,
      ),
      TabChipOption(
        label: _state.showLineNumbers
            ? 'Hide line numbers'
            : 'Show line numbers',
        icon: Icons.format_list_numbered,
        onSelected: _state.toggleLineNumbers,
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
      TabChipOption(
        label: 'Language',
        icon: Icons.code,
        onSelected: () => _showLanguageDialog(context),
      ),
    ];

    queueTabOptions(widget.optionsController, options, useBase: true);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = _getThemeForColorScheme(colorScheme);
    final settings = widget.settingsController.settings;
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    final usePlainViewer = _state.usePagerView;
    final baseTextStyle = TextStyle(
      fontFamily: NerdFonts.effectiveFamily(settings.editorFontFamily),
      fontSize: settings.editorFontSize.clamp(8, 32).toDouble(),
      height: settings.editorLineHeight.clamp(1.0, 2.0).toDouble(),
    );
    final matchColor = colorScheme.primaryContainer.withValues(alpha: 0.28);
    final activeMatchColor = colorScheme.primary.withValues(alpha: 0.45);
    return Padding(
      padding: context.appTheme.spacing.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_state.searchVisible)
            InlineSearchBar(
              controller: _state.searchController,
              onSubmit: (value) => _state.performSearch(value, forward: true),
              onPrev: () => _state.performSearch(
                _state.searchController.text,
                forward: false,
              ),
              onNext: () => _state.performSearch(
                _state.searchController.text,
                forward: true,
              ),
              onClose: _state.toggleSearchBar,
            ),
          Expanded(
            child: _wrapWithGestures(
              usePlainViewer
                  ? PlainPagerView(
                      key: _plainViewerKey,
                      text: _state.controller.fullText,
                      style: baseTextStyle,
                      focusNode: _state.plainViewerFocusNode,
                      showLineNumbers: _state.showLineNumbers,
                      showControls: _state.showPagerControls,
                      matchLines: _state.searchMatchLines,
                      matches: _state.searchMatches,
                      activeMatchIndex: _state.activeMatch,
                      matchColor: matchColor,
                      activeMatchColor: activeMatchColor,
                      onRegisterScrollToLine: _state.registerPagerScroller,
                    )
                  : CodeEditorView(
                      controller: _state.controller,
                      focusNode: _state.editorFocusNode,
                      baseTextStyle: baseTextStyle,
                      themeStyles: theme,
                      showLineNumbers: _state.showLineNumbers,
                      highlightEnabled: _state.highlightEnabled,
                      lineCount: _state.searchLineCount,
                      matchLines: _state.searchMatchLines,
                      activeLine: _state.activeMatchLine,
                      matchColor: matchColor,
                      activeMatchColor: activeMatchColor,
                    ),
              inputMode,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEditorFont(double delta) async {
    await widget.settingsController.update((current) {
      final next = (current.editorFontSize + delta).clamp(8, 32).toDouble();
      return current.copyWith(editorFontSize: next);
    });
  }

  Future<void> _setEditorFontSize(double value) async {
    await widget.settingsController.update((current) {
      final next = value.clamp(8, 32).toDouble();
      if (next == current.editorFontSize) return current;
      return current.copyWith(editorFontSize: next);
    });
  }

  void _dispatchEditorPinch(double value) {
    final handled = GestureService.instance.handle(
      Gestures.editorPinchZoom,
      payload: value,
    );
    if (!handled) {
      unawaited(_setEditorFontSize(value));
    }
  }

  void _registerShortcuts() {
    final handlers = {
      ShortcutActions.editorZoomIn: () => _changeEditorFont(1),
      ShortcutActions.editorZoomOut: () => _changeEditorFont(-1),
    };
    _shortcutSub = ShortcutService.instance.registerScope(
      id: 'editor',
      handlers: handlers,
      focusNode: _state.editorFocusNode,
      priority: 5,
      consumeOnHandle: false,
    );
    _pagerShortcutSub = ShortcutService.instance.registerScope(
      id: 'editor_pager',
      handlers: handlers,
      focusNode: _state.plainViewerFocusNode,
      priority: 5,
      consumeOnHandle: false,
    );
  }
}
