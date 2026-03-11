import 'dart:async';

import 'package:cwatch/model/models/ssh_host.dart';

import '../remote_shell_base.dart';

typedef BuiltInSshTimeoutKill = void Function();

class BuiltInSshTimeoutRunner {
  const BuiltInSshTimeoutRunner();

  Future<T> run<T>({
    required Future<T> future,
    required Duration timeout,
    required SshHost host,
    required String commandDescription,
    RunTimeoutHandler? onTimeout,
    required BuiltInSshTimeoutKill onKill,
  }) async {
    var nextTimeout = timeout;
    final stopwatch = Stopwatch()..start();
    while (true) {
      try {
        return await future.timeout(nextTimeout);
      } on TimeoutException {
        final resolution = onTimeout != null
            ? await onTimeout(
                TimeoutContext(
                  host: host,
                  commandDescription: commandDescription,
                  elapsed: stopwatch.elapsed,
                ),
              )
            : const TimeoutResolution.kill();
        if (resolution.shouldKill) {
          onKill();
          throw TimeoutException(
            'SSH command timed out after ${stopwatch.elapsed.inSeconds}s',
            stopwatch.elapsed,
          );
        }
        nextTimeout = resolution.extendBy ?? timeout;
      }
    }
  }
}
