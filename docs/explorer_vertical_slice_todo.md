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
Status: queued

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in shared explorer shell/chrome
- what should move out of `file_explorer_tab.dart`
- what remains intentionally local to explorer list/input behavior

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen
