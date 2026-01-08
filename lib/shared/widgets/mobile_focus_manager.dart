import 'package:flutter/widgets.dart';

/// Small helper for terminal-like widgets on mobile.
///
/// On iOS/Android we often want to:
/// - allow tap-to-focus to open the keyboard
/// - temporarily suppress focus during pinch/gesture interactions
/// - avoid keeping focus when the user dismisses the keyboard
class MobileFocusManager {
  MobileFocusManager({required FocusNode focusNode, required bool isMobile})
    : _focusNode = focusNode,
      _isMobile = isMobile;

  final FocusNode _focusNode;
  final bool _isMobile;

  bool _suppressFocus = false;
  VoidCallback? _listener;

  void attach() {
    if (_listener != null) return;
    _listener = () {
      if (_isMobile && !_focusNode.hasFocus) {
        _focusNode.canRequestFocus = false;
      }
    };
    _focusNode.addListener(_listener!);
  }

  void detach() {
    final listener = _listener;
    if (listener == null) return;
    _focusNode.removeListener(listener);
    _listener = null;
  }

  void enableFocus() {
    if (!_isMobile || _suppressFocus) return;
    _focusNode.canRequestFocus = true;
    _focusNode.requestFocus();
  }

  void beginGestureBlock() {
    if (!_isMobile) return;
    _suppressFocus = true;
    _focusNode.unfocus();
    _focusNode.canRequestFocus = false;
  }

  void endGestureBlock() {
    if (!_isMobile) return;
    _suppressFocus = false;
    _focusNode.canRequestFocus = true;
  }
}
