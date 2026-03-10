# CWatch

Cross-platform Flutter desktop app for managing servers, Docker engines, Kubernetes contexts, remote files, and terminal/editor workspaces.

## Current Status

The repository is in an active cleanup and structural rewrite planning phase.

The current codebase is organized into `view`, `controller`, and `model` folders, but those layers are not cleanly separated yet. Treat the current structure as an implementation snapshot, not as a completed architecture.

Primary planning document:
- `docs/rewrite_foundations.md`

## Features
- Servers over SSH: host list, connectivity, resource panels, process tree, remote terminals, and remote file explorer flows.
- Docker: context selection, remote engine discovery, resource lists, overview/dashboard flows, and container terminal support.
- Kubernetes: context selection, dashboard/resource views, and CLI/API-backed data collection.
- WSL: Windows-only WSL views and shell support.
- Debug Logs: in-app log inspection for SSH, Docker, and Kubernetes activity.
- Shared Tabs: terminal, remote editor, file explorer, trash, and settings surfaces used across modules.

## Repository Map
- `lib/view/`: Flutter widgets, feature screens, app shell, shared tab UI, and feature workspace views.
- `lib/controller/`: controllers, UI adapters, workspace orchestration, feature bindings, and repositories.
- `lib/model/`: data models, domain services, infrastructure services, SSH/Kubernetes/file handling, and shared non-UI utilities.
- `assets/`: theme presets and other declared assets.
- `packages/`: patched dependencies (`xterm_patched`, `flutter_code_editor_patched`).
- `docs/`: active planning and analysis documents for the cleanup/rewrite effort.

## Architectural Reality

Today:
- feature entrypoints often construct services and manage orchestration directly
- UI and workflow logic are mixed in several large widgets
- settings act as a broad shared dependency surface
- infrastructure concerns and feature policy are not fully separated
- test coverage is currently inadequate for a large rewrite

This is the reason the repository is being documented and re-scoped before deeper refactors begin.

## Development
1. `flutter pub get`
2. `flutter run -d <device>`
3. `flutter analyze`
4. `flutter test`

## Working Conventions
- 2-space indentation.
- Prefer trailing commas in widget trees.
- Import order: SDK, third-party, project.
- Use snake_case for Dart filenames.
- Keep docs honest: if architecture changes, update the relevant planning documents in the same change.

## Related Documents
- `AGENTS.md`: repository-specific working rules.
- `docs/rewrite_foundations.md`: current high-level findings, focus areas, and work sequence.
- `docs/dependency_direction_todo.md`: actionable dependency cleanup backlog with done definitions per hotspot.
- `docs/shell_module_ownership_todo.md`: actionable shell/module ownership backlog for the next dependency cleanup batch.
- `docs/docker_workspace_ownership_todo.md`: actionable docker/workspace ownership backlog for the next dependency cleanup batch.
- `docs/testing_roadmap.md`: current testing backlog and rewrite-support testing priorities.
