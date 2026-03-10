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
Status: queued

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
