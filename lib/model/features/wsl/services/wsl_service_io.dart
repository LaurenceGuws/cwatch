import 'dart:io';

import 'wsl_distribution.dart';
import 'wsl_service_interface.dart';

WslService createWslServiceImpl() => _WslService();

class _WslService implements WslService {
  static final RegExp _splitPattern = RegExp(r'\\s{2,}');

  @override
  Future<List<WslDistribution>> listDistributions() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final result = await Process.run('wsl.exe', ['--list', '--verbose']);
    if (result.exitCode != 0) {
      final stderrText = (result.stderr ?? '').toString().trim();
      throw Exception(
        'wsl.exe exited with ${result.exitCode}'
        '${stderrText.isEmpty ? '' : ': $stderrText'}',
      );
    }
    final stdoutText = (result.stdout ?? '').toString();
    return _parse(_sanitize(stdoutText));
  }

  String _sanitize(String output) {
    // Remove control characters and other non-printable bytes that show up as
    // empty blocks when Windows returns UTF-16 output.
    return output.replaceAll(RegExp(r'[^\n\r\x20-\x7E]'), '');
  }

  List<WslDistribution> _parse(String output) {
    final lines = output.split('\n');
    final result = <WslDistribution>[];
    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        continue;
      }
      if (line.contains('NAME') && line.contains('STATE')) {
        // Skip column headers from `wsl --list --verbose`.
        continue;
      }
      if (line.startsWith('Windows Subsystem for Linux')) {
        // Skip banner lines like "Windows Subsystem for Linux Distributions:".
        continue;
      }
      var isDefault = line.startsWith('*');
      var normalized = isDefault ? line.substring(1).trimLeft() : line;
      if (normalized.contains('(Default)')) {
        isDefault = true;
        normalized = normalized.replaceAll('(Default)', '').trimRight();
      }
      final parts = normalized.split(_splitPattern);
      if (parts.length >= 3) {
        result.add(
          WslDistribution(
            name: parts[0].trim(),
            state: parts[1].trim(),
            version: parts[2].trim(),
            isDefault: isDefault,
          ),
        );
        continue;
      }
      if (parts.isNotEmpty) {
        // Fallback for `wsl --list` output that lacks state/version columns.
        result.add(
          WslDistribution(
            name: parts[0].trim(),
            state: 'Unknown',
            version: '-',
            isDefault: isDefault,
          ),
        );
      }
    }
    return result;
  }
}
