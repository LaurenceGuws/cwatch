import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
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

import '../../../../models/ssh_host.dart';
import '../../../../services/settings/app_settings_controller.dart';
import '../../../../services/ssh/remote_shell_service.dart';
import '../../../theme/nerd_fonts.dart';

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
  });

  final SshHost host;
  final RemoteShellService shellService;
  final String path;
  final String initialContent;
  final Future<void> Function(String content) onSave;
  final AppSettingsController settingsController;
  final String? helperText;

  @override
  State<RemoteFileEditorTab> createState() => _RemoteFileEditorTabState();
}

class _RemoteFileEditorTabState extends State<RemoteFileEditorTab> {
  late final CodeController _controller;
  late String _normalizedInitialContent;
  bool _dirty = false;
  bool _saving = false;
  String? _saveError;
  String? _languageOverride;

  @override
  void initState() {
    super.initState();
    // Normalize line endings to avoid false positives
    _normalizedInitialContent = _normalizeLineEndings(widget.initialContent);
    final language = _getLanguageForKey(_languageFromPath(widget.path));
    _controller = CodeController(
      text: _normalizedInitialContent,
      language: language,
    )..addListener(_handleTextChange);
    widget.settingsController.addListener(_handleSettingsChanged);
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
    return Column(
      children: [
        // Toolbar
        Material(
          elevation: 1,
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.path,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value:
                          _languageOverride ?? _languageFromPath(widget.path),
                      items: _languageDropdownItems(),
                      onChanged: _handleLanguageChanged,
                      hint: const Text('Language'),
                    ),
                  ),
                ),
                if (_dirty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'Unsaved changes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _saveError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings),
                  onSelected: (value) {
                    if (value == 'file-info') {
                      _showFileInfo(context);
                    } else if (value == 'theme') {
                      _showThemeDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'file-info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 20),
                          SizedBox(width: 8),
                          Text('File Info'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'theme',
                      child: Row(
                        children: [
                          Icon(Icons.palette, size: 20),
                          SizedBox(width: 8),
                          Text('Theme'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: _dirty && !_saving ? _handleSave : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(NerdIcon.cloudUpload.data),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
        // Editor content - full width and scrollable
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CodeTheme(
              data: CodeThemeData(styles: theme),
            child: CodeField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textStyle: TextStyle(
                fontFamily:
                    NerdFonts.effectiveFamily(settings.editorFontFamily),
                fontSize: settings.editorFontSize.clamp(8, 32).toDouble(),
                height: settings.editorLineHeight.clamp(1.0, 2.0).toDouble(),
              ),
              gutterStyle: const GutterStyle(
                showLineNumbers: true,
                showErrors: false,
                showFoldingHandles: true,
              ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved ${widget.path}')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Save failed: $error';
      });
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
        _saveError = null;
      });
    }
  }

  void _showThemeDialog(BuildContext context) {
    final themes = _getAllThemes();
    final brightness = Theme.of(context).colorScheme.brightness;
    final savedTheme = _getSavedThemeForBrightness(brightness);
    final currentTheme =
        savedTheme ??
        (brightness == Brightness.dark ? 'dracula' : 'color-brewer');

    String? previewTheme = currentTheme;
    String? originalTheme = savedTheme;
    final themeList = themes.entries.toList();
    int selectedIndex = themeList.indexWhere((e) => e.key == currentTheme);
    if (selectedIndex == -1) selectedIndex = 0;

    final scrollController = ScrollController();
    final focusNode = FocusNode();

    void selectTheme(int index) {
      if (index >= 0 && index < themeList.length) {
        final themeKey = themeList[index].key;
        previewTheme = themeKey;
        // Update the editor theme in real-time
        _saveThemeForBrightness(brightness, themeKey);
        setState(() {});
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Scroll to selected item when dialog opens
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scrollController.hasClients && selectedIndex >= 0) {
              final itemHeight = 56.0; // Approximate height of ListTile
              final scrollOffset = selectedIndex * itemHeight;
              scrollController.animateTo(
                scrollOffset.clamp(
                  0.0,
                  scrollController.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });

          return KeyboardListener(
            focusNode: focusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                final keyLabel = event.logicalKey.keyLabel;
                if (keyLabel == 'Arrow Down') {
                  setDialogState(() {
                    selectedIndex = (selectedIndex + 1).clamp(
                      0,
                      themeList.length - 1,
                    );
                    selectTheme(selectedIndex);
                    // Scroll to keep selected item visible
                    if (scrollController.hasClients) {
                      final itemHeight = 56.0;
                      final scrollOffset = selectedIndex * itemHeight;
                      scrollController.animateTo(
                        scrollOffset.clamp(
                          0.0,
                          scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                } else if (keyLabel == 'Arrow Up') {
                  setDialogState(() {
                    selectedIndex = (selectedIndex - 1).clamp(
                      0,
                      themeList.length - 1,
                    );
                    selectTheme(selectedIndex);
                    // Scroll to keep selected item visible
                    if (scrollController.hasClients) {
                      final itemHeight = 56.0;
                      final scrollOffset = selectedIndex * itemHeight;
                      scrollController.animateTo(
                        scrollOffset.clamp(
                          0.0,
                          scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                } else if (keyLabel == 'Enter') {
                  // Selection is already applied, just close
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: AlertDialog(
              title: const Text('Select Theme'),
              content: SizedBox(
                width: 400,
                height: 500,
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: themeList.length,
                  itemBuilder: (context, index) {
                    final entry = themeList[index];
                    final themeKey = entry.key;
                    final themeName = entry.value;
                    final isSelected = themeKey == previewTheme;
                    final isFocused = index == selectedIndex;

                    return ListTile(
                      selected: isSelected || isFocused,
                      leading: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const SizedBox(width: 24),
                      title: Text(themeName),
                      onTap: () {
                        setDialogState(() {
                          selectedIndex = index;
                          previewTheme = themeKey;
                        });
                        // Update the editor theme in real-time
                        _saveThemeForBrightness(brightness, themeKey);
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Revert to original theme
                    if (originalTheme != null) {
                      _saveThemeForBrightness(brightness, originalTheme);
                    } else {
                      // Clear saved theme to use default
                      _saveThemeForBrightness(
                        brightness,
                        brightness == Brightness.dark
                            ? 'dracula'
                            : 'color-brewer',
                      );
                    }
                    setState(() {});
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    // Selection is already applied in real-time, just close
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Select'),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      scrollController.dispose();
      focusNode.dispose();
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

  List<DropdownMenuItem<String?>> _languageDropdownItems() {
    final detected = _languageFromPath(widget.path);
    final entries = [
      DropdownMenuItem<String?>(
        value: null,
        child: Text(
          detected != null ? 'Auto ($detected)' : 'Auto (plain text)',
        ),
      ),
      ...() {
        final keys = all_langs.allLanguages.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        return keys
            .map(
              (key) => DropdownMenuItem<String?>(
                value: key,
                child: Text(key),
              ),
            )
            .toList();
      }(),
    ];
    return entries;
  }

  void _handleLanguageChanged(String? key) {
    setState(() {
      _languageOverride = key;
      _controller.language = _getLanguageForKey(
        key ?? _languageFromPath(widget.path),
      );
    });
  }

  dynamic _getLanguageForKey(String? languageId) {
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
