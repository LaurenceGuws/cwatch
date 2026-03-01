import 'dart:math' as math;

import 'package:flutter/material.dart';

class OverlayScrollbar extends StatelessWidget {
  const OverlayScrollbar({
    super.key,
    required this.viewportExtent,
    required this.contentExtent,
    required this.offset,
    required this.onOffsetChanged,
    this.onStepUp,
    this.onStepDown,
    this.width = 18,
    this.reverse = false,
  });

  final double viewportExtent;
  final double contentExtent;
  final double offset;
  final ValueChanged<double> onOffsetChanged;
  final VoidCallback? onStepUp;
  final VoidCallback? onStepDown;
  final double width;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxOffset = math.max(0.0, contentExtent - viewportExtent);
    final effectiveOffset = offset.clamp(0.0, maxOffset);
    final enabled = maxOffset > 0.0;

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          _ArrowButton(
            icon: Icons.keyboard_arrow_up,
            enabled: enabled && onStepUp != null,
            onTap: onStepUp,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                if (trackHeight <= 0) {
                  return const SizedBox.shrink();
                }
                final thumbFraction = enabled
                    ? (viewportExtent / contentExtent).clamp(0.08, 1.0)
                    : 1.0;
                final thumbHeight = (trackHeight * thumbFraction).clamp(
                  14.0,
                  trackHeight,
                );
                final travel = math.max(0.0, trackHeight - thumbHeight);
                final progress = enabled && maxOffset > 0
                    ? (effectiveOffset / maxOffset).clamp(0.0, 1.0)
                    : 0.0;
                final visualProgress = reverse ? (1.0 - progress) : progress;
                final thumbTop = enabled && travel > 0
                    ? visualProgress * travel
                    : 0.0;

                void jumpToLocalY(double localY) {
                  if (!enabled || travel <= 0) {
                    return;
                  }
                  final centered = (localY - thumbHeight / 2).clamp(
                    0.0,
                    travel,
                  );
                  final visual = centered / travel;
                  final logical = reverse ? (1.0 - visual) : visual;
                  final next = logical * maxOffset;
                  onOffsetChanged(next);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      jumpToLocalY(details.localPosition.dy),
                  onVerticalDragUpdate: (details) =>
                      jumpToLocalY(details.localPosition.dy),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 2,
                        right: 2,
                        top: thumbTop,
                        child: Container(
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: enabled
                                ? scheme.primary.withValues(alpha: 0.85)
                                : scheme.outlineVariant.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _ArrowButton(
            icon: Icons.keyboard_arrow_down,
            enabled: enabled && onStepDown != null,
            onTap: onStepDown,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 18,
        child: Icon(
          icon,
          size: 14,
          color: enabled
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
