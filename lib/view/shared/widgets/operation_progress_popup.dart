import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';

class OperationProgressPopup extends StatelessWidget {
  const OperationProgressPopup({
    super.key,
    required this.title,
    required this.completed,
    required this.total,
    required this.progress,
    this.subtitle,
    this.currentItem,
    this.icon = Icons.sync,
    this.onCancel,
  });

  final String title;
  final String? subtitle;
  final int completed;
  final int total;
  final double progress;
  final String? currentItem;
  final IconData icon;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final section = context.appTheme.section;
    final surface = section.surface;
    final typography = context.appTheme.typography;
    final colorScheme = Theme.of(context).colorScheme;
    final progressTrack = section.divider.withValues(alpha: 0.35);
    final baseSize = typography.caption.fontSize ?? 12;
    final metaStyle = typography.caption.copyWith(
      fontSize: (baseSize - 1).clamp(10, baseSize),
    );
    final progressLabel = total > 0 ? '$completed / $total' : '--';

    return Material(
      elevation: surface.elevation,
      color: surface.background,
      shape: RoundedRectangleBorder(
        borderRadius: surface.radius,
        side: BorderSide(color: surface.borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, minWidth: 280),
        child: Padding(
          padding: surface.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.primary),
                  SizedBox(width: spacing.sm),
                  Expanded(child: Text(title, style: typography.tabLabel)),
                  if (onCancel != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: onCancel,
                    ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress: $progressLabel', style: metaStyle),
                    if (subtitle != null) Text(subtitle!, style: metaStyle),
                  ],
                ),
              ),
              SizedBox(height: spacing.sm),
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                lineHeight: 8,
                percent: progress.clamp(0.0, 1.0),
                animation: false,
                backgroundColor: progressTrack,
                progressColor: colorScheme.primary,
                barRadius: const Radius.circular(8),
              ),
              if (currentItem != null) ...[
                SizedBox(height: spacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentItem!,
                    style: typography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
