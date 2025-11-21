import 'package:flutter/material.dart';

/// Tab data for SectionNavBar
class SectionTab {
  const SectionTab({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;
}

class SectionNavBar extends StatelessWidget {
  const SectionNavBar({
    super.key,
    required this.title,
    required this.tabs,
    this.controller,
    this.showTitle = true,
    this.leading,
    this.trailing,
    this.tabIcons,
  });

  final String title;
  final List<Widget> tabs;
  final TabController? controller;
  final bool showTitle;
  final Widget? leading;
  final Widget? trailing;
  final List<IconData>? tabIcons;

  @override
  Widget build(BuildContext context) {
    final hasTabs = tabs.isNotEmpty;
    final viewportWidth = MediaQuery.of(context).size.width;
    final compact = viewportWidth < 640;
    // Switch to icons earlier to prevent text cutoff (especially "Kubernetes")
    // Use a higher breakpoint so icons show before text gets truncated
    final showIconsOnly = viewportWidth < 1000; // Show icons only on small/medium screens
    
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 6 : 8,
          ),
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
                        isScrollable: true,
                        controller: controller,
                        tabs: showIconsOnly && tabIcons != null && tabIcons!.length == tabs.length
                            ? _buildIconTabs(context, tabs, tabIcons!)
                            : tabs,
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

  List<Widget> _buildIconTabs(BuildContext context, List<Widget> tabs, List<IconData> icons) {
    return List.generate(tabs.length, (index) {
      final tab = tabs[index];
      String? label;
      // Extract label from Tab widget if possible
      if (tab is Tab && tab.text != null) {
        label = tab.text;
      }
      
      return Tooltip(
        message: label ?? 'Tab ${index + 1}',
        child: Tab(
          icon: Icon(icons[index]),
          height: 42,
        ),
      );
    });
  }
}
