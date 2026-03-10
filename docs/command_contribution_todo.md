# Command Contribution TODO

Status: active
Purpose: define the shared shell contract for command palette contribution so feature modules stop re-creating routine command-entry plumbing while keeping domain-specific commands feature-owned.

## Why This Exists

The current integration-smell checkpoints are strong enough now:
- tab shell is explicit and checkpointed
- dialog/settings scaffolding is explicit and checkpointed
- SSH auth ownership is at a good checkpoint
- explorer shared surface is explicit and checkpointed
- shared list/menu/settings scaffolding is explicit and checkpointed
- annotation/codegen is at a good checkpoint

That means the next useful shell-facing hotspot is:
- command contribution integration

The repo already has shared command-palette infrastructure:
- `CommandPaletteRegistry`
- `CommandPaletteHandle`
- `HomeShellCommandPalette`
- `showCommandPalette(...)`

The current smell is not missing infrastructure.

It is:
- feature modules still hand-assemble routine command entries
- generic module/tab command contribution rules are not explicit
- the shared registry exists, but the contribution contract is still loose

## Current Shared Surface

Current shared command infrastructure:
- [command_palette_registry.dart](/home/home/personal/cwatch/lib/view/core/navigation/command_palette_registry.dart)
- [home_shell_command_palette.dart](/home/home/personal/cwatch/lib/view/core/navigation/home_shell_command_palette.dart)
- [command_palette.dart](/home/home/personal/cwatch/lib/view/shared/widgets/command_palette.dart)

Representative feature-local contribution sites:
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [settings_view.dart](/home/home/personal/cwatch/lib/view/features/settings/settings/settings_view.dart)

## Current Integration Smells In This Hotspot

### 1. Shared registry exists, but contribution shape is still feature-local

Each feature can register a `CommandPaletteHandle`, but the actual entry-building logic is still mostly hand-wired inside the feature view.

That means:
- generic “open tab”, “switch section”, or “jump to current surface” patterns may be repeated
- the shell has infrastructure, but not a clear contribution contract

### 2. Generic contribution and domain contribution are not separated enough

Some commands are feature-specific and should stay local.

Some commands are structurally generic:
- open a placeholder/picker action
- jump to a section
- expose obvious current-surface actions

Those two categories need to be separated explicitly.

### 3. This should not become a command framework rewrite

The next pass should not try to:
- generate all commands
- unify every feature command shape
- merge command palette, context menus, and tab actions into one abstraction

It should only define:
- shared command contribution rules
- the first narrow repeated command-entry seam worth normalizing

## Task 14.52: choose the next integration-smell hotspot after shared scaffolding
Status: completed

Goal:
- choose the next hotspot after the shared scaffolding checkpoint

Candidates considered:
- command palette / command contribution integration
- capability / breadcrumb integration surfacing
- stop the integration-smell layer and roll up checkpoints

Result:
- the next hotspot is `command contribution integration`

Why this wins:
- shared command-palette infrastructure already exists
- duplicated feature-local command contribution is a clearer active smell than capability surfacing right now
- this also reconnects to the earlier queued tab-shell follow-up around generic tab command contribution, but at the broader command-system boundary where it belongs

Why the other candidates wait:
- capability / breadcrumb integration
  - important, but still more distributed and less ready for a clean first normalization pass
- stop the layer entirely
  - premature; command contribution is the next clear shared-shell seam

## Task 14.53: define the shared command contribution contract
Status: completed

Goal:
- describe what the shell owns in command contribution infrastructure and what feature modules own in actual command definitions

Actions:
- audit current registry and feature loaders
- separate generic contribution patterns from domain-specific commands
- identify the first narrow normalization seam after the contract is written

Done definition:
- shared command contribution responsibilities are explicit
- feature-owned command responsibilities are explicit
- one concrete normalization batch is chosen

Result:
- the shared command contribution contract is now explicit around:
  - `CommandPaletteRegistry`
  - `CommandPaletteHandle`
  - `HomeShellCommandPalette`
  - feature-local module entry loaders

### Shared shell responsibilities

The shared command infrastructure should own:
- command palette registry and handle lifecycle
- shell-global command entries such as navigation and chrome controls
- generic command-entry shaping for repeated shell-owned patterns

