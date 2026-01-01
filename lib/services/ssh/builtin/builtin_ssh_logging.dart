import '../../logging/app_logger.dart';

void logBuiltInSsh(String message) {
  AppLogger().debug(message, tag: 'BuiltInSSH');
}

void logBuiltInSshWarning(
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  AppLogger().warn(
    message,
    tag: 'BuiltInSSH',
    error: error,
    stackTrace: stackTrace,
  );
}
