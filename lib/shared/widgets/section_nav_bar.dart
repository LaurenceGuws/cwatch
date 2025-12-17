import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/navigation/window_controls_constants.dart';

/// Tab data for SectionNavBar
class SectionTab {
  const SectionTab({required this.label, this.icon});

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
    // Only collapse to icons on narrow layouts (mobile-ish) to keep labels visible on desktop.
    final showIconsOnly = compact;

    // Add right padding and match height to window controls when custom chrome is enabled
    final bool useCustomChrome = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final rightPadding = useCustomChrome ? WindowControlsConstants.totalWidth : 0.0;
    // Match window controls height (32px) when custom chrome is enabled to eliminate dead space
    final tabBarHeight = useCustomChrome 
        ? WindowControlsConstants.height 
        : 42.0;
    // Reduce vertical padding when custom chrome is enabled to match button height
    final verticalPadding = useCustomChrome ? 0.0 : (compact ? 6.0 : 8.0);

    return Material(
      elevation: useCustomChrome ? 0 : 1,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: compact ? 8 : 16,
            right: (compact ? 8 : 16) + rightPadding,
            top: verticalPadding,
            bottom: verticalPadding,
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: tabBarHeight,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        controller: controller,
                        tabs:
                            showIconsOnly &&
                                tabIcons != null &&
                                tabIcons!.length == tabs.length
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
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIconTabs(
    BuildContext context,
    List<Widget> tabs,
    List<IconData> icons,
  ) {
    // Match window controls height when custom chrome is enabled
    final bool useCustomChrome = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final tabHeight = useCustomChrome 
        ? WindowControlsConstants.height 
        : 42.0;
    
    return List.generate(tabs.length, (index) {
      final tab = tabs[index];
      String? label;
      // Extract label from Tab widget if possible
      if (tab is Tab && tab.text != null) {
        label = tab.text;
      }

      return Tooltip(
        message: label ?? 'Tab ${index + 1}',
        child: Tab(icon: Icon(icons[index]), height: tabHeight),
      );
    });
  }
}
