# Docker Workspace Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around docker/workspace ownership seams without mixing multiple hotspots into one refactor.

## How To Use This Document

This is the next actionable TODO after the shell/module checkpoint.

Use it to:
- define the current docker/workspace ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining high-value `controller -> view` ownership seams are concentrated in two places:
- docker overview bindings/controllers depending on view-owned helper types
- workspace core types depending on view-owned tab host/chip types

These should not be cleaned up together in one pass.

The more actionable first seam is docker overview ownership because:
- the dependency chain is easy to point at
- the files are already grouped around one feature flow
- it is likely to teach us how to split feature workflow ownership from presentation helpers

## Current Signal From The Codebase

Representative docker files:
- `lib/controller/controllers/docker_overview_actions_controller.dart`
- `lib/controller/di/bindings/docker_overview_binding.dart`
- `lib/view/features/docker/docker_tab_builder.dart`
- `lib/view/features/docker/widgets/docker_overview_controller.dart`
- `lib/view/features/docker/widgets/docker_overview.dart`

Representative workspace-core follow-up files:
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/controller/core/workspace/tabbed_workspace_controller.dart`
- `lib/view/core/tabs/tab_host.dart`
- `lib/view/shared/views/shared/tabs/tab_chip.dart`

Current symptoms:
- `DockerOverviewActionsController` imports view-owned docker workflow/helper types
- `DockerOverviewBinding` constructs feature objects using view-owned types from the docker feature tree
- workspace-core controller types still depend on view-owned tab abstractions, but that is a separate seam and should stay separate for now

## What We Are Trying To Improve

We are not trying to solve all remaining `controller -> view` imports.

We are trying to make one ownership rule clearer:
- docker overview workflow/controller code should not depend directly on view-owned helper/controller types if a narrower ownership split is possible

## Working Rules For This Hotspot
- keep docker overview cleanup separate from workspace-core cleanup
- prefer one ownership move over a broad docker refactor
- do not rename half the docker feature tree in one pass
- re-scope after the first batch lands

## First Batch Candidate

### Task 3.1: inspect docker overview ownership seam
Status: completed

Why this is first:
- `DockerOverviewActionsController` and `DockerOverviewBinding` currently depend on `view/features/docker/*`
- this is the clearest feature-level controller/binding ownership knot left after shell cleanup
- it should be possible to make one narrow ownership correction without rewriting docker tabs end-to-end

Current files in scope:
- `lib/controller/controllers/docker_overview_actions_controller.dart`
- `lib/controller/di/bindings/docker_overview_binding.dart`
- `lib/view/features/docker/docker_tab_builder.dart`
- `lib/view/features/docker/widgets/docker_overview_controller.dart`
- any directly related types needed to make one ownership seam clearer

Actions:
- inspect the docker overview classes and classify each by role:
  - workflow/controller
  - binding/composition
  - presentation helper
  - tab/view builder
- choose one narrow ownership correction
- implement only that correction
- update imports to match

Done definition:
- at least one misleading `controller -> view` dependency in the docker overview seam is removed
- ownership of the touched docker overview types is clearer than before
- the resulting structure is easier to reason about than the current split

Verification:
- `rg -n "package:cwatch/view/features/docker" lib/controller/controllers lib/controller/di/bindings`
- `flutter analyze`
- manual smoke check of docker overview open-tab actions

### Task 3.2: re-scope after docker overview cleanup
Status: completed

### Task 3.3: inspect docker tab builder ownership
Status: completed

Why this is next:
- `DockerOverviewController` now lives under `controller/controllers/`
- the remaining docker-specific `controller -> view` seam is `docker_tab_builder.dart`
- this is now a narrower question than the original overview knot

Actions:
- inspect `docker_tab_builder.dart` and the controller/binding call sites that depend on it
- decide whether the builder is presentation-only or mixed workflow/presentation
- make one narrow ownership correction or record the exception explicitly

Done definition:
- the remaining docker-specific `controller -> view` dependency is either reduced or clearly justified
- docker overview ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/features/docker" lib/controller/controllers lib/controller/di/bindings`
- `flutter analyze`
- manual smoke check of docker overview open-tab actions

Purpose:
- decide whether the next docker/workspace batch should target:
  - remaining docker overview types
  - docker tab builder ownership
  - workspace-core tab ownership
- record what we learned from Task 3.1

Done definition:
- the next docker/workspace task is written from the post-3.1 state of the code
- any new ownership rule or exception is recorded here

Verification:
- follow-up task added before the next docker/workspace structural change starts

Result of re-scope:
- `DockerOverviewController` moved out of `view/` into `controller/controllers/`
- controller/binding ownership for docker overview state is clearer than before
- the remaining docker-specific controller/binding dependency on `view/` is `docker_tab_builder.dart`
- workspace-core ownership still stays out of this batch

## Later Work In This Hotspot

Do not expand these until Task 3.1 has landed.

### Docker tab builder ownership
Track here when ready:
- whether `docker_tab_builder.dart` is presentation-only or mixed workflow/presentation
- whether builder logic should stay in view or move behind a narrower interface

### Workspace-core ownership
Track here when ready:
- whether `WorkspaceTab` should continue depending on `TabOptionsController`
- whether `TabbedWorkspaceController` should continue extending a view-owned `TabHostController`

### Explorer controller/adapter cleanup
Track here when ready:
- remaining explorer controller/adapter imports of view-local helper types
- whether those should be treated as presentation exceptions or further ownership issues

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 3.1 | Docker overview ownership seam | completed | one misleading docker overview `controller -> view` dependency is removed |
| 3.2 | Docker/workspace re-scope | completed | next batch is written from what we learned in 3.1 |
| 3.3 | Docker tab builder ownership | completed | remaining docker-specific controller/binding dependency is reduced or justified |
| 3.x | Docker tab/workspace follow-up | queued | re-scoped after 3.3 |

## Docker/workspace checkpoint

Current state:
- docker overview controller ownership is clarified
- docker controller/binding code no longer imports from `view/features/docker`
- `docker_tab_builder.dart` remains view-owned but is now consumed through a controller-owned interface where needed
- the next work should split docker follow-up from workspace-core ownership instead of treating them as one seam

## Completion Metric

This document is serving its purpose if:
- it defines one narrow docker/workspace cleanup batch clearly enough to execute
- it improves ownership clarity without blending docker and workspace-core refactors together
- it gets re-scoped after the first batch instead of pretending we already know the whole path
