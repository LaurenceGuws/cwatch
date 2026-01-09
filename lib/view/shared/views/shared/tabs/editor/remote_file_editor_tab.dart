import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/controller/adapters/remote_file_editor_ui_adapter.dart';
import 'package:cwatch/controller/controllers/remote_file_editor_controller.dart';

import 'package:cwatch/controller/controllers/settings_controller.dart';
import 'package:cwatch/model/shared/gestures/gesture_activators.dart';
import 'package:cwatch/model/shared/gestures/gesture_service.dart';
import 'package:cwatch/model/shared/shortcuts/input_mode_resolver.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_actions.dart';
import 'package:cwatch/model/shared/shortcuts/shortcut_service.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/model/shared/theme/nerd_fonts.dart';
import 'package:cwatch/model/shared/mixins/tab_options_mixin.dart';
import 'package:cwatch/view/features/settings/settings/editor_settings_controls.dart';
import '../tab_chip.dart';
import '../settings/floating_settings_window.dart';
import 'remote_file_editor/code_editor_view.dart';
import 'remote_file_editor/editor_state.dart';
import 'remote_file_editor/editor_theme_utils.dart';
import 'remote_file_editor/language_detection.dart';

class RemoteFileEditorTab extends StatefulWidget {
  const RemoteFileEditorTab({
    super.key,
    required this.controller,
    required this.uiAdapter,
    required this.path,
    required this.initialContent,
    required this.settingsController,
    this.helperText,
    this.optionsController,
  });

  final RemoteFileEditorController controller;
  final RemoteFileEditorUiAdapter uiAdapter;
  final String path;
  final String initialContent;
  final SettingsController settingsController;
  final String? helperText;
  final TabOptionsController? optionsController;

  @override
  State<RemoteFileEditorTab> createState() => _RemoteFileEditorTabState();
}

