import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/services_infra/network/connectivity_probe.dart';

void main() {
  group('ConnectivityProbe', () {
    late DebugPrintCallback originalDebugPrint;
    late List<String> logLines;

    setUp(() {
      ConnectivityProbe.resetDebugStateForTests();
      originalDebugPrint = debugPrint;
      logLines = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logLines.add(message);
        }
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
      ConnectivityProbe.resetDebugStateForTests();
    });

    test('reuses the same in-flight probe for concurrent callers', () async {
      final completer = Completer<void>();
      var connectCalls = 0;
      final probe = ConnectivityProbe.testing(
        connect: (host, port, {required timeout}) {
          connectCalls += 1;
          return completer.future;
        },
      );

      final first = probe.canConnect(host: 'alpha.example.com', port: 22);
      final second = probe.canConnect(host: 'alpha.example.com', port: 22);

      expect(connectCalls, 1);

      completer.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(
        logLines.where((line) => line.contains('Probing alpha.example.com:22')),
        hasLength(1),
      );
    });

    test('suppresses repeated identical failure warnings during cooldown', () async {
      final probe = ConnectivityProbe.testing(
        connect: (host, port, {required timeout}) {
          throw const SocketException(
            'Connection timed out',
            osError: OSError('Connection timed out', 110),
          );
        },
      );

      expect(await probe.canConnect(host: 'alpha', port: 22), isFalse);
      expect(await probe.canConnect(host: 'alpha', port: 22), isFalse);

      expect(
        logLines.where((line) => line.contains('Probe failed for alpha:22')),
        hasLength(1),
      );
    });
  });
}
