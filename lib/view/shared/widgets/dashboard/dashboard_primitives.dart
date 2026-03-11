import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';

class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final surface = context.appTheme.section.surface;
    return Card(
      elevation: surface.elevation,
      margin: surface.margin,
      shape: RoundedRectangleBorder(borderRadius: surface.radius),
      child: Container(
        decoration: BoxDecoration(
          color: surface.background,
          borderRadius: surface.radius,
          border: Border.all(color: surface.borderColor),
        ),
        padding: surface.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: spacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class DashboardMetricCard extends StatelessWidget {
  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.width,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final surface = context.appTheme.section.surface;
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsets.all(spacing.md),
        decoration: BoxDecoration(
          color: surface.background,
          borderRadius: surface.radius,
          border: Border.all(color: surface.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: scheme.primary),
              SizedBox(width: spacing.base),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: spacing.xs),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardMetadataCard extends StatelessWidget {
  const DashboardMetadataCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final scheme = Theme.of(context).colorScheme;
    final surface = context.appTheme.section.surface;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: surface.background,
        borderRadius: surface.radius,
        border: Border.all(color: surface.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: EdgeInsets.only(top: spacing.xs),
              child: Icon(icon, size: context.appTheme.iconSizes.small),
            ),
            SizedBox(width: spacing.sm),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
