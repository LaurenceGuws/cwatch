import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/controller/adapters/docker_overview_display_ui.dart';
import 'package:cwatch/controller/controllers/docker_overview_display_controller.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/features/docker/services/docker_client_service.dart';

void main() {
  test('inspectImage shows inspect dialog with loaded output', () async {
    final docker = _FakeDockerClientService(
      inspectOutput: '{json}',
      processExitCode: 0,
    );
    final ui = _FakeDockerOverviewDisplayUi();
    final controller = DockerOverviewDisplayController(
      docker: docker,
      ui: ui,
      contextName: 'ctx',
      remoteHost: null,
      shellService: null,
    );

    await controller.inspectImage('img-1');

    expect(ui.inspectTitles, ['Image Inspect: img-1']);
    expect(ui.inspectContents, ['{json}']);
  });

  test('showLogsDialog reports error dialog when log load fails', () async {
    final docker = _FakeDockerClientService(
      inspectOutput: '',
      processExitCode: 1,
    );
    final ui = _FakeDockerOverviewDisplayUi();
    final controller = DockerOverviewDisplayController(
      docker: docker,
      ui: ui,
      contextName: null,
      remoteHost: null,
      shellService: null,
    );

    await controller.showLogsDialog(
      container: DockerContainer(
        id: 'abc',
        name: 'web',
        image: 'nginx',
        state: 'running',
        status: 'Up',
        ports: '',
      ),
      command: 'docker logs abc',
      tailLines: 50,
    );

    expect(ui.errorTitles, ['Failed to load logs']);
    expect(ui.errorMessages.single, contains('docker logs failed'));
  });
}

class _FakeDockerOverviewDisplayUi implements DockerOverviewDisplayUi {
  final List<String> inspectTitles = <String>[];
  final List<String> inspectContents = <String>[];
  final List<String> errorTitles = <String>[];
  final List<String> errorMessages = <String>[];
  final List<String> snackBars = <String>[];

  @override
  Future<void> copyToClipboard(
    String value, {
    required String successMessage,
  }) async {
    snackBars.add(successMessage);
  }

  @override
  Future<void> showErrorDialog({
    required String title,
    required String message,
  }) async {
    errorTitles.add(title);
    errorMessages.add(message);
  }

  @override
  Future<void> showInspectDialog({
    required String title,
    required String content,
  }) async {
    inspectTitles.add(title);
    inspectContents.add(content);
  }

  @override
  Future<void> showLogsDialog({
    required String title,
    required String logs,
  }) async {
    inspectTitles.add(title);
    inspectContents.add(logs);
  }

  @override
  void showSnackBar(String message) {
    snackBars.add(message);
  }
}

class _FakeDockerClientService extends DockerClientService {
  _FakeDockerClientService({
    required this.inspectOutput,
    required this.processExitCode,
  }) : super(
         processRunner: (
           executable,
           arguments, {
           String? workingDirectory,
           Map<String, String>? environment,
           bool runInShell = false,
           Encoding? stdoutEncoding,
           Encoding? stderrEncoding,
         }) async => ProcessResult(
           1,
           processExitCode,
           processExitCode == 0 ? 'logs' : '',
           processExitCode == 0 ? '' : '',
         ),
       );

  final String inspectOutput;
  final int processExitCode;

  @override
  Future<String> inspectImage({
    required String imageId,
    String? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return inspectOutput;
  }
}
