# UI Adapter Dialog Ownership TODO

Status: active
Purpose: track the next dependency-direction cleanup batch around controller UI adapters importing shared dialog/content widgets and popup helpers.

## How To Use This Document

This is the next actionable TODO after the server/WSL binding checkpoint.

Use it to:
- define the current controller-adapter dialog/content ownership problem
- execute one narrow cleanup batch
- record what we learned
- re-scope the next batch after the current one lands

Do not treat later items here as fixed architecture commitments.

## Current Problem

The remaining `controller -> view` imports are now concentrated in UI adapters and UI-facing handlers:
- controller adapters import shared dialog wrappers and dialog content widgets
- some adapters import feature-specific popup/content widgets from `view/`
- these imports are not all equal: some are acceptable concrete UI exceptions, some look like mislocated helpers

## Current Signal From The Codebase

Representative adapter/handler files:
- `lib/controller/adapters/server_workspace_ui_adapter.dart`
- `lib/controller/adapters/docker_ui_adapter.dart`
- `lib/controller/adapters/docker_overview_ui_adapter.dart`
- `lib/controller/adapters/remote_file_editor_ui_adapter.dart`
- `lib/controller/adapters/settings_ui_adapter.dart`
- `lib/controller/adapters/wsl_ui_adapter.dart`
- `lib/controller/adapters/ssh_auth_prompter.dart`
- `lib/controller/adapters/file_operations_ui_handler.dart`

Representative imported view-side helpers:
- `lib/view/shared/widgets/dialog_keyboard_shortcuts.dart`
- `lib/view/shared/widgets/port_forward_dialog.dart`
- `lib/view/shared/widgets/file_operation_progress_dialog.dart`
- `lib/view/shared/widgets/operation_progress_popup.dart`
- `lib/view/shared/views/shared/tabs/editor/remote_file_editor/file_info_dialog_content.dart`
- `lib/view/features/docker/remote_docker_status.dart`
- `lib/view/features/servers/servers/add_server_dialog.dart`

Current symptoms:
- some controller adapters are directly responsible for showing concrete dialogs, which may be fine if the helper is truly shared UI
- some imported types are not dialogs at all, but content/popup widgets living in feature-local paths
- the current folder placement makes it hard to tell which imports are acceptable UI exceptions and which indicate misplaced reusable UI

## What We Are Trying To Improve

We are not trying to eliminate all controller-adapter usage of Flutter widgets.

We are trying to make one ownership rule clearer:
- controller UI adapters may depend on concrete shared UI, but reusable dialog/content helpers should not be hidden in misleading feature-local paths if they are used as cross-cutting adapter dependencies

## Working Rules For This Hotspot
- separate acceptable concrete UI exceptions from misleading file ownership
- prefer moving shared UI helpers before redesigning adapter interfaces
- do not try to rewrite every dialog adapter into a non-UI abstraction
- re-scope after the first batch lands

## First Batch Candidate

### Task 7.1: inspect shared adapter dialog/content helper ownership
Status: completed

Why this is first:
- the remaining imports are clustered around a small set of shared widget helpers
- at least some of these helpers appear mislocated rather than architecturally wrong
- this should allow one narrow ownership correction without changing the adapter pattern itself

Current files in scope:
- `lib/controller/adapters/remote_file_editor_ui_adapter.dart`
- `lib/controller/adapters/docker_ui_adapter.dart`
- `lib/controller/adapters/docker_overview_ui_adapter.dart`
- `lib/controller/adapters/server_workspace_ui_adapter.dart`
- `lib/controller/adapters/settings_ui_adapter.dart`
- `lib/controller/adapters/wsl_ui_adapter.dart`
- `lib/controller/adapters/ssh_auth_prompter.dart`
- `lib/controller/adapters/file_operations_ui_handler.dart`
- directly imported shared/feature-local widget helpers needed to make one ownership seam clearer

