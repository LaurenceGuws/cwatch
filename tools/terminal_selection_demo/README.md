# Terminal Selection Demo

Minimal Flutter app to reproduce the selection + scroll behavior in `terminal_library`.

## Run

```
cd tools/terminal_selection_demo
flutter pub get
flutter run -d linux   # or macos / windows
```

## What to try

1. Start a selection with mouse drag.
2. Keep the button held and scroll with the wheel.
3. Observe whether the selection extends (expected) or moves with the pointer (buggy).

The demo intentionally disables our app-specific selection code so we can see the upstream behavior in isolation.
