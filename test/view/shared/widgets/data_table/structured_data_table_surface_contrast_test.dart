import 'package:cwatch/view/shared/widgets/data_table/structured_data_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const contrast = StructuredDataTableSurfaceContrast();
  const outline = Colors.blueGrey;

  test('header border is stronger on light backgrounds', () {
    final light = contrast.headerBorderColor(
      background: Colors.white,
      outlineVariant: outline,
    );
    final dark = contrast.headerBorderColor(
      background: Colors.black,
      outlineVariant: outline,
    );

    expect(light.a, greaterThan(dark.a));
  });

  test('divider is stronger on light backgrounds', () {
    final light = contrast.dividerColor(
      background: Colors.white,
      outlineVariant: outline,
    );
    final dark = contrast.dividerColor(
      background: Colors.black,
      outlineVariant: outline,
    );

    expect(light.a, greaterThan(dark.a));
  });
}
