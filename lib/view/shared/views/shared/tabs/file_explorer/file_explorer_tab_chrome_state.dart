import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cwatch/controller/controllers/file_explorer_controller.dart';
import 'package:cwatch/controller/core/workspace/tab_options.dart';

class FileExplorerTabChromeState {
  FileExplorerTabChromeState({
    required this.controller,
    required this.showSettings,
    required this.onToggleSettings,
    required this.onUploadFiles,
    required this.onUploadFolder,
    required this.onOpenTrash,
    required this.onOpenTerminalTab,
  });

  final FileExplorerController controller;
  final bool Function() showSettings;
  final VoidCallback onToggleSettings;
  final ValueChanged<String> onUploadFiles;
  final ValueChanged<String> onUploadFolder;
  final VoidCallback onOpenTrash;
  final ValueChanged<String>? onOpenTerminalTab;

  bool dropHover = false;

  bool shouldIgnoreDropHover() {
    return controller.isOsDragActive ||
        controller.isSelfDragTarget(controller.currentPath);
  }

  bool handleDropEntered() {
    if (shouldIgnoreDropHover()) {
      return false;
    }
    if (!dropHover) {
      dropHover = true;
      return true;
    }
    return false;
  }

  bool handleDropUpdated() {
    if (shouldIgnoreDropHover()) {
      return false;
    }
    if (!dropHover) {
      dropHover = true;
      return true;
    }
    return false;
  }

  bool handleDropExited() {
    if (shouldIgnoreDropHover()) {
      return false;
    }
    if (dropHover) {
      dropHover = false;
      return true;
    }
    return false;
  }

  bool clearDropHover() {
    if (!dropHover) {
      return false;
    }
    dropHover = false;
    return true;
  }

  void updateTabOptions(TabOptionsController controllerOptions) {
    final options = <TabChipOption>[
      TabChipOption(
        label: 'Upload files…',
        icon: Icons.upload_file,
        onSelected: () => onUploadFiles(controller.currentPath),
      ),
      TabChipOption(
        label: controller.state.searchActive ? 'Hide search' : 'Show search',
        icon: controller.state.searchActive ? Icons.search_off : Icons.search,
        onSelected: () {
          unawaited(
            controller.setSearchActive(!controller.state.searchActive),
          );
        },
      ),
      TabChipOption(
        label: 'Upload folder…',
        icon: Icons.folder,
        onSelected: () => onUploadFolder(controller.currentPath),
      ),
      TabChipOption(
        label: 'Open trash',
        icon: Icons.delete_outline,
        onSelected: onOpenTrash,
      ),
    ];
    if (onOpenTerminalTab != null) {
      options.add(
        TabChipOption(
          label: 'Open terminal here',
          icon: Icons.terminal,
          onSelected: () => onOpenTerminalTab!(controller.currentPath),
        ),
      );
    }
    options.add(
      TabChipOption(
        label: showSettings() ? 'Hide settings' : 'Settings',
        icon: Icons.settings,
        onSelected: onToggleSettings,
      ),
    );
    if (controllerOptions is CompositeTabOptionsController) {
      controllerOptions.updateBase(options);
    } else {
      controllerOptions.update(options);
    }
  }
}
