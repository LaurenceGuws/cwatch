import 'package:flutter/material.dart';

/// Reusable settings section widget
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        description != null && description!.trim().isNotEmpty;
    final iconColor = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (hasDescription)
                  Tooltip(
                    message: description!,
                    preferBelow: false,
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
