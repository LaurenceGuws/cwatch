import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'package:cwatch/view/shared/widgets/dashboard/dashboard_primitives.dart';

class StructuredDataTableHost extends StatelessWidget {
  const StructuredDataTableHost({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: DashboardSectionCard(
        title: title ?? 'Items',
        subtitle: subtitle,
        trailing: trailing,
        child: Padding(
          padding: EdgeInsets.only(top: spacing.xs),
          child: child,
        ),
      ),
    );
  }
}
