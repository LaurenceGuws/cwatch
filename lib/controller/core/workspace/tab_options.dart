import 'package:flutter/material.dart';

class TabChipOption {
  const TabChipOption({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.color,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool enabled;
  final Color? color;
}

class TabOptionsController extends ValueNotifier<List<TabChipOption>> {
  TabOptionsController([super.value = const []]);

  bool get isDisposed => _disposed;
  bool _disposed = false;

  void update(List<TabChipOption> options) {
    if (_disposed) {
      return;
    }
    value = options;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class CompositeTabOptionsController extends TabOptionsController {
  CompositeTabOptionsController([super.value = const []]);

  final List<TabChipOption> _baseOptions = [];
  final List<TabChipOption> _overlayOptions = [];

  void updateBase(List<TabChipOption> options) {
    _baseOptions
      ..clear()
      ..addAll(options);
    _refresh();
  }

  void updateOverlay(List<TabChipOption> options) {
    _overlayOptions
      ..clear()
      ..addAll(options);
    _refresh();
  }

  void _refresh() {
    if (isDisposed) {
      return;
    }
    value = List.unmodifiable([..._baseOptions, ..._overlayOptions]);
  }
}

class TabCloseWarning {
  const TabCloseWarning({
    required this.title,
    required this.message,
    this.confirmLabel = 'Close tab',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
}
