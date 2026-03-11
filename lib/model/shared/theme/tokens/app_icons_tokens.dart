part of app_theme;

class AppIcons {
  const AppIcons({
    required this.cloud,
    required this.cloudOutline,
    required this.folderOpen,
    required this.edit,
    required this.delete,
    required this.settings,
    required this.search,
    required this.dns,
    required this.arrowRight,
    required this.arrowDown,
    required this.refresh,
    required this.copy,
    required this.container,
    required this.image,
    required this.network,
    required this.volume,
  });

  final IconData cloud;
  final IconData cloudOutline;
  final IconData folderOpen;
  final IconData edit;
  final IconData delete;
  final IconData settings;
  final IconData search;
  final IconData dns;
  final IconData arrowRight;
  final IconData arrowDown;
  final IconData refresh;
  final IconData copy;
  final IconData container;
  final IconData image;
  final IconData network;
  final IconData volume;

  factory AppIcons.nerd() = _NerdIcons;
}

class _NerdIcons extends AppIcons {
  _NerdIcons()
    : super(
        cloud: nerdIconData[NerdIcon.cloud]!,
        cloudOutline: nerdIconData[NerdIcon.cloud]!,
        folderOpen: nerdIconData[NerdIcon.folderOpen]!,
        edit: nerdIconData[NerdIcon.pencil]!,
        delete: nerdIconData[NerdIcon.delete]!,
        settings: nerdIconData[NerdIcon.settings]!,
        search: nerdIconData[NerdIcon.search]!,
        dns: nerdIconData[NerdIcon.servers]!,
        arrowRight: nerdIconData[NerdIcon.arrowRight]!,
        arrowDown: nerdIconData[NerdIcon.arrowDown]!,
        refresh: nerdIconData[NerdIcon.refresh]!,
        copy: nerdIconData[NerdIcon.copy]!,
        container: nerdIconData[NerdIcon.docker]!,
        image: nerdIconData[NerdIcon.fileImage]!,
        network: nerdIconData[NerdIcon.accessPoint]!,
        volume: nerdIconData[NerdIcon.database]!,
      );
}

class AppIconsTokens {
  const AppIconsTokens({this.zoomFactor = 1.0});

  final double zoomFactor;

  double get small => 16 * zoomFactor;
  double get medium => 18 * zoomFactor;
  double get large => 20 * zoomFactor;
  double get xlarge => 24 * zoomFactor;
  double get xxlarge => 30 * zoomFactor;
  double get navigation => 30 * zoomFactor;
  double get emptyState => 48 * zoomFactor;
  double get emptyStateXlarge => 64 * zoomFactor;

  static AppIconsTokens lerp(AppIconsTokens a, AppIconsTokens b, double t) {
    return AppIconsTokens(
      zoomFactor: lerpDouble(a.zoomFactor, b.zoomFactor, t),
    );
  }
}
