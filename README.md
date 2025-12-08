# CWatch

Cross‑platform Flutter app for managing servers, Docker resources, and remote files with built‑in SSH tooling.

## Highlights
- Docker: engine picker, context dashboards, resource stats, container exec, compose logs.
- Servers: SSH connectivity, resource monitors, process tree, logs, trash, remote file explorer with editing/cache.
- Terminals: PTY sessions (local or SSH), patched terminal library for stable selection.
- Settings: agents, SSH vault/keys, container defaults, security, debug logs.
- UI shell: tabbed workspace layout, Nerd Fonts theming, shared widgets and dialogs.

## Code Map (lib/)
- `models/` – settings, workspace state, Docker/SSH entities.
- `services/`
  - SSH: `remote_shell_base.dart`, process client, built‑in client/vault, config parsing, command logging, editor cache.
  - Docker: client, engine services, container shells.
  - Other: logging, settings, filesystem trash.
- `modules/`
  - `docker/` – view + widgets (dashboards, lists, terminals, resource panes).
  - `servers/` – server lists, dialogs, resource panels.
  - `settings/` – settings tabs and sections.
  - `kubernetes/` – kube context helpers.
- `shared/` – tabbed workspace UI (file explorer, editor, terminal, dialogs, theme).
- `core/` – navigation, workspace persistence/tracking, app bootstrap.
- `packages/terminal_library_patched/` – vendored terminal lib with scrolling/selection fixes (via `dependency_overrides`).

## SSH Implementations
- **ProcessRemoteShellService**: wraps system `ssh/scp`; good for environments with native SSH.
- **BuiltInRemoteShellService**: pure Dart SSH (dartssh2) with vault-backed keys; supports SFTP upload/download and terminal sessions. Key unlock prompts can be wired via the built‑in key service.

## Development
1) Install Flutter SDK and deps.
2) `flutter pub get`
3) `flutter run -d <device>`
4) `flutter analyze`
5) `flutter test` (use `--coverage` to mirror CI expectations)

Formatting: Flutter defaults (2 spaces, trailing commas). Keep imports ordered (SDK → third‑party → project). 

## Notes
- Terminal patches live in `packages/terminal_library_patched` (`xterm_library/core/ui/render.dart`, `xterm_library/core/ui/gesture/gesture_handler.dart`); optional repro in `tools/terminal_selection_demo`.
- Workspace/tab state is persisted; see `core/workspace/` for persistence behavior.
