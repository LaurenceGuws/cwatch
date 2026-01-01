import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../models/ssh_host.dart';

enum LogLevel { trace, debug, info, warning, error, critical }

/// Lightweight logger to control console output across app.
/// Defaults to Debug level in debug builds and Warning in release.
class AppLogger {
  AppLogger({this.tag})
      : remoteService = false,
        source = null,
        host = null;

  AppLogger.remote({
    this.tag,
    required String source,
    this.host,
  }) : remoteService = true,
       source = source {
    assert(source.isNotEmpty, 'Remote logger requires a non-empty source.');
  }

  final String? tag;
  final bool remoteService;
  final String? source;
  final SshHost? host;

  static final LogLevel _defaultLevel = kDebugMode
      ? LogLevel.debug
      : LogLevel.warning;
  static LogLevel _minLevel = _defaultLevel;

  static void configure({LogLevel? minLevel}) {
    if (minLevel != null) {
      _minLevel = minLevel;
    }
  }

  void trace(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.trace,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.debug,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.info,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  void warn(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.warning,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.error,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  void critical(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) => _log(
    LogLevel.critical,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
    remote: remote,
  );

  static final RemoteCommandLogController remoteCommandLog =
      RemoteCommandLogController();

  static bool _remoteCommandLoggingEnabled = false;

  static bool get remoteCommandLoggingEnabled =>
      _remoteCommandLoggingEnabled;

  static void configureRemoteCommandLogging({required bool enabled}) {
    _remoteCommandLoggingEnabled = enabled;
  }

  static RemoteCommandObserver get remoteCommandObserver =>
      _addRemoteCommand;

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) {
    if (level.index < _minLevel.index) {
      return;
    }
    final buffer = StringBuffer();
    final now = _formatNow();
    final color = _colorFor(level);
    final reset = '\x1B[0m';
    buffer.write('$color$now ');
    final label = tag ?? this.tag;
    if (label != null && label.isNotEmpty) {
      buffer.write('[$label] ');
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
    _logRemoteIfNeeded(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
      remote: remote,
    );
  }

  String _formatNow() {
    final now = DateTime.now().toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
  }

  String _colorFor(LogLevel level) {
    switch (level) {
      case LogLevel.trace:
        return '\x1B[90m'; // gray
      case LogLevel.debug:
        return '\x1B[34m'; // blue
      case LogLevel.info:
        return '\x1B[32m'; // green
      case LogLevel.warning:
        return '\x1B[33m'; // yellow
      case LogLevel.error:
        return '\x1B[31m'; // red
      case LogLevel.critical:
        return '\x1B[35m'; // magenta
    }
  }

  void _logRemoteIfNeeded(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    RemoteCommandDetails? remote,
  }) {
    if (!remoteService || !_remoteCommandLoggingEnabled) {
      return;
    }
    if (remote == null) {
      assert(false, 'Remote logger requires RemoteCommandDetails.');
      return;
    }
    if (remote.operation.isEmpty ||
        remote.command.isEmpty ||
        remote.contextLabel.isEmpty) {
      assert(
        false,
        'Remote logger requires non-empty operation, command, and context.',
      );
      return;
    }
    final resolvedSource = source ?? tag ?? 'app';
    final output =
        remote.output.isNotEmpty ? remote.output : (error?.toString() ?? '');
    _addRemoteCommand(
      RemoteCommandDebugEvent(
        level: level,
        source: resolvedSource,
        host: host,
        operation: remote.operation,
        command: remote.command,
        output: output,
        contextLabel: remote.contextLabel,
        verificationCommand: remote.verificationCommand,
        verificationOutput: remote.verificationOutput,
        verificationPassed: remote.verificationPassed,
      ),
    );
    if (error != null && stackTrace != null) {
      _addRemoteCommand(
        RemoteCommandDebugEvent(
          level: level,
          source: resolvedSource,
          host: host,
          operation: 'Stack trace',
          command: '',
          output: stackTrace.toString(),
          contextLabel: remote.contextLabel,
        ),
      );
    }
  }
}

typedef RemoteCommandObserver = void Function(RemoteCommandDebugEvent event);

class RemoteCommandDetails {
  const RemoteCommandDetails({
    required this.operation,
    required this.command,
    required this.output,
    required this.contextLabel,
    this.verificationCommand,
    this.verificationOutput,
    this.verificationPassed,
  });

  final String operation;
  final String command;
  final String output;
  final String contextLabel;
  final String? verificationCommand;
  final String? verificationOutput;
  final bool? verificationPassed;
}

class RemoteCommandDebugEvent {
  RemoteCommandDebugEvent({
    this.level = LogLevel.debug,
    required this.source,
    required this.host,
    required this.operation,
    required this.command,
    required this.output,
    required this.contextLabel,
    DateTime? timestamp,
    this.verificationCommand,
    this.verificationOutput,
    this.verificationPassed,
  }) : timestamp = timestamp ?? DateTime.now();

  final LogLevel level;
  final String source;
  final SshHost? host;
  final String operation;
  final String command;
  final String output;
  final String contextLabel;
  final DateTime timestamp;
  final String? verificationCommand;
  final String? verificationOutput;
  final bool? verificationPassed;
}

class RemoteCommandLogController extends ChangeNotifier {
  RemoteCommandLogController({this.maxEntries = 200});

  final int maxEntries;
  final List<RemoteCommandDebugEvent> _events = [];

  UnmodifiableListView<RemoteCommandDebugEvent> get events =>
      UnmodifiableListView(_events);

  bool get isEmpty => _events.isEmpty;

  void add(RemoteCommandDebugEvent event) {
    _events.insert(0, event);
    if (_events.length > maxEntries) {
      _events.removeRange(maxEntries, _events.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_events.isEmpty) {
      return;
    }
    _events.clear();
    notifyListeners();
  }
}

void _addRemoteCommand(RemoteCommandDebugEvent event) {
  if (!AppLogger._remoteCommandLoggingEnabled) {
    return;
  }
  AppLogger.remoteCommandLog.add(event);
}
