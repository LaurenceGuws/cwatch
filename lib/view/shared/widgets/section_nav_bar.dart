import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/view/core/navigation/window_controls_constants.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'window_drag_region.dart';

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
    this.enableWindowDrag = true,
  });

  final String title;
  final List<Widget> tabs;
  final TabController? controller;
  final bool showTitle;
  final Widget? leading;
  final Widget? trailing;
  final List<IconData>? tabIcons;
  final bool enableWindowDrag;

  @override
  Widget build(BuildContext context) {
    final hasTabs = tabs.isNotEmpty;
    final viewportWidth = MediaQuery.of(context).size.width;
    final compact = viewportWidth < 640;
    final showIconsOnly = compact;

    final bool useCustomChrome =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final rightPadding = useCustomChrome && enableWindowDrag
        ? WindowControlsConstants.totalWidth
        : 0.0;
    final dragGutterWidth = useCustomChrome && enableWindowDrag
        ? WindowControlsConstants.dragRegionWidth
        : 0.0;
    final tabBarHeight = useCustomChrome
        ? WindowControlsConstants.tabBarHeightFor(context)
        : context.scale(42.0);
    final verticalPadding = useCustomChrome
        ? 0.0
        : (compact ? context.scale(6.0) : context.scale(8.0));
    final spacing = context.appTheme.spacing;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      elevation: useCustomChrome ? 0 : 0.5,
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              if (useCustomChrome && enableWindowDrag)
                Positioned(
                  left: 0,
                  top: 0,
                  right: rightPadding,
                  bottom: 0,
                  child: const WindowDragRegion(child: SizedBox.expand()),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: useCustomChrome ? 0 : (compact ? 10 : 18),
                  right: useCustomChrome
                      ? rightPadding + dragGutterWidth
                      : (compact ? 10 : 18) + rightPadding + dragGutterWidth,
                  top: verticalPadding,
                  bottom: verticalPadding,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      Padding(
                        padding: EdgeInsets.only(right: spacing.sm),
                        child: leading!,
                      ),
                    ],
                    if (showTitle && title.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: hasTabs ? spacing.lg : 0),
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    if (hasTabs)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IntrinsicWidth(
                            child: SizedBox(
                              height: tabBarHeight,
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                padding: EdgeInsets.zero,
                                labelPadding: EdgeInsets.symmetric(
                                  horizontal: compact ? spacing.sm : spacing.md,
                                ),
                                controller: controller,
                                tabs:
                                    showIconsOnly &&
                                        tabIcons != null &&
                                        tabIcons!.length == tabs.length
                                    ? _buildIconTabs(context, tabs, tabIcons!)
                                    : tabs,
                                labelColor: scheme.primary,
                                unselectedLabelColor: scheme.onSurfaceVariant,
                                dividerColor: Colors.transparent,
                                overlayColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                      (states) => states.contains(WidgetState.hovered)
                                          ? scheme.primary.withValues(alpha: 0.06)
                                          : null,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    if (trailing != null) ...[
                      SizedBox(width: spacing.md),
                      trailing!,
                    ],
                  ],
                ),
              ),
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
    final bool useCustomChrome =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final tabHeight = useCustomChrome
        ? WindowControlsConstants.tabBarHeightFor(context)
        : context.scale(42.0);

    return List.generate(tabs.length, (index) {
      final tab = tabs[index];
      String? label;
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
