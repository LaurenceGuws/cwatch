import 'package:flutter_test/flutter_test.dart';

import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';

void main() {
  group('normalizeDistroSlug', () {
    test('handles oracle linux aliases', () {
      expect(normalizeDistroSlug('ol'), 'oraclelinux');
      expect(normalizeDistroSlug('oracle linux'), 'oraclelinux');
    });

    test('handles openSUSE flavors', () {
      expect(normalizeDistroSlug('opensuse-leap'), 'opensuse');
      expect(normalizeDistroSlug('openSUSE Tumbleweed'), 'opensuse');
    });

    test('handles Debian codenames', () {
      expect(normalizeDistroSlug('debian bookworm'), 'debian');
      expect(normalizeDistroSlug('debian-bullseye'), 'debian');
    });

    test('handles Kali rolling tag', () {
      expect(normalizeDistroSlug('kali-rolling'), 'kali');
    });
  });

  test('uses Debian Nerd Font glyph', () {
    final icon = iconForDistro('debian');
    expect(icon.fontFamily, NerdFonts.family);
    expect(icon.codePoint, 0xf306);
  });

  test('reuses CentOS glyph for CentOS derivatives', () {
    expect(codePointForDistro('rocky'), 0xf304);
    expect(codePointForDistro('almalinux'), 0xf304);
    expect(codePointForDistro('oraclelinux'), 0xf0337);
    expect(codePointForDistro('amazonlinux'), 0xf270);
  });

  test('uses Red Hat glyph for RHEL', () {
    expect(codePointForDistro('rhel'), 0xf316);
    expect(codePointForDistro('redhat'), 0xf316);
  });

  test('uses Debian glyph for Kali', () {
    expect(codePointForDistro('kali'), 0xf306);
  });

  test('maps arch derivatives to Arch glyph', () {
    expect(codePointForDistro('artix'), 0xf303);
    expect(codePointForDistro('cachyos'), 0xf303);
    expect(codePointForDistro('mabox'), 0xf303);
  });

  test('maps fedora derivatives to Fedora glyph', () {
    expect(codePointForDistro('nobara'), 0xf30a);
    expect(codePointForDistro('ultramarine'), 0xf30a);
  });

  test('uses Starship glyphs for EndeavourOS/Garuda', () {
    expect(codePointForDistro('endeavouros'), 0xf197);
    expect(codePointForDistro('garuda'), 0xf06d3);
  });
}
