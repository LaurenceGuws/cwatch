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
Status: queued

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
Status: queued

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
| 6.1 | Server/WSL builder-controller ownership | queued | at least one server/WSL binding-side view dependency is removed |
| 6.2 | Server/WSL re-scope | queued | next task is written from what we learn in 6.1 |
| 6.x | Server/WSL follow-up | queued | re-scoped after 6.2 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow server/WSL binding cleanup batch clearly enough to execute
- it improves ownership clarity without turning into a full feature-shell rewrite
- it gets re-scoped after the first batch instead of pretending we already know the whole path
