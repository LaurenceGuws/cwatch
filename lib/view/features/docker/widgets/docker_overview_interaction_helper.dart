import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:cwatch/controller/controllers/docker_overview_controller.dart';
import 'package:cwatch/model/models/docker_container.dart';
import 'package:cwatch/model/models/docker_image.dart';
import 'package:cwatch/model/models/docker_network.dart';
import 'package:cwatch/model/models/docker_volume.dart';
import 'package:cwatch/view/features/docker/widgets/docker_overview_action_state.dart';

class DockerOverviewInteractionHelper {
  const DockerOverviewInteractionHelper();

  void handleTabSurfacePointerDown({
    required int tabIndex,
    required PointerDownEvent event,
    required DockerOverviewController controller,
  }) {
    final primaryPointer =
        event.kind == PointerDeviceKind.touch ||
        (event.buttons & kPrimaryButton) != 0;
    if (!primaryPointer) {
      return;
    }
    final hardware = HardwareKeyboard.instance;
    if (hardware.isShiftPressed ||
        hardware.isControlPressed ||
        hardware.isMetaPressed) {
      return;
    }
    switch (tabIndex) {
      case 1:
        controller.clearContainerSelection();
        break;
      case 2:
        controller.clearSelection(controller.selectedImageKeys);
        break;
      case 3:
        controller.clearSelection(controller.selectedNetworkKeys);
        break;
      case 4:
        controller.clearSelection(controller.selectedVolumeKeys);
        break;
    }
  }

  bool handleContainerSecondaryTap({
    required DockerContainer container,
    required DockerOverviewController controller,
    required List<DockerContainer> containers,
    int? flatIndex,
  }) {
    if (controller.selectedContainerIds.contains(container.id)) {
      return true;
    }
    final resolvedIndex =
        flatIndex ??
        containers.indexWhere((item) => item.id == container.id);
    controller.selectSingleContainer(
      container.id,
      index: resolvedIndex >= 0 ? resolvedIndex : null,
    );
    return true;
  }

  bool handleImageSecondaryTap({
    required DockerImage image,
    required DockerOverviewController controller,
    required DockerOverviewActionState actionState,
  }) {
    final imageKey = actionState.imageKey(image);
    if (!controller.selectedImageKeys.contains(imageKey)) {
      controller.selectSingleKey(controller.selectedImageKeys, imageKey);
    }
    return true;
  }

  bool handleNetworkSecondaryTap({
    required DockerNetwork network,
    required DockerOverviewController controller,
    required DockerOverviewActionState actionState,
  }) {
    final networkKey = actionState.networkKey(network);
    if (!controller.selectedNetworkKeys.contains(networkKey)) {
      controller.selectSingleKey(controller.selectedNetworkKeys, networkKey);
    }
    return true;
  }

  bool handleVolumeSecondaryTap({
    required DockerVolume volume,
    required DockerOverviewController controller,
  }) {
    if (!controller.selectedVolumeKeys.contains(volume.name)) {
      controller.selectSingleKey(controller.selectedVolumeKeys, volume.name);
    }
    return true;
  }

  Future<void> handleComposeAction({
    required String project,
    required String action,
    required Future<void> Function(String project) openLogs,
    required Future<void> Function(String project, String action) runCommand,
  }) async {
    switch (action) {
      case 'logs':
        await openLogs(project);
        break;
      case 'restart':
      case 'up':
      case 'down':
        await runCommand(project, action);
        break;
    }
  }
}
