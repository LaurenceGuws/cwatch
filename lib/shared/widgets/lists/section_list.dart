import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SectionList extends StatelessWidget {
  const SectionList({
    super.key,
    required this.children,
    this.title,
    this.trailing,
    this.backgroundColor,
  });

  final List<Widget> children;
  final String? title;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appTheme.spacing;
    final cardColor = backgroundColor ?? scheme.surfaceContainerHigh;
    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.base,
                vertical: spacing.xs,
              ),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          if (title != null || trailing != null)
            Divider(height: 1, color: scheme.outlineVariant),
          ..._withDividers(context, children),
        ],
      ),
    );
  }

  List<Widget> _withDividers(BuildContext context, List<Widget> items) {
    final scheme = Theme.of(context).colorScheme;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(Divider(height: 1, color: scheme.outlineVariant));
      }
    }
    return result;
  }
}