class _RemoteFileEditorTabState extends State<RemoteFileEditorTab>
    with TabOptionsMixin {
  late SettingsController _settingsController;
  late final EditorState _state;
  ShortcutSubscription? _shortcutSub;
  GestureSubscription? _gestureSub;
  late final VoidCallback _settingsListener;
  double? _scaleStartFontSize;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController;
    _state = EditorState(
      path: widget.path,
      initialContent: widget.initialContent,
      settingsController: _settingsController,
    )..addListener(_handleStateChanged);
    _settingsListener = _configureInputMode;
    _settingsController.addListener(_settingsListener);
    _configureInputMode();
    _updateTabOptions();
  }

  @override
  void dispose() {
    _shortcutSub?.dispose();
    _gestureSub?.dispose();
    _settingsController
      ..removeListener(_settingsListener)
      ..dispose();
    _state.removeListener(_handleStateChanged);
    _state.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RemoteFileEditorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.removeListener(_settingsListener);
      oldWidget.settingsController.dispose();
      _settingsController = widget.settingsController;
      _settingsController.addListener(_settingsListener);
      _configureInputMode();
    }
  }

  void _handleStateChanged() {
    if (!mounted) return;
    setState(() {});
    _updateTabOptions();
  }

  Future<void> _handleSave() async {
    final saved = await _state.save(widget.controller.saveContent);
    _updateTabOptions();
    if (!mounted || !saved) return;
    widget.uiAdapter.showSnackBar('Saved ${widget.path}');
  }

  Widget _wrapWithGestures(Widget child, InputModeConfig inputMode) {
    if (!inputMode.enableGestures) return child;
    return GestureDetector(
      onScaleStart: (details) {
        if (details.pointerCount < 2) return;
        _scaleStartFontSize = _settingsController.settings.editorFontSize;
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
      _settingsController.settings.inputModePreference,
      defaultTargetPlatform,
    );
    _configureShortcuts(inputMode);
    _configureGestures(inputMode);
  }

  void _configureShortcuts(InputModeConfig inputMode) {
    if (!inputMode.enableShortcuts) {
      _shortcutSub?.dispose();
      _shortcutSub = null;
      return;
    }
    if (_shortcutSub != null) {
      return;
    }
    _shortcutSub?.dispose();
    _registerShortcuts();
  }

  void _configureGestures(InputModeConfig inputMode) {
    if (!inputMode.enableGestures) {
      _gestureSub?.dispose();
      _gestureSub = null;
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
  }

  Map<String, TextStyle> _getThemeForColorScheme(ColorScheme scheme) {
    final savedTheme = _state.savedThemeForBrightness(scheme.brightness);
    final themeKey =
        savedTheme ??
        (scheme.brightness == Brightness.dark ? 'dracula' : 'color-brewer');
    return editorThemeStyles(themeKey);
  }

  void _showFileInfo(BuildContext context) {
    final language = languageFromPath(widget.path);
    final parser = _state.controller.language?.runtimeType.toString();
    widget.uiAdapter.showFileInfoDialog(
      path: widget.path,
      content: _state.controller.text,
      language: language ?? 'Unknown',
      parserName: parser,
      helperText: widget.helperText,
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
        label: 'File info',
        icon: Icons.info_outline,
        onSelected: () => _showFileInfo(context),
      ),
      TabChipOption(
        label: _showSettings ? 'Hide settings' : 'Settings',
        icon: Icons.settings,
        onSelected: _toggleSettings,
      ),
    ];

    queueTabOptions(widget.optionsController, options, useBase: true);
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
    });
    _updateTabOptions();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = _getThemeForColorScheme(colorScheme);
    final settings = _settingsController.settings;
    final inputMode = resolveInputMode(
      settings.inputModePreference,
      defaultTargetPlatform,
    );
    final baseTextStyle = TextStyle(
      fontFamily: NerdFonts.effectiveFamily(settings.editorFontFamily),
      fontSize: settings.editorFontSize.clamp(8, 32).toDouble(),
      height: settings.editorLineHeight.clamp(1.0, 2.0).toDouble(),
    );
    final spacing = context.appTheme.spacing;
    return Padding(
      padding: spacing.inset(horizontal: 2, vertical: 1),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _wrapWithGestures(
                  CodeEditorView(
                    controller: _state.controller,
                    focusNode: _state.editorFocusNode,
                    baseTextStyle: baseTextStyle,
                    themeStyles: theme,
                    showLineNumbers: _state.showLineNumbers,
                    highlightEnabled: _state.highlightEnabled,
                  ),
                  inputMode,
                ),
              ),
            ],
          ),
          if (_showSettings)
            FloatingSettingsWindow(
              title: 'Editor Settings',
              onClose: _toggleSettings,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Syntax Highlighting'),
                    value: _state.highlightEnabled,
                    onChanged: (_) => _state.toggleHighlighting(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Line Numbers'),
                    value: _state.showLineNumbers,
                    onChanged: (_) => _state.toggleLineNumbers(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  EditorSettingsControls(
                    fontFamily: settings.editorFontFamily,
                    fontSize: settings.editorFontSize,
                    lineHeight: settings.editorLineHeight,
                    lightTheme: settings.editorThemeLight,
                    darkTheme: settings.editorThemeDark,
                    onFontFamilyChanged: (value) => _settingsController.update(
                      (s) => s.copyWith(editorFontFamily: value),
                    ),
                    onFontSizeChanged: (value) => _settingsController.update(
                      (s) => s.copyWith(editorFontSize: value),
                    ),
                    onLineHeightChanged: (value) => _settingsController.update(
                      (s) => s.copyWith(editorLineHeight: value),
                    ),
                    onLightThemeChanged: (value) => _settingsController.update(
                      (s) => s.copyWith(editorThemeLight: value),
                    ),
                    onDarkThemeChanged: (value) => _settingsController.update(
                      (s) => s.copyWith(editorThemeDark: value),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _changeEditorFont(double delta) async {
    await _settingsController.update((current) {
      final next = (current.editorFontSize + delta).clamp(8, 32).toDouble();
      return current.copyWith(editorFontSize: next);
    });
  }

  Future<void> _setEditorFontSize(double value) async {
    await _settingsController.update((current) {
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
  }
}
