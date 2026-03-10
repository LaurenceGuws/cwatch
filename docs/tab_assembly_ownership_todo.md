# Tab Assembly Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around controller-owned tab builders that still assemble concrete view widgets.

## How To Use This Document

This is the next actionable TODO after the UI-adapter dialog/content checkpoint.

Use it to:
- define the current tab-assembly ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining `controller -> view` imports are now concentrated in controller-owned tab builders:
- `ServerTabBuilder` assembles concrete shared tabs and server feature widgets
- `WslTabBuilder` assembles the shared terminal tab

This is different from earlier hotspots. These imports may be legitimate if tab builders are intentionally the composition layer for tab bodies, but that ownership rule is not yet explicit.

## Current Signal From The Codebase

Representative files:
- `lib/controller/controllers/server_tab_builder.dart`
- `lib/controller/controllers/wsl_tab_builder.dart`
- `lib/view/features/servers/server_workspace_view.dart`
- `lib/view/features/wsl/wsl_view.dart`

Representative imported view-side types:
- `lib/view/shared/views/shared/tabs/terminal/terminal_tab.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart`
- `lib/view/shared/views/shared/tabs/trash_tab.dart`
- `lib/view/shared/views/shared/tabs/editor/remote_file_editor_loader.dart`
- `lib/view/features/servers/widgets/connectivity_tab.dart`
- `lib/view/features/servers/widgets/resources_tab.dart`

Current symptoms:
- `ServerTabBuilder` and `WslTabBuilder` are now controller-owned, but they still construct concrete widget bodies directly
- that can be reasonable if these builders are treated as composition objects rather than non-UI logic
- right now the repo does not clearly state whether this is an intentional boundary or a remaining ownership issue

## What We Are Trying To Improve

We are not trying to eliminate controller-owned tab construction blindly.

We are trying to answer one ownership question clearly:
- should controller-owned tab builders be allowed to assemble concrete tab widgets, or should tab assembly move back behind a view-owned or narrower factory boundary?

## Working Rules For This Hotspot
- do not force a fake abstraction if widget assembly is genuinely the builder's job
- prefer documenting an explicit boundary if the current shape is acceptable
- if a move is needed, choose the smallest viable seam rather than rewriting all tab builders
- re-scope after the first batch lands

## First Batch Candidate

### Task 8.1: inspect WSL tab assembly ownership
Status: queued

Why this is first:
- `WslTabBuilder` is much smaller than `ServerTabBuilder`
- it isolates the core question with one shared widget dependency (`TerminalTab`)
- it should tell us whether controller-owned tab assembly is acceptable as a composition boundary before touching the heavier server builder

Current files in scope:
- `lib/controller/controllers/wsl_tab_builder.dart`
- `lib/view/features/wsl/wsl_view.dart`
- `lib/view/shared/views/shared/tabs/terminal/terminal_tab.dart`
- any directly related types needed to clarify the boundary

Actions:
- inspect what `WslTabBuilder` really owns versus what the WSL view owns
- decide whether `WslTabBuilder` should remain controller-owned while constructing `TerminalTab`
- either:
  - document this as an intentional composition exception, or
  - make one narrow ownership correction
- record the rule we learn from this batch

Done definition:
- the ownership rule for `WslTabBuilder` is clearer than it is today
- one misleading assumption about controller-owned tab assembly is either corrected or explicitly documented
- the next step for `ServerTabBuilder` can be scoped from evidence rather than guesswork

Verification:
- `rg -n "package:cwatch/view/" lib/controller/controllers/(wsl_tab_builder|server_tab_builder).dart`
- `flutter analyze`
- manual smoke check of WSL terminal tab creation

### Task 8.2: re-scope after WSL tab assembly review
Status: queued

Purpose:
- decide whether the next batch should:
  - apply the same rule to `ServerTabBuilder`
  - move a narrower slice of server tab assembly
  - stop and document controller-owned tab builders as intentional composition objects
- record what we learned from Task 8.1

Done definition:
- the next tab-assembly step is written from the post-8.1 state of the code
- any intentional boundary rule or exception is recorded here

Verification:
- follow-up task added before the next tab-assembly structural change starts

## Later Work In This Hotspot

Do not expand these until Task 8.1 has landed.

### Server tab assembly
Track here when ready:
- whether `ServerTabBuilder` should keep constructing concrete tabs directly
- whether feature-specific tabs and shared tabs should be treated differently

### Shared tab composition
Track here when ready:
- whether shared tabs like terminal/editor/explorer should be assembled through controller-owned builders or view-owned wrappers
- whether the current `WorkspaceTab(body: Widget)` shape is the real reason this seam exists

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 8.1 | WSL tab assembly ownership | queued | ownership rule for `WslTabBuilder` is clearer than today |
| 8.2 | Tab assembly re-scope | queued | next step is written from what we learn in 8.1 |
| 8.x | Tab assembly follow-up | queued | re-scoped after 8.2 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow tab-assembly ownership question clearly enough to execute
- it avoids forcing an artificial abstraction without evidence
- it gets re-scoped after the first batch instead of pretending we already know the whole answer
