import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:cwatch/model/shared/theme/app_theme.dart';

import '../settings/floating_settings_window.dart';

class ExplorerChromeScaffold extends StatelessWidget {
  const ExplorerChromeScaffold({
    super.key,
    required this.pathNavigator,
    required this.content,
    required this.showSettings,
    required this.settings,
    required this.onCloseSettings,
    required this.supportsDesktopDrop,
    required this.dropEnabled,
    required this.dropHover,
    required this.onDragEntered,
    required this.onDragUpdated,
    required this.onDragExited,
    required this.onDragDone,
  });

  final Widget pathNavigator;
  final Widget content;
  final bool showSettings;
  final Widget settings;
  final VoidCallback onCloseSettings;
  final bool supportsDesktopDrop;
  final bool dropEnabled;
  final bool dropHover;
  final ValueChanged<DropEventDetails> onDragEntered;
  final ValueChanged<DropEventDetails> onDragUpdated;
  final ValueChanged<DropEventDetails> onDragExited;
  final Future<void> Function(DropDoneDetails details) onDragDone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final dropOverlayColor = context.appTheme.list.selectedBackground.withValues(
      alpha: 0.35,
    );
    final hostedContent = supportsDesktopDrop
        ? DropTarget(
            enable: dropEnabled,
            onDragEntered: onDragEntered,
            onDragUpdated: onDragUpdated,
            onDragExited: onDragExited,
            onDragDone: onDragDone,
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                if (dropHover)
                  Container(
                    color: dropOverlayColor,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_file, size: 48),
                        SizedBox(height: spacing.md),
                        const Text('Drop files or folders to upload'),
                      ],
                    ),
                  ),
              ],
            ),
          )
        : content;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: pathNavigator,
            ),
            Expanded(child: hostedContent),
          ],
        ),
        if (showSettings)
          FloatingSettingsWindow(
            title: 'Explorer Settings',
            onClose: onCloseSettings,
            child: settings,
          ),
      ],
    );
  }
}
