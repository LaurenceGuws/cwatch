# terminal_library (patched)

Local copy of `terminal_library` 0.0.6 with selection+scroll fix:

- Anchor selection uses buffer cell offsets instead of viewport positions during drag+scroll, preventing the selection from sliding when scrolling.
- Patched files:
  - `lib/xterm_library/core/ui/render.dart`
  - `lib/xterm_library/core/ui/gesture/gesture_handler.dart`

Publish is disabled; this package is vendored for local overrides.
