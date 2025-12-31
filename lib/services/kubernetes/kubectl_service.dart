import 'dart:async';
import 'dart:io';

import '../logging/app_logger.dart';

class KubeNodeStat {
  const KubeNodeStat({
    required this.name,
    this.cpuCores,
    this.cpuPercent,
    this.memoryBytes,
    this.memoryPercent,
  });

  final String name;
  final double? cpuCores;
  final double? cpuPercent;
  final double? memoryBytes;
  final double? memoryPercent;
}

class KubePodStat {
  const KubePodStat({
    required this.namespace,
    required this.name,
    this.cpuCores,
    this.memoryBytes,
  });

  final String namespace;
  final String name;
  final double? cpuCores;
  final double? memoryBytes;
}

class KubeResourceSnapshot {
  const KubeResourceSnapshot({
    required this.nodes,
    required this.pods,
    required this.collectedAt,
  });

  final List<KubeNodeStat> nodes;
  final List<KubePodStat> pods;
  final DateTime collectedAt;
}

class KubectlService {
  const KubectlService();

  Future<KubeResourceSnapshot> fetchResources({
    required String contextName,
    required String configPath,
  }) async {
    final argsBase = ['--context', contextName, '--kubeconfig', configPath];
    final nodesOutput = await _runKubectl([
      ...argsBase,
      'top',
      'nodes',
      '--no-headers',
    ]);
    final podsOutput = await _runKubectl([
      ...argsBase,
      'top',
      'pods',
      '--all-namespaces',
      '--no-headers',
    ]);
    final nodes = _parseNodeStats(nodesOutput);
    final pods = _parsePodStats(podsOutput);
    return KubeResourceSnapshot(
      nodes: nodes,
      pods: pods,
      collectedAt: DateTime.now(),
    );
  }

  Future<String> _runKubectl(List<String> args) async {
    final tag = 'Kubectl';
    final stopwatch = Stopwatch()..start();
    final display = 'kubectl ${args.join(' ')}';
    AppLogger.d('Running $display', tag: tag);
    try {
      final result = await Process.run(
        'kubectl',
        args,
      ).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      if (result.exitCode != 0) {
        final stderr = result.stderr?.toString().trim();
        AppLogger.logRemoteCommand(
          source: 'kubectl',
          operation: 'run',
          command: display,
          output: stderr ?? '',
        );
        final message = (stderr != null && stderr.isNotEmpty)
            ? stderr
            : 'kubectl exited with code ${result.exitCode}';
        AppLogger.w(
          'Failed $display in ${stopwatch.elapsedMilliseconds}ms',
          tag: tag,
          error: message,
        );
        throw Exception(message);
      }
      AppLogger.logRemoteCommand(
        source: 'kubectl',
        operation: 'run',
        command: display,
        output: result.stdout?.toString() ?? '',
      );
      AppLogger.d(
        'Finished $display in ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
      );
      return result.stdout?.toString() ?? '';
    } on TimeoutException {
      stopwatch.stop();
      AppLogger.logRemoteCommand(
        source: 'kubectl',
        operation: 'run',
        command: display,
        output: 'Timed out after ${stopwatch.elapsedMilliseconds}ms',
      );
      AppLogger.w(
        'Timed out $display after ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
      );
      throw Exception('kubectl timed out');
    } catch (e) {
      stopwatch.stop();
      AppLogger.logRemoteCommand(
        source: 'kubectl',
        operation: 'run',
        command: display,
        output: 'Error: $e',
      );
      AppLogger.e(
        'Error running $display after ${stopwatch.elapsedMilliseconds}ms',
        tag: tag,
        error: e,
      );
      if (e is Exception) rethrow;
      throw Exception('Failed to run kubectl: $e');
    }
  }

  List<KubeNodeStat> _parseNodeStats(String output) {
    final lines = output
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty);
    final nodes = <KubeNodeStat>[];
    for (final line in lines) {
      final parts = _splitColumns(line);
      if (parts.length < 4) {
        continue;
      }
      final name = parts[0];
      final cpuCores = _parseCpu(parts[1]);
      final cpuPercent = parts.length > 2 ? _parsePercent(parts[2]) : null;
      final memBytes = parts.length > 3 ? _parseBytes(parts[3]) : null;
      final memPercent = parts.length > 4 ? _parsePercent(parts[4]) : null;
      nodes.add(
        KubeNodeStat(
          name: name,
          cpuCores: cpuCores,
          cpuPercent: cpuPercent,
          memoryBytes: memBytes,
          memoryPercent: memPercent,
        ),
      );
    }
    return nodes;
  }

  List<KubePodStat> _parsePodStats(String output) {
    final lines = output
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty);
    final pods = <KubePodStat>[];
    for (final line in lines) {
      final parts = _splitColumns(line);
      if (parts.length < 3) {
        continue;
      }
      final namespace = parts[0];
      final name = parts[1];
      final cpuCores = _parseCpu(parts[2]);
      final memBytes = parts.length > 3 ? _parseBytes(parts[3]) : null;
      pods.add(
        KubePodStat(
          namespace: namespace,
          name: name,
          cpuCores: cpuCores,
          memoryBytes: memBytes,
        ),
      );
    }
    return pods;
  }

  List<String> _splitColumns(String line) {
    return line
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .toList();
  }

  double? _parseCpu(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '-') return null;
    if (value.endsWith('m')) {
      final numPart = double.tryParse(value.substring(0, value.length - 1));
      return numPart != null ? numPart / 1000 : null;
    }
    return double.tryParse(value);
  }

  double? _parsePercent(String raw) {
    final value = raw.trim().replaceAll('%', '');
    if (value.isEmpty || value == '-') return null;
    return double.tryParse(value);
  }

  double? _parseBytes(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '-') return null;
    final pattern = RegExp(r'^([0-9.]+)([KMG]i)?$', caseSensitive: false);
    final match = pattern.firstMatch(value);
    if (match == null) {
      return double.tryParse(value);
    }
    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      return null;
    }
    final unit = match.group(2)?.toLowerCase();
    switch (unit) {
      case 'ki':
        return number * 1024;
      case 'mi':
        return number * 1024 * 1024;
      case 'gi':
        return number * 1024 * 1024 * 1024;
      default:
        return number;
    }
  }
}
