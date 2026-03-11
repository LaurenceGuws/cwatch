import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'lists/section_list.dart';
import 'lists/selectable_list_item.dart';

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
          titlePadding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.lg,
            spacing.lg,
            spacing.sm,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            spacing.md,
            0,
            spacing.md,
            spacing.md,
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            spacing.md,
            0,
            spacing.md,
            spacing.md,
          ),
          title: Text(title),
          content: SizedBox(
            width: dialogContext.appTheme.dimensions.dialogMinWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SectionList(
                children: List.generate(options.length, (index) {
                  final option = options[index];
                  return SelectableListItem(
                    stripeIndex: index,
                    title: option.title,
                    subtitle: option.subtitle,
                    leading: Icon(option.icon, color: scheme.primary),
                    onTap: () => Navigator.of(dialogContext).pop(option.value),
                  );
                }),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(cancelLabel),
            ),
          ],
        );
      },
    );
  }
}
