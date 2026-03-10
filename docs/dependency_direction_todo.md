# Dependency Direction TODO

Status: active
Purpose: convert the dependency-direction review into an actionable execution backlog with explicit completion criteria.

## Outcome This Document Targets

This document is done only when the repository has:
- explicit dependency rules for `view`, `controller`, `model`, and `services_infra`
- tracked removal of current dependency violations by hotspot
- a defined migration order for the highest-risk areas
- per-task verification steps and definition of done

This is not just an architecture note. It is the working checklist for fixing dependency direction.

## Current Dependency Reality

Observed patterns from the current codebase:
- `controller -> view` imports are common and span workspace code, adapters, feature module entrypoints, and bindings.
- `model -> view` imports exist in explorer services, theme/config utilities, and shared mixins.
- `model -> controller` imports exist and indicate reversed dependency flow.
- `view` depends on both `controller` and `model`, which is acceptable in the short term, but it currently also owns too much orchestration.

Representative examples:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/controller/adapters/explorer_ui_adapter.dart`
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/controller/di/bindings/home_shell_services_binding.dart`
- `lib/model/services/explorer_ops.dart`
- `lib/model/services/path_loading_service.dart`
- `lib/model/services/file_editing_service.dart`
- `lib/model/shared/theme/theme_config_loader.dart`

## Target Dependency Rules

### Rule 1: `view/` may depend on `controller/` and `model/`
Allowed because Flutter UI needs shaped state and domain models during the migration period.

### Rule 2: `controller/` must not depend on concrete `view/` widgets or view-local helpers
Exceptions should be temporary and tracked here until removed.

### Rule 3: `model/` must not depend on `view/` or `controller/`
This is the most important cleanup rule.

### Rule 4: view-local utilities must live in `view/`; shared non-UI utilities must live outside `view/`
Anything used by `model/` or `controller/` cannot remain in a view-local path.

### Rule 5: composition and bindings must build non-UI objects without importing concrete screens
Feature registration may reference view constructors, but service creation and bindings should not rely on view-owned types.

## Violation Categories

### Category A: non-UI logic depends on view-local utilities
Current examples:
- `lib/model/services/file_editing_service.dart` -> `view/.../path_utils.dart`
- `lib/model/services/path_loading_service.dart` -> `view/.../path_utils.dart`
- `lib/model/services/explorer_ops.dart` -> `view/.../path_utils.dart`
- `lib/model/services/explorer_ops.dart` -> `view/.../selection_controller.dart`
- `lib/controller/controllers/file_explorer_controller.dart` -> multiple `view/.../file_explorer/*` helpers

Impact:
- prevents extraction of domain logic from UI
- makes file explorer cleanup harder because shared logic is hiding in widget folders

### Category B: controller layer imports concrete widgets and UI helpers
Current examples:
- workspace and module wiring importing feature views directly
- adapters importing dialogs, dialog wrappers, and widget-specific helpers
- bindings importing tab builders and feature-specific view controllers from `view/`

Impact:
- controllers are not pure workflow/orchestration units
- difficult to replace presentation or test controller logic separately

### Category C: model layer imports controller types
Current examples:
- `lib/model/services/explorer_ops.dart` -> `controller/controllers/explorer_state.dart`
- `lib/model/services_infra/ssh/ssh_auth_prompter.dart` exporting controller adapter

Impact:
- creates circular conceptual ownership
- blocks clean service extraction

### Category D: view-local controllers/builders are split across `view/` and `controller/`
Current examples:
- `lib/view/features/docker/docker_workspace_controller.dart`
- `lib/view/features/servers/server_workspace_controller.dart`
- `lib/view/features/kubernetes/kubernetes_workspace_controller.dart`
- `lib/view/features/wsl/wsl_workspace_controller.dart`

Impact:
- naming and ownership are misleading
- hard to tell which classes are presentation-only versus workflow state

## Hotspot Ranking

### Hotspot 1: file explorer dependency knot
Why first:
- strongest evidence of `model -> view` and `model -> controller`
- central to remote file operations, editor flows, and SSH workflows
- many cross-layer helpers live in view paths

