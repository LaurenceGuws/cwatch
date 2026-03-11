import 'package:flutter/material.dart';

import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/shared/theme/distro_icons.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';

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

String inferComposeGroup(String name) {
  final cleaned = name.trim();
  if (cleaned.contains('_')) {
    final project = cleaned.split('_').first;
    if (project.isNotEmpty) return 'Compose: $project';
  }
  if (cleaned.contains('-')) {
    final parts = cleaned.split('-');
    if (parts.length > 1) {
      const commonSuffixes = {
        'default',
        'app',
        'web',
        'db',
        'backend',
        'frontend',
        'api',
        'service',
        'svc',
        'worker',
        'cache',
        'data',
      };
      if (commonSuffixes.contains(parts.last.toLowerCase()) ||
          parts.length > 2) {
        final project = parts.first;
        if (project.isNotEmpty) return 'Compose: $project';
      }
    }
  }
  return 'Standalone';
}

double distroIconSize(BuildContext context) {
  final titleSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 14;
  return (titleSize * 1.9) * context.zoomFactor;
}

Color sectionBackgroundForIndex(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  final base = context.appTheme.section.surface.background;
  final overlay = scheme.surfaceTint.withValues(alpha: 0.08);
  final alternate = Color.alphaBlend(overlay, base);
  return index.isEven ? base : alternate;
}

String valueOrDash(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }
  return value;
}
