import 'package:flutter/widgets.dart';

/// Centralizes Nerd Font usage (JetBrainsMono Nerd Font) and exposes
/// strongly typed glyphs for product logos or app-specific icons.
class NerdFonts {
  static const String family = 'JetBrainsMonoNF';

  static IconData icon(int codePoint) => IconData(
        codePoint,
        fontFamily: family,
        fontPackage: null,
      );
}

enum NerdIcon {
  servers(0xf048b),
  docker(0xf0868),
  kubernetes(0xf10fe),
  folder(0xf024b),
  folderOpen(0xf0770),
  fileCode(0xf022e),
  yaml(0xe8eb),
  terminal(0xea85),
  accessPoint(0xf0002),
  settings(0xf0493),
  checkCircle(0xf05e0),
  alert(0xf0026),
  cloudUpload(0xf0167),
  refresh(0xf0450),
  delete(0xf09e7),
  add(0xf0415),
  dart(0xe798),
  javascript(0xf031e),
  typescript(0xf06e6),
  css3(0xf031c),
  html5(0xf031d),
  go(0xf07d3),
  rust(0xf1617),
  python(0xf0320),
  ruby(0xf0d2d),
  php(0xf031f),
  java(0xf0b37),
  kotlin(0xf1219),
  swift(0xf06e5),
  c(0xf0671),
  cpp(0xf0672),
  csharp(0xf031b),
  markdown(0xf0354),
  json(0xe80b),
  database(0xe706),
  config(0xf107b),
  fileImage(0xf021f),
  lock(0xf033e),
  arrowRight(0xf0939),
  pencil(0xf03eb),
  drag(0xf01dd),
  close(0xf06c9);

  const NerdIcon(this.codePoint);

  final int codePoint;

  IconData get data => NerdFonts.icon(codePoint);

  String get character => String.fromCharCode(codePoint);
}
