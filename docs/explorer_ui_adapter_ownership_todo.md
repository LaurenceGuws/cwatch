# Explorer UI Adapter Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around file-explorer controller/adapter imports of view-local helper types.

## How To Use This Document

This is the next actionable TODO after the workspace-core checkpoint.

Use it to:
- define the current explorer controller/adapter ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining explorer-specific `controller -> view` imports are concentrated in drag/session helpers and dialog builders:
- controller-side explorer code imports drag primitives from `view/shared/.../file_explorer/`
- controller-side explorer adapters also import dialog builders and merge-conflict UI helpers from the same view-local path

These are related, but they should not all be moved in one broad pass unless the code shows they belong together.

## Current Signal From The Codebase

Representative controller-side files:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/controller/adapters/explorer_ui_adapter.dart`
- `lib/controller/adapters/explorer_os_drag_manager.dart`

Representative view-local files currently imported by controller code:
- `lib/view/shared/views/shared/tabs/file_explorer/desktop_drag_source.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/drag_types.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/dialog_builders.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/merge_conflict_dialog.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/selection_controller.dart`

Current symptoms:
- `DesktopDragSource` and `DragLocalItem` are platform/interaction helpers, but they live under a widget-local explorer path
- `ExplorerOsDragManager` depends on those drag helpers directly
- `FileExplorerController` owns a `DesktopDragSource` and a `SelectionController` even though only parts of those types are reusable state/helpers
- `ExplorerUiAdapter` mixes generic context UI methods with file-explorer-specific dialog builders

## What We Are Trying To Improve

We are not trying to redesign the whole explorer UI.

We are trying to make one ownership rule clearer:
- controller-side explorer workflow should not depend on helper types just because those helpers currently live beside explorer widgets

## Working Rules For This Hotspot
- keep drag helper extraction separate from dialog extraction unless the code shows they should move together
- prefer extracting reusable helper/state types over moving large widget files
- do not redesign `ExplorerUiAdapter` wholesale in the first batch
- re-scope after the first batch lands

## First Batch Candidate

### Task 5.1: extract explorer drag primitives from the view tree
Status: queued

Why this is first:
- `DesktopDragSource`, `createDesktopDragSource`, `DragLocalItem`, and `DragStartResult` are imported by controller code but are not explorer widgets
- this is the clearest remaining explorer helper ownership seam
- the move should be narrow enough to validate without rewriting dialog ownership yet

Current files in scope:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/controller/adapters/explorer_os_drag_manager.dart`
- `lib/controller/adapters/explorer_ui_adapter.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/desktop_drag_source.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/drag_types.dart`

Actions:
- inspect the explorer drag helper types and classify them by role
- move reusable drag primitives to a neutral/controller-owned location if the split is clean
- update controller and view imports to match
- record what explorer-specific `controller -> view` seams remain after the extraction

Done definition:
- controller-side explorer code no longer imports drag helper types from `view/shared/views/shared/tabs/file_explorer/`
- drag primitive ownership is clearer than it is today
- the change does not require a broad explorer widget refactor

Verification:
- `rg -n "desktop_drag_source.dart|drag_types.dart" lib/controller`
- `flutter analyze`
- manual smoke check of explorer drag-out behavior on supported platforms

### Task 5.2: re-scope after drag helper extraction
Status: queued

Purpose:
- decide whether the next explorer adapter batch should target:
  - dialog builder ownership
  - selection/input controller ownership
  - `ExplorerUiAdapter` surface cleanup
- record what we learned from Task 5.1

Done definition:
- the next explorer adapter task is written from the post-5.1 state of the code
- any new ownership rule or exception is recorded here

Verification:
- follow-up task added before the next explorer structural change starts

## Later Work In This Hotspot

Do not expand these until Task 5.1 has landed.

### Explorer dialog ownership
Track here when ready:
- whether `DialogBuilders` should stay view-owned or be split into smaller presenter functions
- whether merge-conflict UI should stay behind `ExplorerUiAdapter` as a view exception

### Explorer selection/input ownership
Track here when ready:
- whether `SelectionController` should remain view-owned input handling
- whether `FileExplorerController` should continue owning a view-side selection helper directly

### Adapter surface cleanup
Track here when ready:
- whether `ExplorerUiAdapter` mixes too many responsibilities
- which dialog/notification methods are true UI adapter responsibilities versus feature-specific presenter glue

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 5.1 | Explorer drag helper extraction | queued | controller-side explorer code no longer imports drag helpers from the explorer view tree |
| 5.2 | Explorer re-scope | queued | next task is written from what we learn in 5.1 |
| 5.x | Explorer adapter follow-up | queued | re-scoped after 5.2 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow explorer controller/adapter cleanup batch clearly enough to execute
- it improves ownership clarity without turning into a full explorer rewrite
- it gets re-scoped after the first batch instead of pretending we already know the whole path
