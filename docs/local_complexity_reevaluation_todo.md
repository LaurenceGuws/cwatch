# Local Complexity Reevaluation TODO

Status: active
Purpose: track bounded cleanup reopened from fresh current-state evidence after the older broad hotspot queue was checkpointed.

## Task 28.1: start the local complexity reevaluation pass
Status: completed

Goal:
- reopen cleanup only from fresh file-level evidence in the current code state
- keep this pass focused on large mixed-responsibility files rather than recreating a broad repo-wide hotspot queue

Done definition:
- there is one active TODO for the current local-complexity pass
- the first bounded batch is named from the fresh file-size and responsibility review

Result:
- local complexity reevaluation is now the active current-state pass
- the first bounded batch should come from the clearest mixed-surface large file

## Task 28.2: define the first bounded local complexity batch
Status: completed

Goal:
- choose one large file whose size still reflects multiple distinct surfaces instead of one coherent responsibility
- keep the batch on file-level decomposition, not broader Docker workflow redesign

Done definition:
- one explicit first batch is named
- the stop condition reflects the current file shape

Result:
- the first bounded local-complexity batch is now:
  - split Docker storage lists out of `docker_lists.dart`
- target files:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
  - new Docker widget file under `lib/view/features/docker/widgets/`
- stop condition:
  - network and volume list surfaces no longer live in the same file as container and image surfaces
  - tiny shared helpers are promoted only where needed
  - behavior stays stable

Why this is the right first cut:
- `docker_lists.dart` is large because it still hosts several distinct list surfaces
- network and volume lists are the most self-contained file-level split available
- this improves navigation and maintainability without changing Docker behavior

## Task 28.3: implement the first bounded local complexity batch
Status: completed

Goal:
- move Docker storage list surfaces into their own file while keeping the rest of the Docker list feature stable

Done definition:
- network and volume list widgets no longer live in `docker_lists.dart`
- the remaining file is materially narrower around container and image surfaces
- focused Docker validation stays green

Result:
- Docker storage list surfaces now live in:
  - [docker_storage_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_storage_lists.dart)
- shared list helpers needed by both files now live in:
  - [docker_lists_helpers.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists_helpers.dart)
- the remaining mixed-surface file is narrowed:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)

## Task 28.4: define the next bounded local complexity batch
Status: completed

Goal:
- choose the next large file whose size still reflects multiple distinct local UI surfaces in one file
- keep the batch on file-level decomposition without reopening broader file explorer architecture work

Done definition:
- one explicit next batch is named from fresh current-state evidence
- the stop condition reflects a narrower file, not a behavior redesign

Result:
- the next bounded local-complexity batch is now:
  - split breadcrumb navigation widgets out of `path_navigator.dart`
- target files:
  - [path_navigator.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/path_navigator.dart)
  - new breadcrumb widget file under `lib/view/shared/views/shared/tabs/file_explorer/`
- stop condition:
  - breadcrumb view and breadcrumb button/menu widgets no longer live in the same file as the path text field and search shell
  - `PathNavigator` remains the public entry widget
  - behavior stays stable

Why this is the right next cut:
- `path_navigator.dart` is large because it still hosts two distinct local surfaces
- the breadcrumb subsystem is self-contained enough for a clean file split
- this improves navigation and maintenance without changing file explorer behavior

## Task 28.5: implement the breadcrumb split
Status: completed

Goal:
- move the breadcrumb navigation subsystem into its own file while keeping `PathNavigator` as the stable public shell

Done definition:
- breadcrumb widgets no longer live in `path_navigator.dart`
- the remaining file is materially narrower around path entry, search, and row-height behavior
- focused file-explorer validation stays green

Result:
- breadcrumb navigation widgets now live in:
  - [path_breadcrumbs_view.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/path_breadcrumbs_view.dart)
- the remaining path navigator shell is narrowed:
  - [path_navigator.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/path_navigator.dart)

## Task 28.6: define the next bounded local complexity batch
Status: completed

Goal:
- choose the next large file whose size still reflects multiple distinct local surfaces in one file
- prefer a pure file-level split over runtime-heavy files whose size is mostly one coherent responsibility

Done definition:
- one explicit next batch is named from fresh current-state evidence
- the stop condition narrows one file without reopening broader architecture work

Result:
- the next bounded local-complexity batch is now:
  - split the performance tab surface out of `debug_logs_view.dart`
- target files:
  - [debug_logs_view.dart](/home/home/personal/cwatch/lib/view/features/debug_logs/debug_logs_view.dart)
  - new performance-panel widget file under `lib/view/features/debug_logs/`
- stop condition:
  - the performance tab widget tree and its local rendering helpers no longer live in the same file as the debug log table panel
  - `DebugLogsView` remains the public entry widget
  - behavior stays stable

Why this is the right next cut:
- `debug_logs_view.dart` still hosts two genuinely separate tab panels
- the performance panel has a self-contained filter/chart surface
- this improves navigation and maintenance without redesigning logging behavior

## Task 28.7: implement the performance panel split
Status: completed

Goal:
- move the debug-log performance tab surface into its own file while keeping the top-level debug logs screen stable

Done definition:
- the performance panel and its local chart/render helpers no longer live in `debug_logs_view.dart`
- the remaining file is materially narrower around the tab shell and networking log table
- focused validation stays green

Result:
- debug-log performance tab widgets now live in:
  - [debug_logs_performance_panel.dart](/home/home/personal/cwatch/lib/view/features/debug_logs/debug_logs_performance_panel.dart)
- the remaining debug logs shell is narrowed:
  - [debug_logs_view.dart](/home/home/personal/cwatch/lib/view/features/debug_logs/debug_logs_view.dart)
