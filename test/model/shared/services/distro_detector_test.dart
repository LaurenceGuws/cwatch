import 'dart:async';

import 'package:cwatch/model/shared/services/distro_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns slug from os release when available', () async {
    final detector = DistroDetector((command, {timeout}) async {
      if (command == 'cat /etc/os-release') {
        return 'ID=arch\nNAME="Arch Linux"\n';
      }
      fail('uname should not run when os-release succeeds');
    });

    final result = await detector.detectDetailed();

    expect(result.slug, 'arch');
    expect(result.primaryError, isNull);
  });

  test('falls back to uname and keeps os-release failure detail', () async {
    final detector = DistroDetector((command, {timeout}) async {
      if (command == 'cat /etc/os-release') {
        throw Exception('permission denied');
      }
      if (command == 'uname -s') {
        return 'Linux\n';
      }
      throw UnimplementedError(command);
    });

    final result = await detector.detectDetailed();

    expect(result.slug, 'linux');
    expect(result.osReleaseError.toString(), contains('permission denied'));
    expect(result.unameError, isNull);
  });

  test('returns final failure detail when both probes fail', () async {
    final detector = DistroDetector((command, {timeout}) async {
      if (command == 'cat /etc/os-release') {
        throw Exception('no shell');
      }
      if (command == 'uname -s') {
        throw Exception('timed out');
      }
      throw UnimplementedError(command);
    });

    final result = await detector.detectDetailed();

    expect(result.slug, isNull);
    expect(result.osReleaseError.toString(), contains('no shell'));
    expect(result.unameError.toString(), contains('timed out'));
    expect(result.primaryError.toString(), contains('timed out'));
  });

  test('treats timeouts as no result without synthetic errors', () async {
    final detector = DistroDetector((command, {timeout}) async {
      throw TimeoutException('timeout');
    });

    final result = await detector.detectDetailed();

    expect(result.slug, isNull);
    expect(result.osReleaseError, isNull);
    expect(result.unameError, isNull);
    expect(result.primaryError, isNull);
  });
}
