import 'package:flutter/widgets.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/distro_icons.dart';
import 'package:cwatch/shared/widgets/status_dot.dart';

/// Leading slot that pairs a distro icon with a colored status dot.
class DistroLeadingSlot extends StatelessWidget {
  const DistroLeadingSlot({
    super.key,
    required this.iconSize,
    required this.iconColor,
    required this.statusColor,
    this.slug,
    this.iconData,
    this.statusDotScale = 0.25,
  });

  final String? slug;
  final IconData? iconData;
  final double iconSize;
  final double statusDotScale;
  final Color iconColor;
  final Color statusColor;

  static double width(
    BuildContext context,
    double iconSize, {
    double statusDotScale = 0.25,
  }) {
    final dotSize = iconSize * statusDotScale;
    final spacing = context.appTheme.spacing;
    return iconSize + spacing.base * 0.5 + dotSize + spacing.xs;
  }

  @override
  Widget build(BuildContext context) {
    final slotWidth = DistroLeadingSlot.width(
      context,
      iconSize,
      statusDotScale: statusDotScale,
    );
    return SizedBox(
      width: slotWidth,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(color: statusColor, size: iconSize * statusDotScale),
            SizedBox(width: context.appTheme.spacing.xs),
            Icon(
              iconData ?? iconForDistro(slug),
              size: iconSize,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
