import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Lightweight logger to control console output across app.
/// Defaults to Debug level in debug builds and Warning in release.
class AppLogger {
  AppLogger._(this.minLevel);

  static final LogLevel _defaultLevel = kDebugMode
      ? LogLevel.debug
      : LogLevel.warning;
  static AppLogger _instance = AppLogger._(_defaultLevel);

  final LogLevel minLevel;

  static void configure({LogLevel? minLevel}) {
    if (minLevel != null) {
      _instance = AppLogger._(minLevel);
    }
  }

  static void d(String message, {String? tag}) =>
      _instance.log(LogLevel.debug, message, tag: tag);
  static void i(String message, {String? tag}) =>
      _instance.log(LogLevel.info, message, tag: tag);
  static void w(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => _instance.log(
    LogLevel.warning,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );
  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) => _instance.log(
    LogLevel.error,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );

  void log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) {
      return;
    }
    final buffer = StringBuffer();
    final now = _formatNow();
    final color = _colorFor(level);
    final reset = '\x1B[0m';
    buffer.write('$color$now [cwatch] ');
    if (tag != null && tag.isNotEmpty) {
      buffer.write('[$tag] ');
    }
    buffer.write(message);
    if (error != null && level != LogLevel.error) {
      buffer.write(' error: $error');
    }
    buffer.write(reset);
    debugPrint(buffer.toString());
    if (error != null && stackTrace != null) {
      debugPrint('$color$stackTrace$reset');
    }
  }

  String _formatNow() {
    final now = DateTime.now().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }

  String _colorFor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '\x1B[34m'; // blue
      case LogLevel.info:
        return '\x1B[32m'; // green
      case LogLevel.warning:
        return '\x1B[33m'; // yellow
      case LogLevel.error:
        return '\x1B[31m'; // red
    }
  }
}
