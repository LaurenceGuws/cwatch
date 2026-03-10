import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/features/docker/services/docker_cli_executor.dart';
import 'package:cwatch/model/features/docker/services/docker_cli_failure.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';

void main() {
  group('DockerClientService', () {
    test('listContexts parses json lines and skips malformed entries', () async {
      final service = DockerClientService(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) async {
          expect(executable, 'docker');
          expect(arguments, ['context', 'ls', '--format', '{{json .}}']);
          return ProcessResult(
            1,
            0,
            [
              jsonEncode({
                'Name': 'default',
                'DockerEndpoint': 'unix:///var/run/docker.sock',
                'Description': 'Local engine',
                'Current': '*',
              }),
              'not-json',
              jsonEncode({
                'Name': 'remote',
                'DockerEndpoint': 'ssh://docker@example',
                'Current': false,
                'Orchestrator': 'swarm',
              }),
            ].join('\n'),
            '',
          );
        },
      );

      final contexts = await service.listContexts();

      expect(contexts, hasLength(2));
      expect(contexts[0].name, 'default');
      expect(contexts[0].dockerEndpoint, 'unix:///var/run/docker.sock');
      expect(contexts[0].description, 'Local engine');
      expect(contexts[0].current, isTrue);
      expect(contexts[1].name, 'remote');
      expect(contexts[1].current, isFalse);
      expect(contexts[1].orchestrator, 'swarm');
    });

    test('listContainers parses labels, startedAt, and context arguments', () async {
      final service = DockerClientService(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) async {
          expect(executable, 'docker');
          expect(arguments, [
            '--context',
            'remote-prod',
            'ps',
            '-a',
            '--format',
            '{{json .}}',
          ]);
          return ProcessResult(
            1,
            0,
            [
              jsonEncode({
                'ID': 'abc123',
                'Names': 'web',
                'Image': 'nginx:latest',
                'State': 'running',
                'Status': 'Up 2 minutes',
                'Ports': '80/tcp',
                'Command': 'nginx -g daemon off;',
                'RunningFor': '2 minutes ago',
                'Labels':
                    'com.docker.compose.project=shop,com.docker.compose.service=web',
                'StartedAt': '2026-03-10T10:11:12Z',
              }),
              'broken-line',
            ].join('\n'),
            '',
          );
        },
      );

      final containers = await service.listContainers(context: 'remote-prod');

      expect(containers, hasLength(1));
      expect(containers.single.id, 'abc123');
      expect(containers.single.name, 'web');
      expect(containers.single.image, 'nginx:latest');
      expect(containers.single.composeProject, 'shop');
      expect(containers.single.composeService, 'web');
      expect(containers.single.startedAt, DateTime.parse('2026-03-10T10:11:12Z'));
      expect(containers.single.isRunning, isTrue);
    });

    test('listContainers uses dockerHost when context is absent', () async {
      final service = DockerClientService(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) async {
          expect(arguments, [
            '--host',
            'tcp://docker-host:2375',
            'ps',
            '-a',
            '--format',
            '{{json .}}',
          ]);
          return ProcessResult(1, 0, '', '');
        },
      );

      final containers = await service.listContainers(
        dockerHost: 'tcp://docker-host:2375',
      );

      expect(containers, isEmpty);
    });

    test('listContexts surfaces missing docker cli as capability unavailable', () async {
      final service = DockerClientService(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) {
          throw const ProcessException('docker', ['context', 'ls'], 'not found', 127);
        },
      );

      await expectLater(
        service.listContexts(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Docker CLI not available'),
          ),
        ),
      );
    });

    test('listContainers surfaces missing docker cli as capability unavailable', () async {
      final service = DockerClientService(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) {
          throw const ProcessException('docker', ['ps'], 'not found', 127);
        },
      );

      await expectLater(
        service.listContainers(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Docker CLI not available'),
          ),
        ),
      );
    });
  });

  group('DockerCliExecutor', () {
    test('classifies missing docker cli as unavailable', () async {
      final executor = DockerCliExecutor(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) {
          throw const ProcessException('docker', ['ps'], 'not found', 127);
        },
      );

      await expectLater(
        executor.run(
          ['ps'],
          timeout: const Duration(seconds: 1),
          operation: 'list containers',
        ),
        throwsA(
          isA<DockerCliFailure>()
              .having((e) => e.kind, 'kind', DockerCliFailureKind.unavailable)
              .having((e) => e.operation, 'operation', 'list containers')
              .having((e) => e.message, 'message', contains('not found')),
        ),
      );
    });

    test('classifies timeout as timeout failure', () async {
      final executor = DockerCliExecutor(
        processRunner: (
          String executable,
          List<String> arguments, {
          String? workingDirectory,
          Map<String, String>? environment,
          bool runInShell = false,
          Encoding? stdoutEncoding,
          Encoding? stderrEncoding,
        }) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return ProcessResult(1, 0, '', '');
        },
      );

      await expectLater(
        executor.run(
          ['ps'],
          timeout: const Duration(milliseconds: 1),
          operation: 'list containers',
        ),
        throwsA(
          isA<DockerCliFailure>().having(
            (e) => e.kind,
            'kind',
            DockerCliFailureKind.timeout,
          ),
        ),
      );
    });
  });
}
