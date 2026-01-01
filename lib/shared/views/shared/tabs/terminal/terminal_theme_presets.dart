import 'dart:io';

import 'package:flutter/services.dart';
import 'package:cwatch/services/logging/app_logger.dart';
import 'package:cwatch/services/settings/settings_path_provider.dart';
import 'package:cwatch/shared/views/shared/tabs/editor/remote_file_editor/editor_theme_utils.dart';
import 'package:path/path.dart' as p;
import 'package:toml/toml.dart';
import 'package:xterm/xterm.dart';

const Color _searchHitBackground = Color(0x66f6d32d);
const Color _searchHitBackgroundCurrent = Color(0x66ff8c00);
const Color _searchHitForeground = Color(0xff000000);

const Map<String, String> terminalThemeLabels = {
  'xterm-default': 'Xterm Default',
  'xterm-white-on-black': 'Xterm White on Black',
  'dracula': 'Dracula',
  'solarized-dark': 'Solarized Dark',
  'solarized-light': 'Solarized Light',
  'nord': 'Nord',
  'monokai': 'Monokai',
  'one-dark': 'One Dark',
  'gruvbox-dark': 'Gruvbox Dark',
  'gruvbox-light': 'Gruvbox Light',
  'tokyo-night': 'Tokyo Night',
  'night-owl': 'Night Owl',
};

