import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../services/logging/app_logger.dart';

/// Service for launching external applications and editors
class ExternalAppLauncher {
  ExternalAppLauncher._();

  /// Launch a local application with the given path
  static Future<void> launch(String path) async {
    final preferred = await _resolveEditorCommand();
    if (preferred != null) {
      AppLogger.d('Launching preferred editor command: $preferred $path', tag: 'ExternalApp');
      await Process.start(preferred.first, [...preferred.sublist(1), path]);
      return;
    }

    if (Platform.isMacOS) {
      AppLogger.d('Launching open $path', tag: 'ExternalApp');
      await Process.start('open', [path]);
    } else if (Platform.isWindows) {
      AppLogger.d('Launching cmd /c start $path', tag: 'ExternalApp');
      await Process.start('cmd', ['/c', 'start', '', path]);
    } else {
      AppLogger.d('Launching xdg-open $path', tag: 'ExternalApp');
      await Process.start('xdg-open', [path]);
    }
  }

  /// Open a config file in an external editor
  static Future<void> openConfigFile(String sourcePath, BuildContext context) async {
    try {
      final editor = Platform.environment['EDITOR']?.trim();
      if (editor != null && editor.isNotEmpty) {
        final parts = editor
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          // Try to find the executable
          String? executable;
          if (parts.first.contains('/') || parts.first.contains('\\')) {
            // Absolute or relative path
            executable = parts.first;
          } else {
            // Command name - try to find it
            final whichCmd = Platform.isWindows ? 'where' : 'which';
            final result = await Process.run(whichCmd, [parts.first]);
            if (result.exitCode == 0) {
              executable = result.stdout.toString().trim().split('\n').first;
            }
          }
          if (executable != null) {
            await Process.start(
              executable,
              [...parts.sublist(1), sourcePath],
            );
            return;
          }
        }
      }

      // Fallback to platform-specific defaults
      if (Platform.isMacOS) {
        await Process.start('open', ['-t', sourcePath]);
      } else if (Platform.isWindows) {
        await Process.start('notepad', [sourcePath]);
      } else {
        // Linux/Unix - try common editors
        final editors = ['nano', 'vim', 'vi', 'gedit', 'kate'];
        for (final editor in editors) {
          try {
            final whichCmd = 'which';
            final result = await Process.run(whichCmd, [editor]);
            if (result.exitCode == 0) {
              final editorPath = result.stdout.toString().trim().split('\n').first;
              await Process.start(editorPath, [sourcePath]);
              return;
            }
          } catch (_) {
            continue;
          }
        }
        // Last resort: xdg-open
        await Process.start('xdg-open', [sourcePath]);
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open editor: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<List<String>?> _resolveEditorCommand() async {
    final editor = Platform.environment['EDITOR']?.trim();
    if (editor == null || editor.isEmpty) {
      return null;
    }
    final parts = editor
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    final executable = await _findExecutable(parts.first);
    if (executable == null) {
      AppLogger.d('EDITOR command not found: ${parts.first}', tag: 'ExternalApp');
      return null;
    }
    return [executable, ...parts.sublist(1)];
  }

  static Future<String?> _findExecutable(String command) async {
    final exists = await File(command).exists();
    if (exists) {
      return command;
    }
    final whichCmd = Platform.isWindows ? 'where' : 'which';
    final result = await Process.run(whichCmd, [command]);
    if (result.exitCode != 0) {
      AppLogger.w('$whichCmd $command failed', tag: 'ExternalApp', error: result.stderr);
      return null;
    }
    final output = (result.stdout as String?) ?? '';
    return output
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => command);
  }
}