### Feature responsibilities

Feature modules should own:
- domain-specific command labels and handlers
- availability checks tied to feature state
- richer commands that depend on domain-specific workflow logic
- module-specific section navigation entries where that navigation is part of the feature surface

### Current repeated integration smell

The clearest repeated feature-local command assembly is generic tab command contribution:
- tab option entries from `tab.optionsController`
- `Close tab`
- `New tab`
- sometimes `Rename tab`

Current concrete repeated cases:
- `docker_view.dart`
- `server_workspace_view.dart`
- `kubernetes_context_list.dart`

This is a better first seam than normalizing all feature command loaders because:
- it is already structurally shared
- it maps directly to the earlier queued tab-shell command follow-up
- it avoids flattening feature-specific settings/section commands

### Explicitly deferred

- settings tab-switching command entries
- feature-specific picker/open-host/open-context command entries
- command palette generation from annotations
- command/context-menu unification

## Task 14.54: scope generic tab command contribution normalization
Status: completed

Goal:
- define the smallest shared helper for repeated tab command entries without swallowing feature-specific command loaders

First code targets:
- `docker_view.dart`
- `server_workspace_view.dart`
- `kubernetes_context_list.dart`

Done definition:
- the first generic tab-command normalization batch is chosen
- the helper stays narrower than a full command framework

Result:
- the first normalization batch should target a shared helper for:
  - tab option entries from `tab.optionsController`
  - `Close tab`
  - `New tab`
  - optional `Rename tab`

### Why this is the right cut

- Docker and Servers share the full pattern:
  - tab options
  - rename
  - close
  - new
- Kubernetes shares the same pattern minus rename
- that means the helper can stay narrow and support optional rename rather than forcing a uniform feature command set

### First code targets

- `docker_view.dart`
- `server_workspace_view.dart`
- `kubernetes_context_list.dart`

### Explicitly deferred

- settings tab-switch commands
- feature-specific picker/open-host/open-context commands
- non-tab module commands
- command generation from metadata

## Task 14.55: implement shared generic tab command contribution
Status: completed

Goal:
- extract the repeated generic tab command entry assembly into a shared shell helper without touching feature-specific command entries

Done definition:
- Docker, Servers, and Kubernetes use one shared helper for the generic tab-command portion of their command loaders
- rename remains optional
- feature-specific command entries stay local

Result:
- [generic_tab_command_entries.dart](/home/home/personal/cwatch/lib/view/core/navigation/generic_tab_command_entries.dart) now exists as the shared shell helper for generic tab command entries
- the helper is adopted in:
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)

What this proved:
- generic tab command contribution is a real shared shell seam
- optional rename support was the correct boundary
- feature-specific command entries can stay local without duplicating the generic tab-entry boilerplate

## Task 14.56: re-scope the next command contribution batch
Status: completed

Goal:
- decide whether the next command batch should normalize another generic seam or checkpoint this hotspot

Likely candidates:
- settings tab-switch command contributions
- checkpoint the command hotspot and leave richer feature loaders local

Done definition:
- the next narrow command batch is chosen or the hotspot is checkpointed

Result:
- the command contribution hotspot is now at a good checkpoint
- the next batch should not extract a new helper just for settings tab-switch commands

Why this is the right stop point:
- the generic tab-command seam had multiple real adopters and is now shared
- the remaining obvious candidate is `settings_view.dart`, but that is only one surface
- extracting a second helper now would likely create abstraction ahead of evidence

What remains intentionally local:
- settings tab-switch commands
- feature-specific picker/open-host/open-context commands
- richer feature-local command loaders

Current checkpoint summary:
- `CommandPaletteRegistry` and `HomeShellCommandPalette` remain the shared registry/loading substrate
- `generic_tab_command_entries.dart` is now the canonical shared helper for repeated tab command entries
- feature-local loaders remain the right place for domain-specific commands

## Task 14.57: choose the next integration-smell hotspot after command contribution
Status: queued

Goal:
- decide the next integration-smell layer after the command contribution checkpoint

Likely candidates:
- capability / breadcrumb integration surfacing
- checkpoint the integration-smell layer and roll up the current state

Done definition:
- the next hotspot is chosen from current evidence
