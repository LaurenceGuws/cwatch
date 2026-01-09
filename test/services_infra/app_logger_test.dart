import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/ssh_host.dart';
import 'package:cwatch/model/services_infra/logging/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('default logger has no tag', () {
      final logger = AppLogger();
      expect(logger.tag, isNull);
      expect(logger.remoteService, isFalse);
      expect(logger.source, isNull);
      expect(logger.host, isNull);
    });

    test('logger with tag', () {
      final logger = AppLogger(tag: 'TestTag');
      expect(logger.tag, 'TestTag');
      expect(logger.remoteService, isFalse);
    });

    test('remote logger requires non-empty source', () {
      expect(
        () => AppLogger.remote(tag: 'Test', source: ''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('remote logger has source and host', () {
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      final logger = AppLogger.remote(
        tag: 'SSH',
        source: 'ssh',
        host: host,
      );

      expect(logger.tag, 'SSH');
      expect(logger.remoteService, isTrue);
      expect(logger.source, 'ssh');
      expect(logger.host, host);
    });

    test('configure sets minimum log level', () {
      AppLogger.configure(minLevel: LogLevel.info);
      // Note: We can't directly test the level without exposing it,
      // but we can verify the method doesn't throw
      expect(() => AppLogger.configure(minLevel: LogLevel.warning), returnsNormally);
    });

    test('log methods do not throw', () {
      final logger = AppLogger(tag: 'Test');
      expect(() => logger.trace('test message'), returnsNormally);
      expect(() => logger.debug('test message'), returnsNormally);
      expect(() => logger.info('test message'), returnsNormally);
      expect(() => logger.warn('test message'), returnsNormally);
      expect(() => logger.error('test message'), returnsNormally);
      expect(() => logger.critical('test message'), returnsNormally);
    });

    test('log methods accept error and stackTrace', () {
      final logger = AppLogger(tag: 'Test');
      final error = Exception('test error');
      final stackTrace = StackTrace.current;

      expect(
        () => logger.error(
          'test message',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('remote logger can log with remote details', () {
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      final logger = AppLogger.remote(tag: 'SSH', source: 'ssh', host: host);
      final details = RemoteCommandDetails(
        operation: 'test',
        command: 'ls -la',
        output: 'output',
        contextLabel: 'test',
      );

      // Enable remote command logging for this test
      AppLogger.configureRemoteCommandLogging(enabled: true);
      expect(
        () => logger.debug('test', remote: details),
        returnsNormally,
      );
    });
  });

  group('RemoteCommandDebugEvent', () {
    test('creates event with default level', () {
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      final event = RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'test',
        command: 'ls',
        output: 'output',
        contextLabel: 'test',
      );

      expect(event.operation, 'test');
      expect(event.command, 'ls');
      expect(event.output, 'output');
      expect(event.level, LogLevel.debug);
      expect(event.source, 'test');
      expect(event.host, host);
    });

    test('creates event with custom level', () {
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      final event = RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'test',
        command: 'ls',
        output: 'output',
        contextLabel: 'test',
        level: LogLevel.error,
      );

      expect(event.level, LogLevel.error);
    });
  });

  group('RemoteCommandLogController', () {
    test('starts empty', () {
      final controller = RemoteCommandLogController();
      expect(controller.events, isEmpty);
      expect(controller.isEmpty, isTrue);
    });

    test('adds events', () {
      final controller = RemoteCommandLogController();
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      final event1 = RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'op1',
        command: 'cmd1',
        output: 'out1',
        contextLabel: 'test',
      );
      final event2 = RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'op2',
        command: 'cmd2',
        output: 'out2',
        contextLabel: 'test',
      );

      controller.add(event1);
      controller.add(event2);

      expect(controller.events.length, 2);
      expect(controller.isEmpty, isFalse);
      expect(controller.events[0], event2); // Newest first
      expect(controller.events[1], event1);
    });

    test('clear removes all events', () {
      final controller = RemoteCommandLogController();
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );
      controller.add(RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'test',
        command: 'cmd',
        output: 'out',
        contextLabel: 'test',
      ));

      controller.clear();

      expect(controller.events, isEmpty);
      expect(controller.isEmpty, isTrue);
    });

    test('respects maxEntries limit', () {
      final controller = RemoteCommandLogController(maxEntries: 2);
      final host = SshHost(
        name: 'test-host',
        hostname: 'example.com',
        port: 22,
        available: true,
      );

      controller.add(RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'op1',
        command: 'cmd1',
        output: 'out1',
        contextLabel: 'test',
      ));
      controller.add(RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'op2',
        command: 'cmd2',
        output: 'out2',
        contextLabel: 'test',
      ));
      controller.add(RemoteCommandDebugEvent(
        source: 'test',
        host: host,
        operation: 'op3',
        command: 'cmd3',
        output: 'out3',
        contextLabel: 'test',
      ));

      expect(controller.events.length, 2);
      expect(controller.events[0].operation, 'op3');
      expect(controller.events[1].operation, 'op2');
    });
  });
}
