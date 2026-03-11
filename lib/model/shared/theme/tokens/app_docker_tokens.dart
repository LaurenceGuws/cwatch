part of app_theme;

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

