import 'package:flutter/material.dart';
import 'package:cwatch/shared/theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: spacing.xs),
            child,
          ],
        ),
      ),
    );
  }
}
