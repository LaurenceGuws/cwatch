import 'package:cwatch/model/models/editor_preferences.dart';
import 'package:cwatch/model/models/explorer_preferences.dart';
import 'package:cwatch/model/models/shell_preferences.dart';
import 'package:cwatch/model/models/terminal_preferences.dart';

/// Canonical first-pass input surface for config metadata generation.
///
/// This stays deliberately narrow so the first annotation/codegen slice only
/// covers primitive grouped preference models.
const configMetadataTargetTypes = <Type>[
  ShellPreferences,
  EditorPreferences,
  TerminalPreferences,
  ExplorerPreferences,
];
