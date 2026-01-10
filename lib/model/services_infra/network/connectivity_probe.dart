import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

class ConnectivityProbe {
  const ConnectivityProbe({this.source = 'connectivity'});

  final String source;

  Future<bool> canConnect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 2),
    SshHost? hostContext,
    String? hostLabel,
  }) async {
    final targetLabel = hostLabel?.trim().isNotEmpty == true
        ? hostLabel!
        : host;
    final logger = hostContext != null
        ? AppLogger.remote(
            tag: 'Connectivity',
            source: source,
            host: hostContext,
          )
        : AppLogger(tag: 'Connectivity');
    // Always create RemoteCommandDetails for debug view, even without hostContext
    final remoteDetails = RemoteCommandDetails(
      operation: 'Connectivity probe',
      command: 'tcp connect $host:$port',
      output: '',
      contextLabel: hostContext != null ? targetLabel : '$targetLabel (local)',
    );
    final stopwatch = Stopwatch()..start();
    logger.debug(
      'Probing $targetLabel:$port (timeout=${timeout.inMilliseconds}ms)',
      remote: remoteDetails,
    );
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      stopwatch.stop();
      logger.debug(
        'Probe ok for $targetLabel:$port in ${stopwatch.elapsedMilliseconds}ms',
        remote: RemoteCommandDetails(
          operation: remoteDetails.operation,
          command: remoteDetails.command,
          output: 'ok in ${stopwatch.elapsedMilliseconds}ms',
          contextLabel: remoteDetails.contextLabel,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      stopwatch.stop();
      final showStackTrace = !_isTimeoutError(error);
      logger.warn(
        'Probe failed for $targetLabel:$port after ${stopwatch.elapsedMilliseconds}ms',
        error: error,
        stackTrace: showStackTrace ? stackTrace : null,
        remote: RemoteCommandDetails(
          operation: remoteDetails.operation,
          command: remoteDetails.command,
          output: error.toString(),
          contextLabel: remoteDetails.contextLabel,
        ),
      );
      return false;
    }
  }

  bool _isTimeoutError(Object error) {
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      final osMessage = error.osError?.message.toLowerCase() ?? '';
      return message.contains('timed out') || osMessage.contains('timed out');
    }
    return false;
  }
}