final Map<String, TerminalTheme> terminalThemes = {
  'xterm-default': TerminalThemes.defaultTheme,
  'xterm-white-on-black': TerminalThemes.whiteOnBlack,
  'dracula': _theme(
    cursor: 0xffbd93f9,
    selection: 0xff44475a,
    foreground: 0xfff8f8f2,
    background: 0xff282a36,
    black: 0xff21222c,
    red: 0xffff5555,
    green: 0xff50fa7b,
    yellow: 0xfff1fa8c,
    blue: 0xffbd93f9,
    magenta: 0xffff79c6,
    cyan: 0xff8be9fd,
    white: 0xfff8f8f2,
    brightBlack: 0xff6272a4,
    brightRed: 0xffff6e6e,
    brightGreen: 0xff69ff94,
    brightYellow: 0xfffffa87,
    brightBlue: 0xffd6acff,
    brightMagenta: 0xffff92df,
    brightCyan: 0xffa4ffff,
    brightWhite: 0xffffffff,
  ),
  'solarized-dark': _theme(
    cursor: 0xff839496,
    selection: 0xff073642,
    foreground: 0xff839496,
    background: 0xff002b36,
    black: 0xff073642,
    red: 0xffdc322f,
    green: 0xff859900,
    yellow: 0xffb58900,
    blue: 0xff268bd2,
    magenta: 0xffd33682,
    cyan: 0xff2aa198,
    white: 0xffeee8d5,
    brightBlack: 0xff002b36,
    brightRed: 0xffcb4b16,
    brightGreen: 0xff586e75,
    brightYellow: 0xff657b83,
    brightBlue: 0xff839496,
    brightMagenta: 0xff6c71c4,
    brightCyan: 0xff93a1a1,
    brightWhite: 0xfffdf6e3,
  ),
  'solarized-light': _theme(
    cursor: 0xff657b83,
    selection: 0xffeee8d5,
    foreground: 0xff586e75,
    background: 0xfffdf6e3,
    black: 0xff073642,
    red: 0xffdc322f,
    green: 0xff859900,
    yellow: 0xffb58900,
    blue: 0xff268bd2,
    magenta: 0xffd33682,
    cyan: 0xff2aa198,
    white: 0xffeee8d5,
    brightBlack: 0xff002b36,
    brightRed: 0xffcb4b16,
    brightGreen: 0xff586e75,
    brightYellow: 0xff657b83,
    brightBlue: 0xff839496,
    brightMagenta: 0xff6c71c4,
    brightCyan: 0xff93a1a1,
    brightWhite: 0xfffdf6e3,
  ),
  'nord': _theme(
    cursor: 0xff81a1c1,
    selection: 0xff3b4252,
    foreground: 0xffd8dee9,
    background: 0xff2e3440,
    black: 0xff3b4252,
    red: 0xffbf616a,
    green: 0xffa3be8c,
    yellow: 0xffebcb8b,
    blue: 0xff81a1c1,
    magenta: 0xffb48ead,
    cyan: 0xff88c0d0,
    white: 0xffe5e9f0,
    brightBlack: 0xff4c566a,
    brightRed: 0xffbf616a,
    brightGreen: 0xffa3be8c,
    brightYellow: 0xffebcb8b,
    brightBlue: 0xff81a1c1,
    brightMagenta: 0xffb48ead,
    brightCyan: 0xff8fbcbb,
    brightWhite: 0xffeceff4,
  ),
  'monokai': _theme(
    cursor: 0xfffd9720,
    selection: 0xff49483e,
    foreground: 0xfff8f8f2,
    background: 0xff272822,
    black: 0xff272822,
    red: 0xfff92672,
    green: 0xffa6e22e,
    yellow: 0xfff4bf75,
    blue: 0xff66d9ef,
    magenta: 0xffae81ff,
    cyan: 0xffa1efe4,
    white: 0xfff8f8f2,
    brightBlack: 0xff75715e,
    brightRed: 0xfff92672,
    brightGreen: 0xffa6e22e,
    brightYellow: 0xfff4bf75,
    brightBlue: 0xff66d9ef,
    brightMagenta: 0xffae81ff,
    brightCyan: 0xffa1efe4,
    brightWhite: 0xffffffff,
  ),
  'one-dark': _theme(
    cursor: 0xff528bff,
    selection: 0xff3e4451,
    foreground: 0xffabb2bf,
    background: 0xff282c34,
    black: 0xff282c34,
    red: 0xffe06c75,
    green: 0xff98c379,
    yellow: 0xffe5c07b,
    blue: 0xff61afef,
    magenta: 0xffc678dd,
    cyan: 0xff56b6c2,
    white: 0xffdcdfe4,
    brightBlack: 0xff5c6370,
    brightRed: 0xffe06c75,
    brightGreen: 0xff98c379,
    brightYellow: 0xffe5c07b,
    brightBlue: 0xff61afef,
    brightMagenta: 0xffc678dd,
    brightCyan: 0xff56b6c2,
    brightWhite: 0xffffffff,
  ),
  'gruvbox-dark': _theme(
    cursor: 0xffd5c4a1,
    selection: 0xff3c3836,
    foreground: 0xffebdbb2,
    background: 0xff282828,
    black: 0xff282828,
    red: 0xffcc241d,
    green: 0xff98971a,
    yellow: 0xffd79921,
    blue: 0xff458588,
    magenta: 0xffb16286,
    cyan: 0xff689d6a,
    white: 0xffa89984,
    brightBlack: 0xff928374,
    brightRed: 0xfffb4934,
    brightGreen: 0xffb8bb26,
    brightYellow: 0xfffabd2f,
    brightBlue: 0xff83a598,
    brightMagenta: 0xffd3869b,
    brightCyan: 0xff8ec07c,
    brightWhite: 0xffebdbb2,
  ),
  'gruvbox-light': _theme(
    cursor: 0xff7c6f64,
    selection: 0xffebdbb2,
    foreground: 0xff3c3836,
    background: 0xfffbf1c7,
    black: 0xff1d2021,
    red: 0xffcc241d,
    green: 0xff98971a,
    yellow: 0xffd79921,
    blue: 0xff458588,
    magenta: 0xffb16286,
    cyan: 0xff689d6a,
    white: 0xffa89984,
    brightBlack: 0xff928374,
    brightRed: 0xff9d0006,
    brightGreen: 0xff79740e,
    brightYellow: 0xffb57614,
    brightBlue: 0xff076678,
    brightMagenta: 0xff8f3f71,
    brightCyan: 0xff427b58,
    brightWhite: 0xffebdbb2,
  ),
  'tokyo-night': _theme(
    cursor: 0xff7dcfff,
    selection: 0xff1a1b26,
    foreground: 0xffa9b1d6,
    background: 0xff1a1b26,
    black: 0xff15161e,
    red: 0xfff7768e,
    green: 0xff9ece6a,
    yellow: 0xffe0af68,
    blue: 0xff7aa2f7,
    magenta: 0xffbb9af7,
    cyan: 0xff7dcfff,
    white: 0xffa9b1d6,
    brightBlack: 0xff414868,
    brightRed: 0xfff7768e,
    brightGreen: 0xff9ece6a,
    brightYellow: 0xffe0af68,
    brightBlue: 0xff7aa2f7,
    brightMagenta: 0xffbb9af7,
    brightCyan: 0xff7dcfff,
    brightWhite: 0xffc0caf5,
  ),
  'night-owl': _theme(
    cursor: 0xff7e57c2,
    selection: 0xff011627,
    foreground: 0xffd6deeb,
    background: 0xff011627,
    black: 0xff011627,
    red: 0xffef5350,
    green: 0xff22da6e,
    yellow: 0xffaddb67,
    blue: 0xff82aaff,
    magenta: 0xffc792ea,
    cyan: 0xff21c7a8,
    white: 0xffffffff,
    brightBlack: 0xff575656,
    brightRed: 0xffff5874,
    brightGreen: 0xffc3e88d,
    brightYellow: 0xffffa759,
    brightBlue: 0xff82aaff,
    brightMagenta: 0xffc792ea,
    brightCyan: 0xff7fdbca,
    brightWhite: 0xffffffff,
  ),
};

