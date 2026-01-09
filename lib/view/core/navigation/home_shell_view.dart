import 'package:flutter/material.dart';

import 'package:cwatch/model/services_infra/settings/app_settings_controller.dart';
import 'package:cwatch/model/shared/theme/app_theme.dart';
import 'home_shell_controller.dart';
import 'home_shell_state.dart';
import 'shell_module.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/sidebar.dart';
import 'widgets/window_controls.dart';
import 'widgets/window_controls_path_clipper.dart';

class HomeShellView extends StatelessWidget {
  const HomeShellView({
    required this.settingsController,
    required this.controller,
    required this.supportsCustomChrome,
    required this.ensurePageCached,
    required this.onShowSidebarOptions,
    required this.onDestinationSelected,
    required this.windowControls,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    super.key,
  });

  final AppSettingsController settingsController;
  final HomeShellController controller;
  final bool supportsCustomChrome;
  final void Function(BuildContext context, String destination)
  ensurePageCached;
  final ValueChanged<Offset> onShowSidebarOptions;
  final ValueChanged<String> onDestinationSelected;
  final Widget? windowControls;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final viewportWidth = MediaQuery.of(context).size.width;
    final viewportHeight = MediaQuery.of(context).size.height;
    final isPortrait = viewportHeight > viewportWidth;

    final modules = controller.moduleRegistry.modules;
    final primaryModules = modules.where((module) => module.isPrimary).toList();
    final secondaryModules = modules
        .where((module) => !module.isPrimary)
        .toList();

    ensurePageCached(context, controller.state.selectedDestination);

    final selectedIndex = _moduleIndex(
      modules,
      controller.state.selectedDestination,
    );
    final safeSelectedIndex = selectedIndex.clamp(
      0,
      (modules.length - 1).clamp(0, 9999),
    );

    final bool useCustomChrome =
        supportsCustomChrome &&
        !settingsController.settings.windowUseSystemDecorations;

    final bool showSidebar = !controller.state.sidebarCollapsed;
    Widget? navigationBar;
    Alignment navigationAlignment = Alignment.centerLeft;
    EdgeInsets contentPadding = EdgeInsets.zero;

    if (useCustomChrome) {
      contentPadding =
          contentPadding +
          EdgeInsets.only(top: WindowControls.height + spacing.base * 1.5);
    }

    if (showSidebar) {
      switch (controller.state.sidebarPlacement) {
        case SidebarPlacement.dynamic:
          if (isPortrait) {
            navigationBar = BottomNavBar(
              modules: modules,
              selected: controller.state.selectedDestination,
              onSelect: onDestinationSelected,
              onShowOptions: onShowSidebarOptions,
            );
            navigationAlignment = Alignment.bottomCenter;
            contentPadding = const EdgeInsets.only(bottom: BottomNavBar.height);
          } else {
            navigationBar = Sidebar(
              primaryModules: primaryModules,
              secondaryModules: secondaryModules,
              selected: controller.state.selectedDestination,
              onSelect: onDestinationSelected,
              onShowOptions: onShowSidebarOptions,
            );
            navigationAlignment = Alignment.centerLeft;
            contentPadding = EdgeInsets.only(left: Sidebar.width + spacing.xs);
          }
          break;
        case SidebarPlacement.left:
          navigationBar = Sidebar(
            primaryModules: primaryModules,
            secondaryModules: secondaryModules,
            selected: controller.state.selectedDestination,
            onSelect: onDestinationSelected,
            onShowOptions: onShowSidebarOptions,
          );
          navigationAlignment = Alignment.centerLeft;
          contentPadding = EdgeInsets.only(left: Sidebar.width + spacing.xs);
          break;
        case SidebarPlacement.right:
          navigationBar = Sidebar(
            primaryModules: primaryModules,
            secondaryModules: secondaryModules,
            selected: controller.state.selectedDestination,
            onSelect: onDestinationSelected,
            alignRight: true,
            onShowOptions: onShowSidebarOptions,
          );
          navigationAlignment = Alignment.centerRight;
          contentPadding = EdgeInsets.only(right: Sidebar.width + spacing.xs);
          break;
        case SidebarPlacement.bottom:
          navigationBar = BottomNavBar(
            modules: modules,
            selected: controller.state.selectedDestination,
            onSelect: onDestinationSelected,
            onShowOptions: onShowSidebarOptions,
          );
          navigationAlignment = Alignment.bottomCenter;
          contentPadding = const EdgeInsets.only(bottom: BottomNavBar.height);
          break;
      }
    }

    final content = Padding(
      padding: contentPadding,
      child: IndexedStack(
        key: const ValueKey('pages-indexed-stack'),
        index: safeSelectedIndex,
        children: modules
            .map(
              (module) =>
                  controller.state.pageCache.pageFor(module.id) ??
                  const SizedBox.shrink(),
            )
            .toList(),
      ),
    );

    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              minimum: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: controller.input.gesturesEnabled
                    ? onScaleStart
                    : null,
                onScaleUpdate: controller.input.gesturesEnabled
                    ? onScaleUpdate
                    : null,
                onScaleEnd: controller.input.gesturesEnabled
                    ? onScaleEnd
                    : null,
                child: controller.services.gestureDetectorFactory.wrap(
                  context,
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          if (useCustomChrome && windowControls != null)
                            Positioned.fill(
                              child: ClipPath(
                                clipper: const WindowControlsPathClipper(
                                  buttonWidth: WindowControls.totalWidth,
                                  buttonHeight: WindowControls.height,
                                ),
                                child: content,
                              ),
                            )
                          else
                            Positioned.fill(child: content),
                          if (navigationBar != null)
                            Align(
                              alignment: navigationAlignment,
                              child: navigationBar,
                            ),
                        ],
                      );
                    },
                  ),
                  enabled: controller.input.gesturesEnabled,
                ),
              ),
            ),
            if (windowControls != null)
              Positioned(top: 0, right: 0, child: windowControls!),
          ],
        ),
      ),
    );
  }

  int _moduleIndex(List<ShellModuleView> modules, String id) {
    if (modules.isEmpty) return 0;
    final index = modules.indexWhere((module) => module.id == id);
    return index == -1 ? 0 : index;
  }
}
