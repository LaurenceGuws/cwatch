import 'package:flutter/material.dart';

class SectionNavBar extends StatelessWidget {
  const SectionNavBar({
    super.key,
    required this.title,
    required this.tabs,
    this.controller,
    this.showTitle = true,
  });

  final String title;
  final List<Widget> tabs;
  final TabController? controller;
  final bool showTitle;

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
            mainAxisAlignment: hasTabs
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              if (showTitle && title.isNotEmpty)
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (hasTabs)
                Flexible(
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
            ],
          ),
        ),
      ),
    );
  }
}
