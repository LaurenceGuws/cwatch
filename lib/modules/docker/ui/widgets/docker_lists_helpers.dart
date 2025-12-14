import 'package:cwatch/models/docker_container.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';

String? slugForContainer(DockerContainer container) =>
    _slugForReference(container.image);

String? slugForImage(String repository, String tag) =>
    _slugForReference('$repository:$tag');

String? _slugForReference(String reference) {
  final lower = reference.toLowerCase();
  if (lower.isEmpty) {
    return null;
  }
  final segments = lower.split('/');
  final leaf = segments.isNotEmpty ? segments.last : lower;
  final base = leaf.split(':').first;
  final fromBase = normalizeDistroSlug(base);
  if (fromBase != null) {
    return fromBase;
  }
  for (final keyword in _orderedDistroKeywords) {
    if (lower.contains(keyword)) {
      final match = normalizeDistroSlug(keyword);
      if (match != null) {
        return match;
      }
    }
  }
  return null;
}

final _orderedDistroKeywords = [
  ...{...distroIconMap.keys, ...distroAliasMap.keys},
]..sort((a, b) => b.length.compareTo(a.length));
