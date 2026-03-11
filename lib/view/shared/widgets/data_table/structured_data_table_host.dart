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

class StructuredDataTableFeedback extends StatelessWidget {
  const StructuredDataTableFeedback({
    super.key,
    required this.title,
    this.subtitle,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.loading = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return StructuredDataTableHost(
      title: title,
      subtitle: subtitle,
      padding: padding,
      child: DashboardFeedbackState(
        title: null,
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
        loading: loading,
      ),
    );
  }
}
