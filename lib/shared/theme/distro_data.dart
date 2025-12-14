import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Flutter-free distro metadata (codepoints, labels, aliases, slug helpers).
/// Glyphs mirror Starship's Nerd Font symbols.
const int kLinuxCodePoint = 0xf31a; // 
const int kWindowsCodePoint = 0xf0372; // 󰍲
const int kAppleCodePoint = 0xf302; // 
const int kArchCodePoint = 0xf303; // 
const int kFedoraCodePoint = 0xf30a; // 
const int kCentosCodePoint = 0xf304; // 
const int kUbuntuCodePoint = 0xf31b; // 
const int kDebianCodePoint = 0xf306; // 
const int kAlpineCodePoint = 0xf300; // 
const int kGentooCodePoint = 0xf30d; // 
const int kMintCodePoint = 0xf30e; // 
const int kManjaroCodePoint = 0xf312; // 
const int kOpenSuseCodePoint = 0xf314; // 
const int kNixosCodePoint = 0xf313; // 
const int kRaspbianCodePoint = 0xf315; // 
const int kRedhatCodePoint = 0xf316; // 
const int kPopCodePoint = 0xe2a3; // 
const int kAoscCodePoint = 0xf301; // 
const int kAmazonCodePoint = 0xf270; // 
const int kOracleCodePoint = 0xf0337; // 󰌷
const int kFreeBsdCodePoint = 0xf30c; // 
const int kNetBsdCodePoint = 0xf024; // 
const int kOpenBsdCodePoint = 0xf023a; // 󰈺
const int kDragonflyCodePoint = 0xe28e; // 
const int kSolusCodePoint = 0xf0833; // 󰠳

// Baseline distro codepoints derived from Nerd Font symbols.
const Map<String, int> _baseIconCodepoints = {
  'alpine': kAlpineCodePoint,
  'amazon': kAmazonCodePoint,
  'android': 0xf17b,
  'aosc': kAoscCodePoint,
  'arch': kArchCodePoint,
  'centos': kCentosCodePoint,
  'debian': kDebianCodePoint,
  'dragonfly': kDragonflyCodePoint,
  'emscripten': 0xf205,
  'endeavouros': 0xf197,
  'fedora': kFedoraCodePoint,
  'freebsd': kFreeBsdCodePoint,
  'garuda': 0xf06d3,
  'gentoo': kGentooCodePoint,
  'hardenedbsd': 0xf078c,
  'illumos': 0xf0238,
  'linux': kLinuxCodePoint,
  'macos': kAppleCodePoint,
  'manjaro': kManjaroCodePoint,
  'mariner': 0xf1cd,
  'midnightbsd': 0xf186,
  'mint': kMintCodePoint,
  'netbsd': kNetBsdCodePoint,
  'nixos': kNixosCodePoint,
  'openbsd': kOpenBsdCodePoint,
  'opensuse': kOpenSuseCodePoint,
  'oraclelinux': kOracleCodePoint,
  'pop': kPopCodePoint,
  'raspbian': kRaspbianCodePoint,
  'redhat': kRedhatCodePoint,
  'redhatenterprise': kRedhatCodePoint,
  'redox': 0xf0018,
  'solus': kSolusCodePoint,
  'suse': kOpenSuseCodePoint,
  'ubuntu': kUbuntuCodePoint,
  'unknown': 0xf22d,
  'windows': kWindowsCodePoint,
};

const Map<String, int> _extraCodePointMap = {
  // Derivatives and additional slugs we want to normalize to Starship glyphs.
  'archlinux': kArchCodePoint,
  'rhel': kRedhatCodePoint,
  'almalinux': kCentosCodePoint,
  'rocky': kCentosCodePoint,
  'oracle': kOracleCodePoint,
  'amazonlinux': kAmazonCodePoint,
  'artix': kArchCodePoint,
  'cachyos': kArchCodePoint,
  'mabox': kArchCodePoint,
  'bluefin': kUbuntuCodePoint,
  'nobara': kFedoraCodePoint,
  'ultramarine': kFedoraCodePoint,
  'pop_os': kPopCodePoint,
  'kali': kDebianCodePoint,
  'kali-linux': kDebianCodePoint,
  'kalilinux': kDebianCodePoint,
  'raspberrypi': kRaspbianCodePoint,
  'openeuler': kLinuxCodePoint,
  'opencloudos': kCentosCodePoint,
  'void': kLinuxCodePoint,
  'alpaquita': kDebianCodePoint,
  'uos': kLinuxCodePoint,
};

