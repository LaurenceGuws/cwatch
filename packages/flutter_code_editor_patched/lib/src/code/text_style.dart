import 'package:flutter/painting.dart';

extension TextStyleExtension on TextStyle {
  String toMapString() {
    final result = {
      'color': color,
      //add another fields if required
    };
    result.removeWhere((key, value) => value == null);
    return result.toString();
  }

  TextStyle paled() {
    final clr = color;

    if (clr == null) {
      return this;
    }

    int channel(double value) => (value * 255).round().clamp(0, 255);
    final alpha = (channel(clr.a) / 2).round().clamp(0, 255).toInt();
    return copyWith(
      color: Color.fromARGB(
        alpha,
        channel(clr.r),
        channel(clr.g),
        channel(clr.b),
      ),
    );
  }
}