Key files:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/model/services/explorer_ops.dart`
- `lib/model/services/path_loading_service.dart`
- `lib/model/services/file_editing_service.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/path_utils.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/selection_controller.dart`

### Hotspot 2: app shell and module registration
Why second:
- composition and module registration shape the dependency graph for the whole app
- current bindings and module files blur view construction with service creation

Key files:
- `lib/view/core/navigation/home_shell_controller.dart`
- `lib/view/core/navigation/home_shell_modules.dart`
- `lib/controller/di/bindings/home_shell_services_binding.dart`
- `lib/controller/features/*/view.dart`
- `lib/controller/features/*_module.dart`

### Hotspot 3: docker feature shell and related bindings
Why third:
- large orchestration surface
- view/controller/binding overlap is severe
- one of the biggest feature shells by size

Key files:
- `lib/view/features/docker/docker_view.dart`
- `lib/controller/controllers/docker_overview_actions_controller.dart`
- `lib/controller/di/bindings/docker_*`
- `lib/view/features/docker/docker_tab_builder.dart`
- `lib/view/features/docker/docker_workspace_controller.dart`

### Hotspot 4: servers and kubernetes workspace shells
Why fourth:
- same pattern as docker, slightly lower urgency than file explorer and shell composition

Key files:
- `lib/view/features/servers/server_workspace_view.dart`
- `lib/view/features/kubernetes/kubernetes_context_list.dart`
- `lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart`

## Execution Plan

## Phase 0: establish enforcement baseline

### Task 0.1: create dependency rule summary in docs
Status: completed

Actions:
- keep this document as the source of truth for dependency cleanup
- add follow-up references from rewrite planning docs when new deep-dives are created

Done definition:
- current dependency rules are documented
- hotspot ordering is documented
- each hotspot has explicit tasks and verification steps

Verification:
- doc reviewed for completeness
- linked from `docs/rewrite_foundations.md`

### Task 0.2: create simple violation inventory queries
Status: completed

Actions:
- standardize `rg` queries for `model -> view`, `model -> controller`, and `controller -> view`
- record them in this doc so future passes use the same baseline

Done definition:
- repeatable commands exist for counting violations
- commands can be rerun after each hotspot cleanup

Verification:
- command list stored in this doc
- commands run successfully in repo root

Suggested commands:
```bash
rg -n "package:cwatch/view/" lib/model
rg -n "package:cwatch/controller/" lib/model
rg -n "package:cwatch/view/" lib/controller
```

## Phase 1: file explorer dependency extraction

### Task 1.1: move path utilities out of `view/`
Status: pending

Actions:
- identify all non-UI path helpers in `file_explorer/path_utils.dart`
- move them to a non-UI shared location
- update imports in `model/`, `controller/`, and `view/`

Done definition:
- `model/` no longer imports `view/.../path_utils.dart`
- `controller/` no longer imports `view/.../path_utils.dart` unless a temporary exception is recorded
- path helper ownership is obvious from the new location

Verification:
- `rg -n "path_utils.dart" lib/model lib/controller` shows only non-view path references
- `flutter analyze`
- targeted explorer flows still work

### Task 1.2: split selection logic from widget-local code
Status: pending

Actions:
- inspect `selection_controller.dart` for UI-specific versus reusable logic
- move reusable selection/domain state out of `view/`
- leave widget interaction concerns in `view/`

Done definition:
- `model/services/explorer_ops.dart` does not import a view-local selection class
- selection ownership is split into reusable state logic vs widget behavior

Verification:
- `rg -n "selection_controller.dart" lib/model`
- `flutter analyze`
- focused explorer interaction checks

### Task 1.3: remove `model -> controller` dependency from explorer state
Status: pending

Actions:
- move `ExplorerState` to a neutral location or split it into model-safe state and controller/view concerns
- update `ExplorerOps` to depend only on neutral state abstractions

Done definition:
- no `package:cwatch/controller/` imports remain under `lib/model/services/explorer_ops.dart`
- explorer state ownership is explicit

Verification:
- `rg -n "package:cwatch/controller/" lib/model`
- `flutter analyze`
- explorer regression checks

### Task 1.4: reduce `FileExplorerController` reliance on view-local helpers
Status: pending

Actions:
- move drag/path/selection logic to neutral modules where appropriate
- leave concrete widget composition and dialogs in UI adapters or widgets

Done definition:
- `FileExplorerController` only depends on UI adapters for UI behavior, not widget-local utility modules
- cross-layer imports from controller to explorer view helpers are substantially reduced or eliminated

Verification:
- `rg -n "package:cwatch/view/" lib/controller/controllers/file_explorer_controller.dart`
- `flutter analyze`
- explorer open/search/navigate/edit smoke checks

## Phase 2: shell composition and module registration cleanup

### Task 2.1: separate feature registration from feature screen construction
Status: pending

Actions:
- audit `controller/features/*/view.dart` and `*_module.dart`
- define whether feature descriptors live in `view/` or `controller/`, then normalize
- stop exporting view screens through controller paths

Done definition:
- feature registration has a single ownership pattern
- controller-layer exports no longer masquerade as screen ownership

Verification:
- `rg -n "export 'package:cwatch/view/" lib/controller`
- `flutter analyze`
- app shell navigation still loads all modules

### Task 2.2: move service creation out of view-adjacent bindings where possible
Status: pending

Actions:
- audit `home_shell_services_binding.dart` and related bindings
- separate app/service composition from feature view types
- reduce imports from bindings into view-owned classes unless strictly presentation-related

Done definition:
- service bindings build services without depending on concrete screens
- composition root responsibilities are clearer than today

Verification:
- `rg -n "package:cwatch/view/" lib/controller/di/bindings`
- `flutter analyze`
- home shell bootstrap smoke check

## Phase 3: docker feature cleanup

### Task 3.1: define docker presentation ownership
Status: pending

Actions:
- decide which of `docker_view.dart`, `docker_workspace_controller.dart`, `docker_tab_builder.dart`, and controller-layer docker classes are presentation-only
- rename or relocate classes so ownership is obvious

Done definition:
- no ambiguity remains about where docker workflow state lives
- presentation-only classes do not sit in controller/model namespaces incorrectly

Verification:
- file map updated in docs
- `flutter analyze`

### Task 3.2: remove controller dependencies on docker view helpers
Status: pending

Actions:
- inspect `docker_overview_actions_controller.dart` and docker bindings importing view-side helpers
- extract neutral interfaces or move ownership to presentation layer

Done definition:
- controller-layer docker orchestration does not depend on concrete docker view helpers
- any remaining exceptions are documented with removal follow-up

Verification:
- `rg -n "package:cwatch/view/features/docker" lib/controller`
- `flutter analyze`
- docker context/open-tab smoke checks

## Phase 4: servers and kubernetes cleanup

### Task 4.1: normalize workspace controller ownership
Status: pending

Actions:
- audit workspace controllers under `lib/view/features/*/*workspace_controller.dart`
- decide whether each is a presentation state holder or should move out of `view/`
- apply one naming/placement rule across features

Done definition:
- workspace controller naming and ownership are consistent across docker, servers, kubernetes, and wsl
- docs reflect the chosen rule

Verification:
- file ownership table updated
- `flutter analyze`

### Task 4.2: reduce server/kubernetes view-shell orchestration responsibilities
Status: pending

Actions:
- move non-rendering logic out of `server_workspace_view.dart` and `kubernetes_context_list.dart`
- isolate UI composition from feature coordination

Done definition:
- feature shell widgets are primarily responsible for composition/rendering
- workflow coordination has a clear non-widget owner

Verification:
- hotspot file sizes reduced meaningfully or responsibilities split into clearly named collaborators
- `flutter analyze`

## Cross-Cutting Rules For Every Hotspot

### Before starting a hotspot
- capture current violations with the standard `rg` queries
- define the exact file ownership target
- add or identify characterization tests needed before moving behavior

### During implementation
- do not move code without clarifying ownership
- avoid replacing one bad dependency direction with another
- prefer extracting neutral helpers over adding more adapters around confused ownership

### Hotspot done definition
A hotspot is only complete when all of the following are true:
- the targeted violation class has been removed or reduced to explicitly tracked exceptions
- ownership of moved code is clear from path and name
- `flutter analyze` passes
- targeted regression tests exist or documented manual verification was completed if tests are not yet in place
- this document is updated to mark the task complete and note any follow-up exceptions

## Tracking Table

| Task | Scope | Status | Blocking Items | Done When |
| --- | --- | --- | --- | --- |
| 0.1 | Rule summary | completed | none | doc is source of truth and linked from rewrite docs |
| 0.2 | Violation queries | completed | none | repeatable queries documented and used |
| 1.1 | Explorer path helpers | pending | none | no `model/controller -> view/path_utils` dependency |
| 1.2 | Explorer selection logic | pending | 1.1 may influence | no `model -> view/selection_controller` dependency |
| 1.3 | Explorer state ownership | pending | 1.2 may influence | no `model -> controller` dependency in explorer services |
| 1.4 | Explorer controller cleanup | pending | 1.1-1.3 | controller no longer depends on explorer view helpers |
| 2.1 | Feature registration ownership | pending | none | no controller-exported view ownership pattern |
| 2.2 | Shell/service composition | pending | 2.1 helpful | bindings/service creation decoupled from screens |
| 3.1 | Docker ownership map | pending | 2.x helpful | docker presentation/workflow ownership is explicit |
| 3.2 | Docker controller cleanup | pending | 3.1 | reduced `controller -> docker view` dependencies |
| 4.1 | Workspace controller normalization | pending | 2.x helpful | consistent naming/location across features |
| 4.2 | Server/K8s shell decomposition | pending | 4.1 helpful | shell widgets no longer own broad coordination |

## Completion Metric

This deep-dive is complete when:
- `lib/model` has zero imports from `package:cwatch/view/`
- `lib/model` has zero imports from `package:cwatch/controller/`
- `lib/controller` imports from `package:cwatch/view/` are limited to explicitly accepted presentation boundaries and listed exceptions
- the file explorer hotspot is fully closed first, then the shell registration hotspot, then docker, then servers/kubernetes
- follow-up deep-dives can build on the cleaned dependency rules instead of re-litigating ownership