const Map<String, int> distroCodePointMap = {
  ..._baseIconCodepoints,
  ..._extraCodePointMap,
};

const Map<String, String> _baseIconLabels = {
  'alpine': 'Alpine',
  'amazon': 'Amazon',
  'android': 'Android',
  'aosc': 'AOSC',
  'arch': 'Arch',
  'centos': 'CentOS',
  'debian': 'Debian',
  'dragonfly': 'DragonFly',
  'emscripten': 'Emscripten',
  'endeavouros': 'EndeavourOS',
  'fedora': 'Fedora',
  'freebsd': 'FreeBSD',
  'garuda': 'Garuda',
  'gentoo': 'Gentoo',
  'hardenedbsd': 'HardenedBSD',
  'illumos': 'Illumos',
  'linux': 'Linux',
  'macos': 'MacOS',
  'manjaro': 'Manjaro',
  'mariner': 'Mariner',
  'midnightbsd': 'MidnightBSD',
  'mint': 'Mint',
  'netbsd': 'NetBSD',
  'nixos': 'NixOS',
  'openbsd': 'OpenBSD',
  'opensuse': 'openSUSE',
  'oraclelinux': 'Oracle Linux',
  'pop': 'Pop!_OS',
  'raspbian': 'Raspbian',
  'redhat': 'Red Hat',
  'redhatenterprise': 'Red Hat Enterprise Linux',
  'redox': 'Redox',
  'solus': 'Solus',
  'suse': 'SUSE',
  'ubuntu': 'Ubuntu',
  'unknown': 'Unknown',
  'windows': 'Windows',
};

const Map<String, String> _extraLabelMap = {
  'archlinux': 'Arch Linux',
  'linuxmint': 'Linux Mint',
  'darwin': 'macOS',
  'mac': 'macOS',
  'almalinux': 'AlmaLinux',
  'rocky': 'Rocky Linux',
  'pop_os': 'Pop!_OS',
  'oracle': 'Oracle Linux',
  'amazonlinux': 'Amazon Linux',
  'artix': 'Artix Linux',
  'cachyos': 'CachyOS',
  'mabox': 'Mabox Linux',
  'bluefin': 'Bluefin',
  'nobara': 'Nobara',
  'ultramarine': 'Ultramarine',
  'kali': 'Kali Linux',
  'openeuler': 'openEuler',
  'opencloudos': 'OpenCloudOS',
  'void': 'Void Linux',
  'alpaquita': 'Alpaquita',
  'uos': 'UOS',
};

const Map<String, String> distroLabelMap = {
  ..._baseIconLabels,
  ..._extraLabelMap,
};

