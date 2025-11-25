# CWatch

Cross‑platform Flutter app for managing servers, Docker resources, and remote files with built‑in SSH tooling.

## Features
- Docker dashboards: contexts, resource stats, logs, exec terminals.
- Server workspace: SSH connectivity, resource monitors, logs, trash, file explorer with remote editing/local cache.
- Settings: agents, SSH vault/keys, containers, security, debug logs.
- Shared UI scaffolding: tabbed engine/workspace layout, Nerd Fonts theming.

## Structure (lib/)
- `main.dart` – app entry.
- `models/` – settings, SSH hosts, Docker entities, workspace state.
- `services/` – Docker client, filesystem trash, logging, settings, SSH (remote shell, key store/vault, config, command logging, editor cache).
- `ui/`
  - `theme/` – app theme, Nerd Fonts.
  - `views/` – feature screens:
    - `docker/` – view + widgets (dashboards, engine picker, terminals, resources).
    - `servers/` – server lists, add dialogs, resource panels, trash.
    - `settings/` – settings tabs (agents, SSH, containers, security, debug, general).
    - `shared/` – workspace tabs (file explorer, remote editor, terminal, merge conflicts, icons, etc.).
  - `widgets/` – shared components (actions, lists, nav, progress dialogs).

## Terminal library patch
- Uses a vendored `terminal_library` with fixed selection‑while‑scrolling behavior: `packages/terminal_library_patched` (wired via `dependency_overrides` in `pubspec.yaml`).
- Patched files: `xterm_library/core/ui/render.dart`, `xterm_library/core/ui/gesture/gesture_handler.dart`; non‑bundled features (zmodem, paragraph cache) are removed.

## Development
1) Install Flutter SDK and dependencies.
2) `flutter pub get`
3) `flutter run -d <device>`
4) `flutter analyze` (clean with vendored package excluded from lint noise)

Optional: `tools/terminal_selection_demo` hosts a minimal repro for terminal selection behavior.
