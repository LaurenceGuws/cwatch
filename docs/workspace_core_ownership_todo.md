# Workspace Core Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around workspace-core tab ownership without blending it with feature-specific refactors.

## How To Use This Document

This is the next actionable TODO after the docker/workspace checkpoint.

Use it to:
- define the current workspace-core ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining high-value workspace-core `controller -> view` seam is concentrated in tab state ownership:
- `WorkspaceTab` depends on tab option types that currently live in a view widget file
- `TabbedWorkspaceController` depends on `TabHostController` from a view path even though the type itself is not presentation-specific

These are related, but they should not be solved in one broad move unless the code shows they belong together.

## Current Signal From The Codebase

Representative files:
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/controller/core/workspace/tabbed_workspace_controller.dart`
- `lib/view/core/tabs/tab_host.dart`
- `lib/view/shared/views/shared/tabs/tab_chip.dart`
- `lib/model/shared/mixins/tab_options_mixin.dart`

Current symptoms:
- `WorkspaceTab` imports `TabOptionsController` from `tab_chip.dart`, which is primarily a UI widget file
- `tab_chip.dart` currently mixes tab UI with reusable tab option state types
- `TabbedWorkspaceController` extends `TabHostController` from a `view/` path even though the controller itself is non-UI state management
- workspace-core ownership is harder to reason about because the reusable types live alongside widgets

## What We Are Trying To Improve

We are not trying to redesign all tab UI.

We are trying to make one ownership rule clearer:
- non-UI workspace tab state types should not have to live in view widget files to be shared across the app

## Working Rules For This Hotspot
- keep workspace-core cleanup separate from feature-specific tab builders
- prefer extracting reusable state over moving whole UI files
- avoid broad tab-system renames unless a smaller extraction fails
- re-scope after the first batch lands

## First Batch Candidate

### Task 4.1: split tab option state from `tab_chip.dart`
Status: completed

Why this is first:
- `WorkspaceTab` currently imports a controller/state type from a widget file
- `TabChipOption`, `TabOptionsController`, `CompositeTabOptionsController`, and `TabCloseWarning` are used far beyond the `TabChip` widget itself
- this is the narrowest workspace-core ownership correction available

Current files in scope:
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/view/shared/views/shared/tabs/tab_chip.dart`
- `lib/model/shared/mixins/tab_options_mixin.dart`
- direct call sites that need import updates

Actions:
- inspect the non-UI tab option types in `tab_chip.dart`
- extract reusable non-UI tab option state to a neutral location
- keep the `TabChip` widget in the view tree
- update imports in `controller/`, `model/`, and `view/`
- record what workspace-core coupling remains after the extraction

Done definition:
- `WorkspaceTab` no longer imports from `tab_chip.dart`
- reusable tab option state no longer lives in a widget file
- ownership of the tab option types is clearer than it is today

Verification:
- `rg -n "tab_chip.dart" lib/controller lib/model`
- `flutter analyze`
- manual smoke check of tab menus and tab close warnings in one or two workspace screens

### Task 4.2: re-scope after tab option extraction
Status: completed

Purpose:
- decide whether the next workspace-core batch should target:
  - `TabHostController` ownership
  - remaining workspace tab metadata ownership
  - feature-side tab builder exceptions
- record what we learned from Task 4.1

Done definition:
- the next workspace-core task is written from the post-4.1 state of the code
- any new ownership rule or exception is recorded here

Verification:
- follow-up task added before the next workspace-core structural change starts

Result of re-scope:
- reusable tab option state now lives in `lib/controller/core/workspace/tab_options.dart`
- `WorkspaceTab` no longer imports from `tab_chip.dart`
- `tab_chip.dart` is now a widget file again instead of a mixed widget/state file
- the next workspace-core ownership question is `TabHostController` living under `view/core/tabs/`

### Task 4.3: inspect tab host controller ownership
Status: completed

Why this is next:
- `TabbedWorkspaceController` still extends `TabHostController` from a `view/` path
- `TabHostController` appears to be generic tab state management rather than presentation
- this is now the clearest remaining workspace-core `controller -> view` seam

Actions:
- inspect `tab_host.dart` and its call sites
- decide whether `TabHostController` should move to a neutral/controller-owned location or remain where it is as an explicit exception
- implement one narrow ownership correction or record the exception clearly

Done definition:
- the `TabbedWorkspaceController` dependency on `view/core/tabs/tab_host.dart` is either removed or explicitly justified
- workspace-core ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/core/tabs/tab_host.dart" lib/controller`
- `flutter analyze`

Result of Task 4.3:
- `TabHostController` now lives in `lib/controller/core/workspace/tab_host_controller.dart`
- `TabbedWorkspaceController` no longer imports from `view/core/tabs/tab_host.dart`
- view-side tab rendering code imports the controller-owned type directly
- `lib/view/core/tabs/tab_host.dart` is now only a compatibility export and not an ownership source

### Task 4.4: re-scope workspace-core follow-up
Status: queued

Purpose:
- decide whether the next workspace-core batch should target:
  - removing the compatibility export in `view/core/tabs/tab_host.dart`
  - clarifying `WorkspaceTab` metadata vs rendered body ownership
  - stopping here and shifting to the next hotspot
- record what we learned from Task 4.3

Done definition:
- the next workspace-core step is written from the post-4.3 state of the code
- any intentional compatibility shim or exception is recorded here

Verification:
- follow-up task added before the next workspace-core structural change starts

## Later Work In This Hotspot

Do not expand these until Task 4.1 has landed.

### Tab host controller ownership
Track here when ready:
- whether `TabHostController` should move out of `view/core/tabs/`
- whether its current location is only misleading or actively harmful

### Workspace tab metadata ownership
Track here when ready:
- whether `WorkspaceTab` should keep carrying `Widget body`
- whether workspace tab metadata and rendered content should stay as one type

### Feature tab builder exceptions
Track here when ready:
- which feature tab builders remain legitimately view-owned
- which controller/binding usages still need narrower interfaces

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 4.1 | Tab option state extraction | completed | `WorkspaceTab` no longer imports from `tab_chip.dart` |
| 4.2 | Workspace-core re-scope | completed | next task is written from what we learn in 4.1 |
| 4.3 | Tab host controller ownership | completed | `TabbedWorkspaceController` no longer depends on `view/core/tabs/tab_host.dart`, or the exception is justified |
| 4.4 | Workspace-core re-scope | queued | next step is written from what we learn in 4.3 |
| 4.x | Workspace-core follow-up | queued | re-scoped after 4.4 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow workspace-core cleanup batch clearly enough to execute
- it improves ownership clarity without turning into a general tab-system rewrite
- it gets re-scoped after the first batch instead of pretending we already know the whole path
