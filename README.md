# CWatch

Cross‑platform Flutter desktop app for managing servers, Docker, Kubernetes contexts, and remote files over SSH.

## Highlights
- **Servers**: SSH connectivity, resource panels, process tree, logs, and a remote file explorer with editor + cache.
- **Docker**: engine picker, remote context dashboards, resource lists, and container terminals.
- **Kubernetes**: context picker + dashboard views backed by the CLI (`kubectl`) service.
- **WSL (Windows only)**: WSL distribution views via `lib/modules/wsl/`.
- **Debug Logs**: in‑app log viewer for tracing SSH/Docker/K8s activity.
- **Terminal & Editor**: PTY-backed terminal tabs and a remote file editor with syntax detection and theme presets.

## Code Map
- `lib/core/` app bootstrap (`app_bootstrap.dart`), navigation shell, tab/workspace persistence.
- `lib/modules/` UI modules: `servers/`, `docker/`, `kubernetes/`, `wsl/`, `debug_logs/`, `settings/`.
- `lib/services/ssh/` SSH backends, vault/keys, host key handling, SFTP transfers, terminal sessions.
- `lib/shared/views/shared/tabs/` terminal/editor/file explorer tabs + shared dialogs.
- `assets/` theme presets and media used by terminal/editor UI.
- `packages/` patched deps: `xterm_patched`, `flutter_code_editor_patched`.

## Architecture (Phase 4)
- UI only talks to controllers/view-models.
- Controllers orchestrate services and call UI adapters for dialogs/snackbars/menus.
- Services contain domain logic only (no Flutter imports).
- Repositories encapsulate data access (filesystem, SSH, caches, config).
- UI adapters are the only layer touching Flutter UI APIs.
- Shared remains utilities and cross-cutting concerns.
- Global layer folders (no per-module nesting):
  - `lib/app/controllers/`
  - `lib/app/services/`
  - `lib/app/repositories/`
  - `lib/app/adapters/`
  - `lib/data/sources/`
  - `lib/data/models/`
  - `lib/ui/views/`
  - `lib/ui/widgets/`
  - `lib/ui/bindings/`

## SSH Backends
- **ProcessRemoteShellService**: uses system `ssh`/`scp` for command and file ops.
- **BuiltInRemoteShellService**: pure Dart SSH with vault‑backed keys, host key verification, and SFTP.

## Development
1) Install Flutter SDK.
2) `flutter pub get`
3) `flutter run -d <device>`
4) `flutter analyze` (required after each change)
5) `flutter test` or `flutter test --coverage`

Formatting: 2‑space indentation, trailing commas in widgets, and ordered imports (SDK → third‑party → project).
