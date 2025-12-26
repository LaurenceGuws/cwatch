import 'package:flutter/material.dart';
import 'package:cwatch/shared/theme/app_theme.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: spacing.md),
              Text(message),
              SizedBox(height: spacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
