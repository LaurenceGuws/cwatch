part of 'package:cwatch/model/shared/theme/app_theme.dart';

class AppDockerTokens {
  const AppDockerTokens({
    required this.running,
    required this.stopped,
    required this.images,
    required this.networks,
    required this.volumes,
    required this.chartPalette,
    required this.chartGrid,
    required this.chartGridAlt,
  });

  final Color running;
  final Color stopped;
  final Color images;
  final Color networks;
  final Color volumes;
  final List<Color> chartPalette;
  final Color chartGrid;
  final Color chartGridAlt;

  factory AppDockerTokens.fromScheme(ColorScheme scheme) {
    return AppDockerTokens(
      running: Colors.green,
      stopped: Colors.orange,
      images: Colors.blueGrey,
      networks: Colors.teal,
      volumes: Colors.deepPurple,
      chartPalette: const [
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.red,
        Colors.indigo,
        Colors.pink,
        Colors.cyan,
        Colors.brown,
      ],
      chartGrid: Colors.grey,
      chartGridAlt: Colors.grey,
    );
  }

  static AppDockerTokens lerp(AppDockerTokens a, AppDockerTokens b, double t) {
    return AppDockerTokens(
      running: Color.lerp(a.running, b.running, t) ?? a.running,
      stopped: Color.lerp(a.stopped, b.stopped, t) ?? a.stopped,
      images: Color.lerp(a.images, b.images, t) ?? a.images,
      networks: Color.lerp(a.networks, b.networks, t) ?? a.networks,
      volumes: Color.lerp(a.volumes, b.volumes, t) ?? a.volumes,
      chartPalette: List<Color>.generate(
        a.chartPalette.length,
        (index) =>
            Color.lerp(a.chartPalette[index], b.chartPalette[index], t) ??
            a.chartPalette[index],
      ),
      chartGrid: Color.lerp(a.chartGrid, b.chartGrid, t) ?? a.chartGrid,
      chartGridAlt:
          Color.lerp(a.chartGridAlt, b.chartGridAlt, t) ?? a.chartGridAlt,
    );
  }
}

class DistroColors {
  const DistroColors({
    required this.ubuntu,
    required this.debian,
    required this.arch,
    required this.fedora,
    required this.centos,
    required this.redhat,
    required this.alpine,
    required this.opensuse,
    required this.oracle,
    required this.pop,
    required this.mint,
    required this.nixos,
    required this.raspbian,
    required this.android,
    required this.windows,
    required this.macos,
    required this.linux,
    required this.unknown,
  });

  final Color ubuntu;
  final Color debian;
  final Color arch;
  final Color fedora;
  final Color centos;
  final Color redhat;
  final Color alpine;
  final Color opensuse;
  final Color oracle;
  final Color pop;
  final Color mint;
  final Color nixos;
  final Color raspbian;
  final Color android;
  final Color windows;
  final Color macos;
  final Color linux;
  final Color unknown;

  factory DistroColors.standard() {
    return const DistroColors(
      ubuntu: Color(0xFFE95420),
      debian: Color(0xFFD70A53),
      arch: Color(0xFF1793D1),
      fedora: Color(0xFF294172),
      centos: Color(0xFF932279),
      redhat: Color(0xFFCC0000),
      alpine: Color(0xFF0D597F),
      opensuse: Color(0xFF73BA25),
      oracle: Color(0xFFC74634),
      pop: Color(0xFF48B9C7),
      mint: Color(0xFF4CAF50),
      nixos: Color(0xFF7EBAE4),
      raspbian: Color(0xFFC7053D),
      android: Color(0xFF3DDC84),
      windows: Color(0xFF00A4EF),
      macos: Color(0xFF545454),
      linux: Color(0xFF4DB6AC),
      unknown: Color(0xFF9E9E9E),
    );
  }

  static DistroColors lerp(DistroColors a, DistroColors b, double t) {
    Color blend(Color x, Color y) => Color.lerp(x, y, t) ?? x;
    return DistroColors(
      ubuntu: blend(a.ubuntu, b.ubuntu),
      debian: blend(a.debian, b.debian),
      arch: blend(a.arch, b.arch),
      fedora: blend(a.fedora, b.fedora),
      centos: blend(a.centos, b.centos),
      redhat: blend(a.redhat, b.redhat),
      alpine: blend(a.alpine, b.alpine),
      opensuse: blend(a.opensuse, b.opensuse),
      oracle: blend(a.oracle, b.oracle),
      pop: blend(a.pop, b.pop),
      mint: blend(a.mint, b.mint),
      nixos: blend(a.nixos, b.nixos),
      raspbian: blend(a.raspbian, b.raspbian),
      android: blend(a.android, b.android),
      windows: blend(a.windows, b.windows),
      macos: blend(a.macos, b.macos),
      linux: blend(a.linux, b.linux),
      unknown: blend(a.unknown, b.unknown),
    );
  }
}
