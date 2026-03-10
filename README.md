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

## Target Direction

The target is a reusable shell/framework layer plus removable feature modules.

Reusable shell/framework ownership should cover:
- tabbed workspace infrastructure
- generic tab hosts and shared workspace primitives
- reusable Flutter widgets and utility UI that are not feature-specific
- shared menus, lists, configuration scaffolding, and other non-feature-specific building blocks

Feature modules should own:
- feature-specific views and tab assembly
- feature-specific workflows and policies
- feature-specific dialog content and presentation helpers

Capability rule:
- system CLIs and host-config integration are optional convenience paths for power users
- missing Docker/Kubernetes/SSH CLIs should degrade feature availability and leave visible breadcrumbs, not be treated as app-fatal conditions
- batteries-included implementations, such as built-in SSH support, remain valid product paths

Strict shared-shell rule:
- each tabbed module must provide an initial placeholder tab as its default workspace state
- the shell enforces that contract
- the feature owns the placeholder tab UI and behavior
- the shell does not enforce a shared picker/list landing page

The shell should continue to make sense if SSH, Docker, Kubernetes, or WSL modules are removed. That boundary is now an explicit rewrite goal, not just an implied preference.

## Current Integration Direction

The next cleanup layer is integration smell cleanup.

That means:
- make shared shell elements visible as a real subsystem
- polish and reuse existing shell/shared surfaces instead of silently re-creating them
- keep local overrides explicit when a subsystem genuinely needs different behavior
- scope annotation/codegen work only around stable metadata, not active runtime behavior

Current first hotspot in that layer:
- tab chip / tab shell contract

Current follow-up doc:
- `docs/tab_shell_contract_todo.md`

Current next normalization direction:
- shared tab-shell adapter/helper for routine chip assembly and generic tab command contribution

Current implementation-ready follow-up:
- `docs/tab_shell_adapter_todo.md`

Current implementation checkpoint:
- WSL now uses the first shared tab-shell chip builder seam
- Kubernetes now uses the same seam for the routine options-controller case
- Docker now uses the same seam for picker restrictions and picker-only options
- Servers now use the same seam for host mapping, extra default options, and close warnings

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
- `docs/workspace_core_ownership_todo.md`: actionable workspace-core ownership backlog for the next dependency cleanup batch.
- `docs/explorer_ui_adapter_ownership_todo.md`: actionable explorer controller/adapter ownership backlog for the next dependency cleanup batch.
- `docs/server_wsl_binding_ownership_todo.md`: actionable server/WSL binding ownership backlog for the next dependency cleanup batch.
- `docs/ui_adapter_dialog_ownership_todo.md`: actionable UI-adapter dialog/content ownership backlog for the next dependency cleanup batch.
- `docs/tab_assembly_ownership_todo.md`: actionable tab-assembly ownership backlog for the next dependency cleanup batch.
- `docs/theme_registry_ownership_todo.md`: actionable shared-theme ownership backlog for the next dependency cleanup batch.
- `docs/feature_ui_adapter_ownership_todo.md`: actionable feature-specific UI adapter ownership backlog for the next dependency cleanup batch.
- `docs/composition_root_ownership_todo.md`: actionable composition/service ownership backlog for the next rewrite layer.
- `docs/settings_state_taxonomy_todo.md`: actionable settings/state taxonomy backlog for the next rewrite layer.
- `docs/testing_roadmap.md`: current testing backlog and rewrite-support testing priorities.
- `docs/integration_smell_foundations.md`: high-level scope for shell/shared integration smell cleanup.
- `docs/integration_smell_todo.md`: actionable integration-smell backlog for the next rewrite layer.
