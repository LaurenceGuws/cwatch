import 'dart:io';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

typedef ConnectivityConnector =
    Future<void> Function(
      String host,
      int port, {
      required Duration timeout,
    });

class ConnectivityProbe {
  const ConnectivityProbe({this.source = 'connectivity'})
    : _connect = _defaultConnect;

  ConnectivityProbe.testing({
    this.source = 'connectivity',
    required ConnectivityConnector connect,
  }) : _connect = connect;

  final String source;
  final ConnectivityConnector _connect;

  static final Map<String, Future<bool>> _inFlightByTarget =
      <String, Future<bool>>{};
  static final Map<String, _LoggedProbeFailure> _recentFailuresByTarget =
      <String, _LoggedProbeFailure>{};
  static const Duration _failureLogCooldown = Duration(seconds: 30);

  Future<bool> canConnect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 2),
    SshHost? hostContext,
    String? hostLabel,
  }) async {
    final targetKey = '$host:$port';
    final existing = _inFlightByTarget[targetKey];
    if (existing != null) {
      return existing;
    }

    final future = _runConnect(
      host: host,
      port: port,
      timeout: timeout,
      hostContext: hostContext,
      hostLabel: hostLabel,
      targetKey: targetKey,
    );
    _inFlightByTarget[targetKey] = future;
    future.whenComplete(() {
      if (identical(_inFlightByTarget[targetKey], future)) {
        _inFlightByTarget.remove(targetKey);
      }
    });
    return future;
  }

  Future<bool> _runConnect({
    required String host,
    required int port,
    required Duration timeout,
    required String targetKey,
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
      await _connect(host, port, timeout: timeout);
      stopwatch.stop();
      _recentFailuresByTarget.remove(targetKey);
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
      final signature = _failureSignature(error);
      if (_shouldLogFailure(targetKey, signature)) {
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
      }
      return false;
    }
  }

  static Future<void> _defaultConnect(
    String host,
    int port, {
    required Duration timeout,
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
  }

  bool _isTimeoutError(Object error) {
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      final osMessage = error.osError?.message.toLowerCase() ?? '';
      return message.contains('timed out') || osMessage.contains('timed out');
    }
    return false;
  }

  bool _shouldLogFailure(String targetKey, String signature) {
    final now = DateTime.now();
    final previous = _recentFailuresByTarget[targetKey];
    if (previous != null &&
        previous.signature == signature &&
        now.difference(previous.loggedAt) < _failureLogCooldown) {
      return false;
    }
    _recentFailuresByTarget[targetKey] = _LoggedProbeFailure(
      signature: signature,
      loggedAt: now,
    );
    return true;
  }

  String _failureSignature(Object error) {
    if (error is SocketException) {
      final osMessage = error.osError?.message ?? '';
      return 'socket:${error.message}|$osMessage|${error.port}';
    }
    return '${error.runtimeType}:$error';
  }

  static void resetDebugStateForTests() {
    _inFlightByTarget.clear();
    _recentFailuresByTarget.clear();
  }
}

class _LoggedProbeFailure {
  const _LoggedProbeFailure({
    required this.signature,
    required this.loggedAt,
  });

  final String signature;
  final DateTime loggedAt;
}
