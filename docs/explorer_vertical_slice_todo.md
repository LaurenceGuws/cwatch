# Explorer Vertical Slice TODO

Status: active
Purpose: turn the first vertical-slice rewrite into an implementation backlog around the explorer feature, using the existing dependency, integration, and testing checkpoints as the floor rather than starting from another broad architecture survey.

## Why Explorer Is First

Explorer is the strongest first vertical slice because:
- major dependency-direction problems in the explorer path are already cleaned up
- explorer shared-surface and chrome contracts are already explicit
- explorer already has useful regression coverage:
  - `explorer_ops_test.dart`
  - `path_loading_service_test.dart`
  - `file_editing_service_test.dart`
  - `explorer_trash_manager_test.dart`
  - `file_explorer_tab_test.dart`
  - `explorer_dialog_builders_test.dart`
- it exercises:
  - shared shell UI
  - feature workflow state
  - file operations
  - dialog/selection/input behavior
- it avoids the heavier infra complexity of servers as a first proving slice

## Scope Of This Slice

This slice is not:
- a full explorer redesign
- a generic file-manager framework
- a broad filesystem infrastructure rewrite

This slice is:
- proving the target architecture on one bounded feature surface
- reducing the size and coupling of `file_explorer_tab.dart`
- making explorer workflow boundaries clearer end-to-end

## Current Architectural Starting Point

Relevant current files:
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)
- [file_explorer_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/file_explorer_controller.dart)
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
- [explorer_ops.dart](/home/home/personal/cwatch/lib/model/services/explorer_ops.dart)
- [path_loading_service.dart](/home/home/personal/cwatch/lib/model/services/path_loading_service.dart)
- [file_editing_service.dart](/home/home/personal/cwatch/lib/model/services/file_editing_service.dart)
- [explorer_chrome_scaffold.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/explorer_chrome_scaffold.dart)

Current known truth:
- explorer chrome/shared-surface ownership is much cleaner than before
- the main remaining weight is still concentrated in `file_explorer_tab.dart`
- the likely next architectural seam is splitting explorer orchestration from dense list/input rendering

## Task 15.1: confirm explorer as the first vertical slice
Status: completed

Goal:
- choose the first true vertical slice from current rewrite evidence

Candidates considered:
- explorer
- docker
- servers

Result:
- explorer is the first vertical slice

Why this wins:
- strongest cleanup groundwork already landed
- strongest regression floor already exists
- high architectural leverage with lower infra risk than servers

## Task 15.2: define the explorer target slice boundary
Status: completed

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in shared explorer shell/chrome
- what should move out of `file_explorer_tab.dart`
- what remains intentionally local to explorer list/input behavior

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen

Result:
- the first explorer slice boundary is now explicit

### What stays shared / out of scope for the first batch

These areas are already in a good enough place and should stay stable for the first slice pass:
- `ExplorerChromeScaffold`
- `PathNavigator`
- `ExplorerUiAdapter`
- `ExplorerOps`
- `PathLoadingService`
- `FileEditingService`
- dialog builders and shared prompt paths

Why they stay stable:
- they already reflect the dependency/integration cleanup work
- changing them in the first slice would broaden the blast radius unnecessarily

### What stays intentionally local to explorer behavior

These remain explorer-local even after the first slice cut:
- dense entry-list rendering
- pointer/keyboard selection behavior
- drag/drop interaction handling
- file-operation initiation flows tied closely to explorer selection and entries

The goal is not to genericize these.

### What should move out of `file_explorer_tab.dart` first

The first seam is explorer orchestration around top-level tab state, not the entry list itself.

That means extracting the logic that currently coordinates:
- loading/error/streaming render switching
- shortcut/action wiring
- settings-panel toggle state
- timeout notification side effects
- controller-to-view state mapping for top-level explorer modes

This should become a narrower explorer view-model/presenter-style seam for the tab surface, while the entry list and selection-heavy rendering can stay local for now.

### Why this is the right first cut

- it reduces the architectural weight of `file_explorer_tab.dart` without destabilizing the densest interaction code
- it proves the slice on orchestration/state shaping first
- it keeps the existing regression floor relevant

## Task 15.3: implement explorer top-level presentation/orchestration split
Status: queued

Goal:
- extract the top-level explorer tab presentation/orchestration logic out of `file_explorer_tab.dart` while leaving entry-list/input-heavy behavior local for now

First code targets:
- top-level loading/error/streaming state shaping
- settings visibility toggle ownership
- timeout snackbar side-effect handling
- shortcut/action wiring for explorer-level actions

Done definition:
- `file_explorer_tab.dart` is materially smaller and more focused on rendering/composition
- the new seam clearly owns top-level explorer tab orchestration
- entry-list/input behavior remains local and untouched except where needed for the seam
