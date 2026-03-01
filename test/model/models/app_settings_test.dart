import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/model/models/app_settings.dart';

void main() {
  test('zideFfiBackendEnabled defaults to false', () {
    const settings = AppSettings();
    expect(settings.zideFfiBackendEnabled, isFalse);
  });

  test('zideFfiBackendEnabled round-trips through json', () {
    const settings = AppSettings(zideFfiBackendEnabled: true);
    final encoded = settings.toJson();
    final decoded = AppSettings.fromJson(encoded);
    expect(decoded.zideFfiBackendEnabled, isTrue);
  });
}
