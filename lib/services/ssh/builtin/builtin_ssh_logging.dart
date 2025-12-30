import '../../logging/app_logger.dart';

void logBuiltInSsh(String message) {
  AppLogger.d(message, tag: 'BuiltInSSH');
}

void logBuiltInSshWarning(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  AppLogger.w(
    message,
    tag: 'BuiltInSSH',
    error: error,
    stackTrace: stackTrace,
  );
}
