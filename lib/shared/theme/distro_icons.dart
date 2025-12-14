export 'distro_data.dart'
    show
        codePointForDistro,
        distroAliasMap,
        distroCodePointMap,
        distroLabelMap,
        labelForDistro,
        normalizeDistroSlug,
        colorForDistro;

import 'package:flutter/widgets.dart';

import 'distro_data.dart';
import 'nerd_fonts.dart';

const IconData _kLinuxIcon =
    IconData(kLinuxCodePoint, fontFamily: NerdFonts.family);

/// Long tail of distro slugs that map to the same icon.
final Map<String, IconData> distroIconMap = {
  for (final entry in distroCodePointMap.entries)
    entry.key: IconData(entry.value, fontFamily: NerdFonts.family),
};

IconData iconForDistro(String? slug) =>
    distroIconMap[slug?.toLowerCase()] ?? _kLinuxIcon;
