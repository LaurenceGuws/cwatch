# Server WSL Binding Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around controller bindings importing view-owned server and WSL builder/controller types.

## How To Use This Document

This is the next actionable TODO after the explorer adapter checkpoint.

Use it to:
- define the current server/WSL binding ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining high-value binding-side `controller -> view` imports are concentrated in server and WSL feature construction:
- bindings construct server and WSL tab builders that currently live under `view/features/...`
- one binding also constructs a WSL workspace controller that currently lives under `view/features/wsl/`

These are related because they are both about controller-owned construction code depending on view-owned feature workflow types.

## Current Signal From The Codebase

Representative binding files:
- `lib/controller/di/bindings/server_tab_builder_binding.dart`
- `lib/controller/di/bindings/wsl_tab_builder_binding.dart`
- `lib/controller/di/bindings/wsl_workspace_controller_binding.dart`

Representative feature-side files currently imported by bindings:
- `lib/view/features/servers/server_tab_builder.dart`
- `lib/view/features/wsl/wsl_tab_builder.dart`
- `lib/view/features/wsl/wsl_workspace_controller.dart`

Current symptoms:
- `ServerTabBuilder` is a feature workflow/builder type, but bindings import it from `view/features/servers/`
- `WslTabBuilder` is in the same position for WSL
- `WslWorkspaceController` is controller-style state/persistence logic, but it still lives under `view/features/wsl/`
- the current split makes feature construction ownership harder to reason about than it needs to be

## What We Are Trying To Improve

We are not trying to redesign the server or WSL features end-to-end.

We are trying to make one ownership rule clearer:
- controller-side bindings should not construct feature workflow/controller types from `view/features/...` when those types are not primarily widgets

## Working Rules For This Hotspot
- keep server and WSL builder/controller ownership cleanup together only where the pattern is clearly shared
- prefer moving non-widget builder/controller types over broad feature tree reshuffles
- do not refactor large server/WSL views in the first batch
- re-scope after the first batch lands

## First Batch Candidate

### Task 6.1: inspect server and WSL builder/controller ownership
Status: completed

Why this is first:
- the remaining binding-side `controller -> view` imports are tightly clustered here
- `WslWorkspaceController` is especially strong signal because it is controller logic living under `view/features/`
- this should allow one or two narrow ownership moves without redesigning the screens

Current files in scope:
- `lib/controller/di/bindings/server_tab_builder_binding.dart`
- `lib/controller/di/bindings/wsl_tab_builder_binding.dart`
- `lib/controller/di/bindings/wsl_workspace_controller_binding.dart`
- `lib/view/features/servers/server_tab_builder.dart`
- `lib/view/features/wsl/wsl_tab_builder.dart`
- `lib/view/features/wsl/wsl_workspace_controller.dart`
- any directly related types needed to make one ownership seam clearer

Actions:
- classify each touched type by role:
  - widget/presentation
  - builder/workflow
  - workspace controller/state
- choose one narrow ownership correction that improves the binding boundary
- implement only that correction
- update imports to match
- record what binding-side view dependencies remain after the move

Done definition:
- at least one server/WSL binding-side `controller -> view` dependency is removed
- ownership of the touched server/WSL builder/controller types is clearer than before
- the resulting structure is easier to reason about than the current split

Verification:
- `rg -n "package:cwatch/view/features/(servers|wsl)" lib/controller/di/bindings`
- `flutter analyze`
- manual smoke check of server and WSL tab creation/restoration flows

### Task 6.2: re-scope after the first server/WSL ownership move
Status: completed

Purpose:
- decide whether the next batch should target:
  - remaining server tab builder ownership
  - remaining WSL builder/controller ownership
  - stopping here and moving to shared dialog adapter seams
- record what we learned from Task 6.1

Done definition:
- the next server/WSL task is written from the post-6.1 state of the code
- any new ownership rule or exception is recorded here

Verification:
- follow-up task added before the next server/WSL structural change starts

Result of re-scope:
- `WslWorkspaceController` moved out of `view/features/wsl/` into `controller/controllers/`
- `WslWorkspaceControllerBinding` no longer imports a view-owned workspace controller
- the remaining binding-side view imports in this hotspot are now limited to `ServerTabBuilder` and `WslTabBuilder`
- the next batch should focus on tab builder ownership, not broader server/WSL view cleanup

### Task 6.3: inspect server and WSL tab builder ownership
Status: completed

Why this is next:
- the remaining binding-side `controller -> view` imports in this hotspot are both tab builders
- this is a narrower and more comparable pair than the original mixed builder/controller seam
- it gives a clear next question: move one builder, narrow the binding interface, or record the exception

Actions:
- inspect `ServerTabBuilder` and `WslTabBuilder` with their binding call sites
- decide whether one builder is clearly non-widget enough to move now, or whether a narrower interface is the right boundary
- implement one narrow ownership correction or record the exception clearly

Done definition:
- at least one remaining server/WSL tab-builder binding dependency is reduced or clearly justified
- binding ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/features/(servers|wsl)" lib/controller/di/bindings`
- `flutter analyze`

Result of Task 6.3:
- `WslTabBuilder` moved out of `view/features/wsl/` into `controller/controllers/`
- `WslTabBuilderBinding` no longer imports from `view/features/`
- the remaining binding-side view import in this hotspot is now only `ServerTabBuilder`
- the next batch should isolate server tab-builder ownership rather than keep treating server and WSL as one seam

### Task 6.4: inspect server tab builder ownership
Status: queued

Why this is next:
- `ServerTabBuilderBinding` is now the only remaining binding-side import from `view/features/(servers|wsl)`
- the server builder is heavier than the WSL builder, so it should be scoped on its own now
- this gives a clear next question: move the builder, narrow the binding interface, or record the exception

Actions:
- inspect `ServerTabBuilder` and its binding/view call sites
- decide whether the builder itself should move or whether a narrower controller-owned interface is the better boundary
- implement one narrow ownership correction or record the exception clearly

Done definition:
- the remaining `ServerTabBuilderBinding -> view/features/servers` dependency is reduced or clearly justified
- server binding ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/features/servers/server_tab_builder.dart" lib/controller/di/bindings`
- `flutter analyze`

## Later Work In This Hotspot

Do not expand these until Task 6.1 has landed.

### Server builder ownership
Track here when ready:
- whether `ServerTabBuilder` should stay feature-view-owned or move behind a narrower interface
- whether builder logic should be split from concrete widget assembly

### WSL builder/controller ownership
Track here when ready:
- whether `WslTabBuilder` and `WslWorkspaceController` should move together
- whether WSL restoration logic needs a controller-owned home

### Shared dialog adapter seams
Track elsewhere after this hotspot:
- controller UI adapters that still import shared dialog/content widgets
- whether those are true view exceptions or mislocated helpers

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 6.1 | Server/WSL builder-controller ownership | completed | at least one server/WSL binding-side view dependency is removed |
| 6.2 | Server/WSL re-scope | completed | next task is written from what we learn in 6.1 |
| 6.3 | Server/WSL tab-builder ownership | completed | at least one remaining server/WSL tab-builder binding dependency is reduced or justified |
| 6.4 | Server tab-builder ownership | queued | the remaining `ServerTabBuilderBinding -> view/features/servers` dependency is reduced or justified |
| 6.x | Server/WSL follow-up | queued | re-scoped after 6.4 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow server/WSL binding cleanup batch clearly enough to execute
- it improves ownership clarity without turning into a full feature-shell rewrite
- it gets re-scoped after the first batch instead of pretending we already know the whole path
