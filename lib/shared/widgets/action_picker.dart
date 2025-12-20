import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lists/section_list.dart';
import 'lists/section_list_item.dart';

class ActionOption<T> {
  const ActionOption({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final T value;
}

class ActionPicker {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<ActionOption<T>> options,
    String cancelLabel = 'Close',
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final spacing = dialogContext.appTheme.spacing;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: SectionList(
              children: List.generate(options.length, (index) {
                final option = options[index];
                return SectionListItem(
                  stripeIndex: index,
                  title: option.title,
                  subtitle: option.subtitle,
                  leading: Icon(option.icon, color: scheme.primary),
                  onTap: () => Navigator.of(dialogContext).pop(option.value),
                );
              }),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: spacing.base),
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(cancelLabel),
              ),
            ),
          ],
        );
      },
    );
  }
}
