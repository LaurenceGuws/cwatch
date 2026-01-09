# CWatch

Cross‑platform Flutter desktop app for managing servers, Docker, Kubernetes contexts, and remote files over SSH.

## Highlights
- **Servers**: SSH connectivity, resource panels, process tree, logs, and a remote file explorer with editor + cache.
- **Docker**: engine picker, remote context dashboards, resource lists, and container terminals.
- **Kubernetes**: context picker + dashboard views backed by the CLI (`kubectl`) service.
- **WSL (Windows only)**: WSL distribution views via `lib/view/features/wsl/`.
- **Debug Logs**: in‑app log viewer for tracing SSH/Docker/K8s activity.
- **Terminal & Editor**: PTY-backed terminal tabs and a remote file editor with syntax detection and theme presets.

## Code Map
- `lib/view/app/` app bootstrap (`app_bootstrap.dart`), navigation shell (`app_shell.dart`).
- `lib/view/features/` UI modules: `servers/`, `docker/`, `kubernetes/`, `wsl/`, `debug_logs/`, `settings/`.
- `lib/view/shared/` shared widgets and tab components (terminal, editor, file explorer).
- `lib/controller/` controllers, UI adapters, DI bindings, repositories.
  - `controllers/` state management (ChangeNotifier-based).
  - `adapters/` UI adapters for dialogs, snackbars, menus.
  - `di/bindings/` dependency injection bindings.
  - `repositories/` data access layer.
- `lib/model/` domain models, services, and infrastructure.
  - `models/` data models (SSH hosts, Docker containers, K8s resources, etc.).
  - `services/` domain services (file operations, explorer ops, etc.).
  - `services_infra/` infrastructure services (SSH, logging, settings, etc.).
    - `ssh/` SSH backends, vault/keys, host key handling, SFTP transfers, terminal sessions.
  - `shared/` cross-cutting utilities (themes, shortcuts, gestures).
- `assets/` theme presets and media used by terminal/editor UI.
- `packages/` patched deps: `xterm_patched`, `flutter_code_editor_patched`.

## Architecture
- **UI Layer** (`lib/view/`): Flutter widgets and views. Only communicates with controllers.
- **Controller Layer** (`lib/controller/`): State management and orchestration.
  - Controllers extend `ChangeNotifier` for reactive state.
  - Controllers orchestrate services and call UI adapters for dialogs/snackbars/menus.
  - UI adapters are the only layer touching Flutter UI APIs (`BuildContext`, dialogs, etc.).
- **Model Layer** (`lib/model/`): Domain logic and data.
  - Services contain pure domain logic (no Flutter imports).
  - Repositories encapsulate data access (filesystem, SSH, caches, config).
  - Models are plain data classes.
- **Shared** (`lib/model/shared/`): Cross-cutting utilities (themes, shortcuts, gestures).

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