final Map<String, TerminalTheme> _userTerminalThemes = {};
final Map<String, String> _userTerminalThemeLabels = {};
final Map<String, TerminalTheme> _assetTerminalThemes = {};
final Map<String, String> _assetTerminalThemeLabels = {};

Map<String, TerminalTheme> terminalThemeCatalog() {
  return {...terminalThemes, ..._assetTerminalThemes, ..._userTerminalThemes};
}

Map<String, String> terminalThemeLabelCatalog() {
  return {
    ...terminalThemeLabels,
    ..._assetTerminalThemeLabels,
    ..._userTerminalThemeLabels,
  };
}

Future<void> reloadUserTerminalThemes() async {
  await loadAssetTerminalThemes();
  _userTerminalThemes.clear();
  _userTerminalThemeLabels.clear();

  final themeDir = await _terminalThemeDirectory();
  await _ensureThemeTemplate(themeDir);
  if (!await themeDir.exists()) {
    return;
  }

  final entries = await themeDir.list(followLinks: false).toList();
  for (final entry in entries) {
    if (entry is! File || !entry.path.endsWith('.toml')) continue;
    final parsed = await _parseThemeFile(entry);
    if (parsed.isEmpty) continue;

    for (final item in parsed) {
      _userTerminalThemes[item.key] = item.theme;
      _userTerminalThemeLabels[item.key] = item.label;
    }
  }
}

