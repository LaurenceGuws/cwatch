// ignore_for_file: implementation_imports, use_build_context_synchronously

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:super_clipboard/super_clipboard.dart' as sc;
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as sdd;
import 'package:super_drag_and_drop/src/into_raw.dart';
import 'package:super_native_extensions/raw_drag_drop.dart'
    show DragContext, TargetedWidgetSnapshot, WidgetSnapshot;

import '../../../../../services/logging/app_logger.dart';
import 'drag_types.dart';

/// Platform interface for starting OS-native drag sessions.
abstract class DesktopDragSource {
  /// Returns true when the platform supports starting drag sessions.
  bool get isSupported;

  /// Begin a drag session for the provided local payloads.
  ///
  /// Implementations should stage files as needed and initiate the native
  /// drag loop. The returned result indicates whether the OS drag actually
  /// started; it does not imply a successful drop.
  Future<DragStartResult> startDrag({
    required BuildContext context,
    required Offset globalPosition,
    required List<DragLocalItem> items,
  });
}

DesktopDragSource createDesktopDragSource() {
  if (Platform.isLinux) {
    return LinuxDragSource();
  }
  if (Platform.isWindows) {
    return WindowsDragSource();
  }
  if (Platform.isMacOS) {
    return UnsupportedDragSource();
  }
  return UnsupportedDragSource();
}

/// Windows implementation using super_drag_and_drop to start a native drag loop.
class WindowsDragSource implements DesktopDragSource {
  @override
  bool get isSupported => true;

  @override
  Future<DragStartResult> startDrag({
    required BuildContext context,
    required Offset globalPosition,
    required List<DragLocalItem> items,
  }) async {
    if (items.isEmpty) {
      return const DragStartResult(started: false, error: 'No items to drag');
    }
    try {
      final dragContext = await DragContext.instance();
      final session = dragContext.newSession();
      if (!context.mounted) {
        return const DragStartResult(
          started: false,
          error: 'Context unmounted before drag started',
        );
      }
      final view = ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first
          : null;
      final devicePixelRatio =
          view?.devicePixelRatio ??
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ??
          1.0;
      final placeholderColor = Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.8);
      final configItems = await _buildConfigItems(
        globalPosition,
        items,
        devicePixelRatio,
        placeholderColor,
      );
      if (!context.mounted) {
        return const DragStartResult(
          started: false,
          error: 'Context unmounted before drag started',
        );
      }
      final configuration = sdd.DragConfiguration(
        items: configItems,
        allowedOperations: [sdd.DropOperation.copy, sdd.DropOperation.move],
      );
      final rawConfig = await configuration.intoRaw(devicePixelRatio);
      await dragContext.startDrag(
        buildContext: context,
        session: session,
        configuration: rawConfig,
        position: globalPosition,
      );
      return const DragStartResult(started: true);
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to start desktop drag session',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      return DragStartResult(started: false, error: error.toString());
    }
  }

  Future<List<sdd.DragConfigurationItem>> _buildConfigItems(
    Offset globalPosition,
    List<DragLocalItem> items,
    double devicePixelRatio,
    Color placeholderColor,
  ) async {
    final image = await _placeholderImage(devicePixelRatio, placeholderColor);
    final snapshot = WidgetSnapshot.image(image);
    final rect = Rect.fromLTWH(
      globalPosition.dx,
      globalPosition.dy,
      image.pointWidth,
      image.pointHeight,
    );
    final targeted = TargetedWidgetSnapshot(snapshot, rect);

    return items
        .map(
          (item) => sdd.DragConfigurationItem(
            item: sdd.DragItem(suggestedName: item.displayName)
              ..add(sc.Formats.fileUri(Uri.file(item.localPath))),
            image: targeted.retain(),
          ),
        )
        .toList();
  }

  Future<ui.Image> _placeholderImage(
    double devicePixelRatio,
    Color placeholderColor,
  ) async {
    final size = (20 * devicePixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = placeholderColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        const Radius.circular(2),
      ),
      paint,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    image.devicePixelRatio = devicePixelRatio;
    return image;
  }
}

/// Linux implementation using super_drag_and_drop to start a native drag loop.
class LinuxDragSource implements DesktopDragSource {
  @override
  bool get isSupported => true;

  @override
  Future<DragStartResult> startDrag({
    required BuildContext context,
    required Offset globalPosition,
    required List<DragLocalItem> items,
  }) async {
    if (items.isEmpty) {
      return const DragStartResult(started: false, error: 'No items to drag');
    }
    try {
      final dragContext = await DragContext.instance();
      final session = dragContext.newSession();
      if (!context.mounted) {
        return const DragStartResult(
          started: false,
          error: 'Context unmounted before drag started',
        );
      }
      final view = ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first
          : null;
      final devicePixelRatio =
          view?.devicePixelRatio ??
          ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ??
          1.0;
      final placeholderColor = Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.8);
      final configItems = await _buildConfigItems(
        globalPosition,
        items,
        devicePixelRatio,
        placeholderColor,
      );
      if (!context.mounted) {
        return const DragStartResult(
          started: false,
          error: 'Context unmounted before drag started',
        );
      }
      final configuration = sdd.DragConfiguration(
        items: configItems,
        allowedOperations: [sdd.DropOperation.copy, sdd.DropOperation.move],
      );
      final rawConfig = await configuration.intoRaw(devicePixelRatio);
      await dragContext.startDrag(
        buildContext: context,
        session: session,
        configuration: rawConfig,
        position: globalPosition,
      );
      return const DragStartResult(started: true);
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to start desktop drag session',
        tag: 'Explorer',
        error: error,
        stackTrace: stackTrace,
      );
      return DragStartResult(started: false, error: error.toString());
    }
  }

  Future<List<sdd.DragConfigurationItem>> _buildConfigItems(
    Offset globalPosition,
    List<DragLocalItem> items,
    double devicePixelRatio,
    Color placeholderColor,
  ) async {
    final image = await _placeholderImage(devicePixelRatio, placeholderColor);
    final snapshot = WidgetSnapshot.image(image);
    final rect = Rect.fromLTWH(
      globalPosition.dx,
      globalPosition.dy,
      image.pointWidth,
      image.pointHeight,
    );
    final targeted = TargetedWidgetSnapshot(snapshot, rect);

    return items
        .map(
          (item) => sdd.DragConfigurationItem(
            item: sdd.DragItem(suggestedName: item.displayName)
              ..add(sc.Formats.fileUri(Uri.file(item.localPath))),
            image: targeted.retain(),
          ),
        )
        .toList();
  }

  Future<ui.Image> _placeholderImage(
    double devicePixelRatio,
    Color placeholderColor,
  ) async {
    final size = (20 * devicePixelRatio).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = placeholderColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        const Radius.circular(2),
      ),
      paint,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    image.devicePixelRatio = devicePixelRatio;
    return image;
  }
}

/// Fallback for platforms without an implementation yet.
class UnsupportedDragSource implements DesktopDragSource {
  @override
  bool get isSupported => false;

  @override
  Future<DragStartResult> startDrag({
    required BuildContext context,
    required Offset globalPosition,
    required List<DragLocalItem> items,
  }) async {
    return const DragStartResult(
      started: false,
      error: 'Drag source not supported on this platform',
    );
  }
}
