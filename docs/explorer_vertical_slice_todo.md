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
Status: completed

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

Result:
- extracted [file_explorer_tab_presenter.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_presenter.dart)
- moved top-level explorer tab orchestration into the presenter seam:
  - loading/error/streaming state shaping
  - settings visibility toggle ownership
  - timeout snackbar de-duplication
  - explorer-level shortcut wiring
- kept dense entry-list, selection, drag/drop, and file-operation initiation local to [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)

## Task 15.4: re-scope the next explorer slice batch
Status: completed

Goal:
- decide the next smallest explorer-local seam after the presenter split without broadening the slice into generic file-manager abstractions

Likely candidates:
- extract explorer-level action/file-operation handlers out of `file_explorer_tab.dart`
- split entry-list interaction wiring from row rendering
- checkpoint the slice and move to tests before further extraction

Done definition:
- the next explorer batch is chosen from current code shape
- the choice reflects the presenter split that just landed

Result:
- the next explorer seam should be explorer-level action/file-operation orchestration, not entry-list rendering
- the remaining dense weight in [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart) is concentrated in:
  - entry context-menu wiring
  - rename/move/delete flows
  - paste/upload/download flows
  - local edit sync/refresh/clear flows
  - drop handling and refresh helpers
- entry-list rendering, selection behavior, and row-level interaction remain intentionally local for now

Why this is the right next cut:
- it removes workflow orchestration from the tab without forcing generic entry-list abstractions
- it follows the presenter split cleanly:
  - presenter owns top-level tab state shaping
  - next seam should own explorer action/file-operation coordination
- it preserves the current local ownership of dense pointer/keyboard/list behavior

## Task 15.5: implement explorer action/file-operation split
Status: completed

Goal:
- extract explorer-level action and file-operation orchestration out of `file_explorer_tab.dart` while keeping entry-list rendering and selection behavior local

First code targets:
- entry context-menu action routing
- rename/move/delete orchestration
- paste/upload/download orchestration
- local edit sync/refresh/clear orchestration
- refresh/drop helpers that primarily support file operations

What should stay local in this batch:
- `_buildEntriesList()`
- selection controller integration
- list key handling wiring
- row rendering and drag-selection behavior

Done definition:
- `file_explorer_tab.dart` no longer owns most explorer action/file-operation workflow code
- the extracted seam is explorer-specific and narrow, not a generic file-manager action framework
- dense list/input behavior remains local and readable

Result:
- extracted [file_explorer_tab_actions.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_actions.dart)
- moved explorer action/file-operation orchestration out of [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart):
  - entry context-menu action routing
  - rename/move/delete flows
  - paste/upload/download flows
  - local edit sync/refresh/clear flows
  - path refresh and drop-completion helpers
- kept entry-list rendering, selection behavior, drag-selection, and row-level interaction local to the tab

## Task 15.6: re-scope the next explorer slice batch
Status: completed

Goal:
- decide whether the next explorer step should keep splitting view-local seams or stop and deepen the regression floor around the new presenter/actions boundaries

Likely candidates:
- split entry-list interaction wiring from row rendering
- add focused tests around the presenter/actions seams
- checkpoint the first explorer slice as a coherent stopping point

Done definition:
- the next explorer batch is chosen from the post-action-split code shape
- the choice reflects the new presenter and actions seams together, not just line count reduction

Result:
- the next explorer batch should deepen the regression floor around the new presenter/actions seams
- it should not split entry-list interaction wiring yet

Why this is the right next move:
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart) is now down to the dense explorer-local interaction surface:
  - entry-list rendering
  - pointer and keyboard selection wiring
  - drag-hover state
  - drag-selection integration
- that remaining code is exactly the area most likely to become worse if split prematurely into fake reusable helpers
- the two new seams:
  - [file_explorer_tab_presenter.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_presenter.dart)
  - [file_explorer_tab_actions.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_actions.dart)
  should be locked down before any deeper explorer-local extraction

## Task 15.7: add focused tests for explorer presenter/actions seams
Status: completed

Goal:
- add regression coverage around the two new explorer seams before deciding whether the first slice should continue or checkpoint

First test targets:
- `file_explorer_tab_presenter_test.dart`
  - timeout snackbar de-duplication
  - loading vs streaming state shaping
  - shortcut map enable/disable behavior
- `file_explorer_tab_actions_test.dart`
  - rename/move/delete success/failure routing
  - paste/upload/download delegation
  - refresh/drop completion behavior

Done definition:
- the presenter/actions seams have direct focused tests
- the tests validate the extracted orchestration boundaries rather than broad widget behavior
- the next slice decision can be made from a safer regression floor

Result:
- added [file_explorer_tab_presenter_test.dart](/home/home/personal/cwatch/test/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_presenter_test.dart)
- added [file_explorer_tab_actions_test.dart](/home/home/personal/cwatch/test/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_actions_test.dart)
- covered:
  - timeout snackbar de-duplication
  - loading vs streaming state shaping
  - shortcut enable/disable behavior
  - rename success/failure routing
  - paste delegation
  - drop-completion delegation

## Task 15.8: re-scope the first explorer slice checkpoint
Status: queued

Goal:
- decide whether the first explorer slice should checkpoint now or continue into the dense entry-list interaction surface

Questions to answer:
- is the first slice already a coherent boundary proof with presenter + actions + tests
- is there one more low-risk explorer-local extraction worth doing before checkpointing
- should the next move be explorer-specific widget/input tests instead of more code movement

Done definition:
- the next explorer move is chosen from the post-test code shape
- the decision reflects architectural value, not just remaining file size