Future<void> loadAssetTerminalThemes() async {
  if (_assetTerminalThemes.isNotEmpty) {
    return;
  }
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths =
        manifest
            .listAssets()
            .where(
              (key) =>
                  key.startsWith('assets/themes/terminal/') &&
                  key.endsWith('.toml'),
            )
            .toList()
          ..sort();
    if (assetPaths.isEmpty) {
      AppLogger().warn(
        'No bundled terminal themes found in asset manifest.',
        tag: 'TerminalTheme',
      );
      return;
    }
    for (final assetPath in assetPaths) {
      final basename = p.basenameWithoutExtension(assetPath);
      final content = await rootBundle.loadString(assetPath);
      List<_ParsedTerminalTheme> parsed;
      try {
        parsed = _parseThemeContent(content: content, basename: basename);
      } catch (error, stackTrace) {
        AppLogger().warn(
          'Failed to parse bundled theme ${p.basename(assetPath)}',
          tag: 'TerminalTheme',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
      for (final item in parsed) {
        _assetTerminalThemes[item.key] = item.theme;
        _assetTerminalThemeLabels[item.key] = item.label;
      }
    }
  } catch (error, stackTrace) {
    AppLogger().warn(
      'Failed to load bundled terminal themes',
      tag: 'TerminalTheme',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

const double _selectionOpacity = 0.40;

TerminalTheme _theme({
  required int cursor,
  required int selection,
  required int foreground,
  required int background,
  required int black,
  required int red,
  required int green,
  required int yellow,
  required int blue,
  required int magenta,
  required int cyan,
  required int white,
  required int brightBlack,
  required int brightRed,
  required int brightGreen,
  required int brightYellow,
  required int brightBlue,
  required int brightMagenta,
  required int brightCyan,
  required int brightWhite,
}) {
  Color c(int hex) => Color(hex);
  final selectionAlpha = _selectionOpacity.clamp(0.0, 1.0).toDouble();
  Color selectionColor(int hex) => Color(hex).withValues(alpha: selectionAlpha);
  return TerminalTheme(
    cursor: c(cursor),
    selection: selectionColor(selection),
    foreground: c(foreground),
    background: c(background),
    black: c(black),
    red: c(red),
    green: c(green),
    yellow: c(yellow),
    blue: c(blue),
    magenta: c(magenta),
    cyan: c(cyan),
    white: c(white),
    brightBlack: c(brightBlack),
    brightRed: c(brightRed),
    brightGreen: c(brightGreen),
    brightYellow: c(brightYellow),
    brightBlue: c(brightBlue),
    brightMagenta: c(brightMagenta),
    brightCyan: c(brightCyan),
    brightWhite: c(brightWhite),
    searchHitBackground: _searchHitBackground,
    searchHitBackgroundCurrent: _searchHitBackgroundCurrent,
    searchHitForeground: _searchHitForeground,
  );
}

TerminalTheme terminalThemeForKey(String key) {
  return terminalThemeCatalog()[key] ?? TerminalThemes.defaultTheme;
}

class _ParsedTerminalTheme {
  const _ParsedTerminalTheme({
    required this.key,
    required this.theme,
    required this.label,
  });

  final String key;
  final TerminalTheme theme;
  final String label;
}

Future<Directory> _themesDirectory(String category) async {
  final base = await const SettingsPathProvider().configDirectory();
  return Directory(p.join(base, 'themes', category));
}

Future<Directory> _terminalThemeDirectory() async {
  return _themesDirectory('terminal');
}

Future<void> _ensureThemeTemplate(Directory themeDir) async {
  if (!await themeDir.exists()) {
    await themeDir.create(recursive: true);
  }
  final templateFile = File(p.join(themeDir.path, 'example.toml'));
  if (await templateFile.exists()) {
    return;
  }
  await templateFile.writeAsString(_terminalThemeTemplate);
}

Future<void> _ensureEditorThemeTemplate(Directory themeDir) async {
  if (!await themeDir.exists()) {
    await themeDir.create(recursive: true);
  }
  final templateFile = File(p.join(themeDir.path, 'example.toml'));
  if (await templateFile.exists()) {
    return;
  }
  await templateFile.writeAsString(_buildEditorThemeTemplate());
}

Future<void> _ensureAppThemeTemplate(Directory themeDir) async {
  if (!await themeDir.exists()) {
    await themeDir.create(recursive: true);
  }
  final templateFile = File(p.join(themeDir.path, 'example.toml'));
  if (await templateFile.exists()) {
    return;
  }
  await templateFile.writeAsString(_buildAppThemeTemplate());
}

Future<void> ensureThemeExamples() async {
  await _ensureThemeTemplate(await _themesDirectory('terminal'));
  await _ensureEditorThemeTemplate(await _themesDirectory('editor'));
  await _ensureAppThemeTemplate(await _themesDirectory('app'));
}

Future<List<_ParsedTerminalTheme>> _parseThemeFile(File file) async {
  try {
    final basename = p.basenameWithoutExtension(file.path);
    final content = await file.readAsString();
    return _parseThemeContent(content: content, basename: basename);
  } catch (error, stackTrace) {
    AppLogger().warn(
      'Failed to load theme ${p.basename(file.path)}',
      tag: 'TerminalTheme',
      error: error,
      stackTrace: stackTrace,
    );
    return [];
  }
}

List<_ParsedTerminalTheme> _parseThemeContent({
  required String content,
  required String basename,
}) {
  final doc = TomlDocument.parse(content);
  final data = doc.toMap();
  final entries = _resolveThemeEntries(data);
  final parsed = <_ParsedTerminalTheme>[];

  for (final entry in entries) {
    final key = entry.key == null ? basename : '$basename-${entry.key}';
    final label = entry.label ?? _titleCase(entry.key ?? basename);
    final colorTable = _resolveColorTable(entry.data);
    final missing = _terminalThemeRequiredKeys
        .where((key) => !colorTable.containsKey(key))
        .toList();
    if (missing.isNotEmpty) {
      AppLogger().warn(
        'Theme $basename${entry.keySuffix} missing keys: '
        '${missing.join(', ')}',
        tag: 'TerminalTheme',
      );
      continue;
    }

    Color? readColor(String key) => _parseColor(colorTable[key]);
    final parsedColors = <String, Color?>{
      'cursor': readColor('cursor'),
      'selection': readColor('selection'),
      'foreground': readColor('foreground'),
      'background': readColor('background'),
      'black': readColor('black'),
      'red': readColor('red'),
      'green': readColor('green'),
      'yellow': readColor('yellow'),
      'blue': readColor('blue'),
      'magenta': readColor('magenta'),
      'cyan': readColor('cyan'),
      'white': readColor('white'),
      'bright_black': readColor('bright_black'),
      'bright_red': readColor('bright_red'),
      'bright_green': readColor('bright_green'),
      'bright_yellow': readColor('bright_yellow'),
      'bright_blue': readColor('bright_blue'),
      'bright_magenta': readColor('bright_magenta'),
      'bright_cyan': readColor('bright_cyan'),
      'bright_white': readColor('bright_white'),
      'search_hit_background': readColor('search_hit_background'),
      'search_hit_background_current': readColor(
        'search_hit_background_current',
      ),
      'search_hit_foreground': readColor('search_hit_foreground'),
    };

    final invalid = parsedColors.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList();
    if (invalid.isNotEmpty) {
      AppLogger().warn(
        'Theme $basename${entry.keySuffix} has invalid colors: '
        '${invalid.join(', ')}',
        tag: 'TerminalTheme',
      );
      continue;
    }

    final theme = TerminalTheme(
      cursor: parsedColors['cursor']!,
      selection: parsedColors['selection']!,
      foreground: parsedColors['foreground']!,
      background: parsedColors['background']!,
      black: parsedColors['black']!,
      red: parsedColors['red']!,
      green: parsedColors['green']!,
      yellow: parsedColors['yellow']!,
      blue: parsedColors['blue']!,
      magenta: parsedColors['magenta']!,
      cyan: parsedColors['cyan']!,
      white: parsedColors['white']!,
      brightBlack: parsedColors['bright_black']!,
      brightRed: parsedColors['bright_red']!,
      brightGreen: parsedColors['bright_green']!,
      brightYellow: parsedColors['bright_yellow']!,
      brightBlue: parsedColors['bright_blue']!,
      brightMagenta: parsedColors['bright_magenta']!,
      brightCyan: parsedColors['bright_cyan']!,
      brightWhite: parsedColors['bright_white']!,
      searchHitBackground: parsedColors['search_hit_background']!,
      searchHitBackgroundCurrent:
          parsedColors['search_hit_background_current']!,
      searchHitForeground: parsedColors['search_hit_foreground']!,
    );

    parsed.add(_ParsedTerminalTheme(key: key, theme: theme, label: label));
  }

  return parsed;
}

class _ThemeEntry {
  const _ThemeEntry({required this.data, this.key, this.label});

  final Map<String, Object?> data;
  final String? key;
  final String? label;

  String get keySuffix => key == null ? '' : '[$key]';
}

List<_ThemeEntry> _resolveThemeEntries(Map<String, Object?> data) {
  if (data.containsKey('colors')) {
    return [_ThemeEntry(data: data)];
  }

  final entries = <_ThemeEntry>[];
  for (final entry in data.entries) {
    if (entry.value is! Map) continue;
    final section = Map<String, Object?>.from(entry.value as Map);
    if (!section.containsKey('colors')) continue;
    entries.add(
      _ThemeEntry(
        data: section,
        key: entry.key.toString(),
        label: section['name'] is String ? section['name'] as String : null,
      ),
    );
  }
  return entries;
}

Map<String, Object?> _resolveColorTable(Map<String, Object?> data) {
  final colors = data['colors'];
  if (colors is Map) {
    return Map<String, Object?>.from(colors);
  }
  final normalized = Map<String, Object?>.from(data);
  normalized.remove('name');
  normalized.remove('label');
  return normalized;
}

Color? _parseColor(Object? value) {
  if (value is String) {
    var hex = value.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    if (hex.length != 8) {
      return null;
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
  return null;
}

String _titleCase(String value) {
  final parts = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList();
  return parts
      .map((part) => part.substring(0, 1).toUpperCase() + part.substring(1))
      .join(' ');
}

const Set<String> _terminalThemeRequiredKeys = {
  'cursor',
  'selection',
  'foreground',
  'background',
  'black',
  'red',
  'green',
  'yellow',
  'blue',
  'magenta',
  'cyan',
  'white',
  'bright_black',
  'bright_red',
  'bright_green',
  'bright_yellow',
  'bright_blue',
  'bright_magenta',
  'bright_cyan',
  'bright_white',
  'search_hit_background',
  'search_hit_background_current',
  'search_hit_foreground',
};

const List<String> _appAccentKeys = [
  'blue-grey',
  'teal',
  'amber',
  'indigo',
  'purple',
  'green',
];

String _buildEditorThemeTemplate() {
  final keys = editorThemeOptions().keys.toList()..sort();
  final buffer = StringBuffer();
  buffer.writeln('# Example editor theme for CWatch.');
  buffer.writeln(
    '# Save files in ~/.config/cwatch/themes/editor and use .toml extension.',
  );
  buffer.writeln('# The theme key must match a built-in editor theme key.');
  buffer.writeln('# Available keys:');
  for (final key in keys) {
    buffer.writeln('# - $key');
  }
  buffer.writeln('');
  buffer.writeln('theme_key = "dracula"');
  return buffer.toString();
}

String _buildAppThemeTemplate() {
  final buffer = StringBuffer();
  buffer.writeln('# Example app theme overrides for CWatch.');
  buffer.writeln(
    '# Save files in ~/.config/cwatch/themes/app and use .toml extension.',
  );
  buffer.writeln('# theme_mode options: system, light, dark');
  buffer.writeln('# app_accent options: ${_appAccentKeys.join(', ')}');
  buffer.writeln('');
  buffer.writeln('theme_mode = "system"');
  buffer.writeln('app_accent = "blue-grey"');
  buffer.writeln('# app_font_family = "JetBrainsMono Nerd Font"');
  return buffer.toString();
}

const String _terminalThemeTemplate = '''# Example terminal theme for CWatch.
# Save files in ~/.config/cwatch/themes/terminal and use .toml extension.
# The theme key is the filename without extension.
# Colors accept #RRGGBB or #AARRGGBB.

name = "Example Theme"

[colors]
cursor = "#ffcc00"
selection = "#334155"
foreground = "#e2e8f0"
background = "#0f172a"
black = "#0f172a"
red = "#ef4444"
green = "#22c55e"
yellow = "#eab308"
blue = "#38bdf8"
magenta = "#a855f7"
cyan = "#06b6d4"
white = "#e2e8f0"
bright_black = "#334155"
bright_red = "#f87171"
bright_green = "#4ade80"
bright_yellow = "#facc15"
bright_blue = "#7dd3fc"
bright_magenta = "#c084fc"
bright_cyan = "#22d3ee"
bright_white = "#f8fafc"
search_hit_background = "#f6d32d"
search_hit_background_current = "#ff8c00"
search_hit_foreground = "#000000"
''';
