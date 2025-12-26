import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StandardEmptyState extends StatelessWidget {
  const StandardEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final hasAction = actionLabel != null;
    return Center(
      child: Padding(
        padding: spacing.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48),
              SizedBox(height: spacing.md),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasAction) ...[
              SizedBox(height: spacing.lg),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