const Map<String, String> distroAliasMap = {
  'rh': 'redhat',
  'rhel': 'redhat',
  'ol': 'oraclelinux',
  'oracle': 'oraclelinux',
  'oracle-linux': 'oraclelinux',
  'rockylinux': 'rocky',
  'rocky-linux': 'rocky',
  'redhatenterprise': 'rhel',
  'rhel-like': 'rhel',
  'centos-stream': 'centos',
  'centosstream': 'centos',
  'amazonlinux': 'amazon',
  'amzn': 'amazon',
  'pop': 'pop_os',
  'pop-os': 'pop_os',
  'popos': 'pop_os',
  'kali-rolling': 'kali',
  'kali-linux': 'kali',
  'kalilinux': 'kali',
  'opensuse-leap': 'opensuse',
  'opensuse-tumbleweed': 'opensuse',
  // Debian/Ubuntu codenames map to parent slugs.
  'bookworm': 'debian',
  'bullseye': 'debian',
  'buster': 'debian',
  'stretch': 'debian',
  'trixie': 'debian',
  'jammy': 'ubuntu',
  'noble': 'ubuntu',
  'focal': 'ubuntu',
  'mantic': 'ubuntu',
  'lunar': 'ubuntu',
  'oracular': 'ubuntu',
  // Fedora/CentOS/OpenSUSE flavors.
  'stream': 'centos',
  'tumbleweed': 'opensuse',
  'leap': 'opensuse',
  // Alpine/Arch flavors.
  'edge': 'alpine',
  'linuxmint': 'mint',
  'raspbian': 'raspbian',
  'raspberrypi': 'raspbian',
  'artixlinux': 'artix',
  'endeavour': 'endeavouros',
  'endeavouros': 'endeavouros',
  'garuda-linux': 'garuda',
  'cachyos': 'cachyos',
  'maboxlinux': 'mabox',
  'bluefin': 'bluefin',
  'nobara': 'nobara',
  'ultramarine': 'ultramarine',
  'openeuler': 'openeuler',
  'opencloudos': 'opencloudos',
  'voidlinux': 'void',
  'alpaquita': 'alpaquita',
  'cbl-mariner': 'mariner',
  'mariner': 'mariner',
  'uos': 'uos',
};

final _orderedDistroKeywords = [
  ...{...distroCodePointMap.keys, ...distroAliasMap.keys},
]..sort((a, b) => b.length.compareTo(a.length));

final _distroSlugCleaner = RegExp(r'[^a-z0-9]+');

int codePointForDistro(String? slug) =>
    distroCodePointMap[slug?.toLowerCase()] ?? kLinuxCodePoint;

String labelForDistro(String? slug) =>
    distroLabelMap[slug?.toLowerCase()] ?? 'Linux';

Color colorForDistro(String? slug, AppThemeTokens theme) {
  final distro = normalizeDistroSlug(slug ?? '') ?? 'unknown';
  final colors = theme.distroColors;
  switch (distro) {
    case 'ubuntu':
      return colors.ubuntu;
    case 'debian':
    case 'kali':
      return colors.debian;
    case 'arch':
    case 'archlinux':
    case 'artix':
    case 'cachyos':
    case 'mabox':
      return colors.arch;
    case 'fedora':
    case 'nobara':
    case 'ultramarine':
      return colors.fedora;
    case 'centos':
    case 'rocky':
    case 'almalinux':
      return colors.centos;
    case 'rhel':
    case 'redhat':
    case 'redhatenterprise':
      return colors.redhat;
    case 'alpine':
      return colors.alpine;
    case 'opensuse':
    case 'suse':
      return colors.opensuse;
    case 'oraclelinux':
    case 'oracle':
      return colors.oracle;
    case 'pop_os':
    case 'pop':
      return colors.pop;
    case 'linuxmint':
    case 'mint':
      return colors.mint;
    case 'nixos':
      return colors.nixos;
    case 'raspbian':
      return colors.raspbian;
    case 'android':
      return colors.android;
    case 'windows':
      return colors.windows;
    case 'darwin':
    case 'mac':
    case 'macos':
      return colors.macos;
    case 'linux':
    case 'unknown':
    default:
      return colors.linux;
  }
}

String? normalizeDistroSlug(String raw) {
  final normalized = raw.toLowerCase().trim();
  if (normalized.isEmpty) {
    return null;
  }
  final directAlias = distroAliasMap[normalized];
  if (directAlias != null) {
    return directAlias;
  }
  final cleaned = normalized.replaceAll(_distroSlugCleaner, '');
  if (cleaned.isEmpty) {
    return null;
  }
  if (distroCodePointMap.containsKey(cleaned)) {
    return cleaned;
  }
  final aliasFromClean = distroAliasMap[cleaned];
  if (aliasFromClean != null) {
    return aliasFromClean;
  }
  for (final keyword in _orderedDistroKeywords) {
    if (cleaned.startsWith(keyword)) {
      final alias = distroAliasMap[keyword];
      if (alias != null) {
        return alias;
      }
      if (distroCodePointMap.containsKey(keyword)) {
        return keyword;
      }
    }
  }
  return null;
}
