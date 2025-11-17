import 'package:flutter/material.dart';

class SectionNavBar extends StatelessWidget {
  const SectionNavBar({
    super.key,
    required this.title,
    required this.tabs,
    this.controller,
    this.showTitle = true,
    this.leading,
    this.trailing,
  });

  final String title;
  final List<Widget> tabs;
  final TabController? controller;
  final bool showTitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasTabs = tabs.isNotEmpty;
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                if (showTitle && title.isNotEmpty) const SizedBox(width: 8),
              ],
              if (showTitle && title.isNotEmpty)
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (hasTabs)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 42,
                      child: TabBar(
                        controller: controller,
                        tabs: tabs,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