Actions:
- classify the imported view-side helpers by role:
  - genuinely shared dialog/popup widget
  - feature-local content widget with broader reuse than its path suggests
  - acceptable feature-specific UI exception
- choose one narrow ownership correction
- implement only that correction
- update imports to match
- record which remaining adapter-side view imports are intentional exceptions versus future cleanup candidates

Done definition:
- at least one misleading adapter-side `controller -> view` dependency is removed or reclassified cleanly
- ownership of the touched dialog/content helper is clearer than before
- the change does not require redesigning the entire adapter layer

Verification:
- `rg -n "package:cwatch/view/" lib/controller/adapters`
- `flutter analyze`
- manual smoke check of the affected dialog/popup flow

### Task 7.2: re-scope after the first adapter dialog/content move
Status: completed

Purpose:
- decide whether the next adapter batch should target:
  - shared dialog keyboard wrappers
  - progress popup/dialog helpers
  - remaining feature-local content widgets
  - stopping here and treating the rest as intentional UI exceptions
- record what we learned from Task 7.1

Done definition:
- the next adapter dialog/content task is written from the post-7.1 state of the code
- any intentional UI exceptions are recorded here

Verification:
- follow-up task added before the next adapter structural change starts

Result of re-scope:
- `RemoteFileInfoDialogContent` moved out of the editor tab subtree into `view/shared/widgets/`
- `RemoteFileEditorUiAdapter` no longer depends on a widget file from `view/shared/views/shared/tabs/editor/...`
- the remaining adapter-side imports are now mostly shared dialog wrappers/progress widgets plus a few feature-local exceptions (`remote_docker_status.dart`, `add_server_dialog.dart`)
- the next batch should stay focused on mislocated adapter helper ownership, not generic shared dialog wrappers yet

### Task 7.3: inspect feature-local adapter content/helper ownership
Status: queued

Why this is next:
- the remaining clearly suspicious adapter-side imports are now the feature-local helper/content files rather than the shared widget wrappers
- `docker_ui_adapter.dart` importing `view/features/docker/remote_docker_status.dart` is especially strong signal because the type is data, not UI
- `server_workspace_ui_adapter.dart` importing `add_server_dialog.dart` may be a valid feature exception and should be evaluated separately from mislocated helpers

Actions:
- inspect the remaining feature-local adapter imports and classify them as mislocated helper versus intentional feature exception
- make one narrow ownership correction or record the exception clearly
- update imports to match

Done definition:
- at least one remaining feature-local adapter-side dependency is reduced or clearly justified
- adapter/content ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/view/features/" lib/controller/adapters`
- `flutter analyze`

## Later Work In This Hotspot

Do not expand these until Task 7.1 has landed.

### Shared dialog wrappers
Track here when ready:
- whether `dialog_keyboard_shortcuts.dart` should stay view-owned shared UI
- whether repeated inline rename/password dialogs should be consolidated or left local

### Progress popup/dialog helpers
Track here when ready:
- whether file-operation and operation-progress widgets are shared enough to justify current placement
- whether their current controller adapter usage is an intentional exception

### Feature-local content widgets
Track here when ready:
- whether `remote_file_editor/file_info_dialog_content.dart` and `docker/remote_docker_status.dart` are mislocated reusable content widgets
- whether `servers/add_server_dialog.dart` should remain a feature exception

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 7.1 | Shared adapter dialog/content helper ownership | completed | at least one misleading adapter-side view dependency is removed or reclassified |
| 7.2 | Adapter dialog/content re-scope | completed | next task is written from what we learn in 7.1 |
| 7.3 | Feature-local adapter content/helper ownership | queued | at least one remaining feature-local adapter-side dependency is reduced or justified |
| 7.x | Adapter dialog/content follow-up | queued | re-scoped after 7.3 |

## Completion Metric

This document is serving its purpose if:
- it defines one narrow adapter dialog/content cleanup batch clearly enough to execute
- it improves ownership clarity without pretending adapters should stop using UI completely
- it gets re-scoped after the first batch instead of pretending we already know the whole path
