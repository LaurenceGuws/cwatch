# Dependency Direction TODO

Status: active
Purpose: track dependency cleanup work in a way that is actionable now without over-specifying the later rewrite.

## How To Use This Document

This is a working TODO, not a fixed migration script.

Use it to:
- identify the current hotspot we are cleaning up
- define the next small batch of work
- record what "done" means for that batch
- re-scope the following batch based on what we learn

Do not treat the later hotspot notes as locked implementation plans.

## Working Rules

### Dependency rules we are moving toward
- reusable shell/framework code may depend on shared non-feature UI and infrastructure
- feature modules may depend on reusable shell/framework primitives
- reusable shell/framework code should not depend on feature-specific view implementations except through explicit module registration or contracts
- `view/` may depend on `controller/` and `model/`
- `controller/` should not depend on concrete `view/` widgets or feature-local view helpers unless the dependency is an explicit composition contract
- `model/` should not depend on `view/` or `controller/`
- anything used by `model/` or `controller/` cannot live in a view-local utility path
- service creation should not be entangled with concrete screen ownership
- shell/workspace infrastructure should still function if SSH, Docker, Kubernetes, or WSL modules are removed
- reusable widgets/helpers needed across features must not live under one feature tree

### Rewrite discipline rules
- clean one hotspot at a time
- prefer small extractions over broad relocations
- re-evaluate the plan after each hotspot
- do not commit to later file moves until the current hotspot is understood
- update this document when new ownership facts are discovered

## Current Dependency Reality

Observed patterns from the current codebase:
- `controller -> view` imports are common and span workspace code, adapters, feature module entrypoints, and bindings
- `model -> view` imports exist in explorer services, theme/config utilities, and shared mixins
- `model -> controller` imports exist and indicate reversed dependency flow
- `view` depends on both `controller` and `model`, which is acceptable for now, but it currently also owns too much orchestration

Representative examples:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/controller/adapters/explorer_ui_adapter.dart`
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/controller/di/bindings/home_shell_services_binding.dart`
- `lib/model/services/explorer_ops.dart`
- `lib/model/services/path_loading_service.dart`
- `lib/model/services/file_editing_service.dart`
- `lib/model/shared/theme/theme_config_loader.dart`

## Violation Categories

### Category A: non-UI logic depends on view-local utilities
Examples seen now:
- `lib/model/services/file_editing_service.dart` -> `view/.../path_utils.dart`
- `lib/model/services/path_loading_service.dart` -> `view/.../path_utils.dart`
- `lib/model/services/explorer_ops.dart` -> `view/.../path_utils.dart`
- `lib/model/services/explorer_ops.dart` -> `view/.../selection_controller.dart`
- `lib/controller/controllers/file_explorer_controller.dart` -> multiple `view/.../file_explorer/*` helpers

### Category B: controller layer imports concrete widgets and UI helpers
Examples seen now:
- workspace and module wiring importing feature views directly
- adapters importing dialogs and widget-specific helpers
- bindings importing tab builders and feature-specific view-side types

### Category C: model layer imports controller types
Examples seen now:
- `lib/model/services/explorer_ops.dart` -> `controller/controllers/explorer_state.dart`
- `lib/model/services_infra/ssh/ssh_auth_prompter.dart` exporting controller adapter

### Category D: ownership is split unclearly across `view/` and `controller/`
Examples seen now:
- workspace-controller-style classes under `lib/view/features/*`
- feature registration and screen ownership mixed across `view/` and `controller/`

## Hotspot Order

This is an investigation order, not a locked delivery roadmap.

### Hotspot 1: file explorer dependency knot
Why first:
- strongest `model -> view` and `model -> controller` signals
- central to remote file, editor, and SSH flows
- likely to teach us the most about how shared helpers should be split

Current files in scope:
- `lib/controller/controllers/file_explorer_controller.dart`
- `lib/model/services/explorer_ops.dart`
- `lib/model/services/path_loading_service.dart`
- `lib/model/services/file_editing_service.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/path_utils.dart`
- `lib/view/shared/views/shared/tabs/file_explorer/selection_controller.dart`

### Hotspot 2: app shell and module registration
Why next:
- it shapes the dependency graph for the whole app
- current module/binding ownership is unclear

### Hotspot 3: docker feature shell
Why likely after that:
- large surface area
- heavy overlap between view, controller, and bindings

### Hotspot 4: servers and kubernetes workspace shells
Why later:
- likely similar cleanup pattern to docker
- should be re-scoped once earlier hotspots teach us the better pattern

## Baseline Queries

Use these before and after each hotspot pass:

```bash
rg -n "package:cwatch/view/" lib/model
rg -n "package:cwatch/controller/" lib/model
rg -n "package:cwatch/view/" lib/controller
```

## Current Work: Hotspot 1

## Goal
Remove the worst file-explorer-related dependency direction violations without guessing the final explorer architecture upfront.

## Current batch

### Task 1.1: move path utilities out of `view/`
Status: completed

Why this is first:
- it is the clearest `model/controller -> view` violation
- it is likely low-risk compared with changing workflow ownership immediately

Actions:
- inspect `file_explorer/path_utils.dart`
- separate non-UI helpers from UI-only helpers
- move non-UI helpers to a neutral location
- update imports in `model/`, `controller/`, and `view/`
- record what remains coupled after the move

Done definition:
- `model/` no longer imports `view/.../path_utils.dart`
- `controller/` no longer imports `view/.../path_utils.dart`, or any temporary exception is explicitly recorded here
- the new location makes ownership clearer than before

Verification:
- `rg -n "path_utils.dart" lib/model lib/controller`
- `flutter analyze`
- manual smoke check of explorer navigation/path operations

### Task 1.2: re-scope after path utility extraction
Status: completed

### Task 1.3: inspect and split selection ownership
Status: completed

### Task 1.4: inspect explorer state ownership
Status: completed

### Explorer hotspot checkpoint
Status: completed

Outcome:
- explorer path helpers now live outside `view/`
- explorer selection state now has a non-UI core
- explorer state now lives outside `controller/`
- the explorer hotspot no longer contributes `model -> view` or `model -> controller` imports

Note:
- file explorer still has `controller -> view` dependencies through view-side input/controller classes, but those are not the highest-value next target compared with shell/module ownership

Why this is next:
- it is now the clearest remaining `model -> controller` dependency inside the explorer hotspot
- the selection split reduced coupling without requiring a broad redesign, which suggests state ownership can be tackled the same way

Actions:
- inspect `controller/controllers/explorer_state.dart` and how `ExplorerOps` uses it
- separate reusable explorer state from controller-only concerns if that split is clean
- move the reusable part to a neutral location and update imports

Done definition:
- `lib/model/services/explorer_ops.dart` no longer imports `package:cwatch/controller/`
- explorer state ownership is clearer than it is today

Verification:
- `rg -n "package:cwatch/controller/" lib/model`
- `flutter analyze`
- manual smoke check of explorer load/search/navigation behavior

Why this is next:
- it is the next clear `model -> view` dependency in the explorer hotspot
- the path utility extraction suggests this can likely be another narrow ownership fix

Actions:
- inspect `selection_controller.dart` for reusable state logic versus widget interaction concerns
- move reusable selection logic out of `view/` if it is not UI-specific
- update `ExplorerOps` and any controller/view imports accordingly

Done definition:
- `lib/model/services/explorer_ops.dart` no longer imports a view-local selection controller
- selection ownership is clearer than it is today, even if the final explorer architecture is still in progress

Verification:
- `rg -n "selection_controller.dart" lib/model lib/controller`
- `flutter analyze`
- manual smoke check of explorer selection behavior

Purpose:
- decide the next explorer cleanup step based on what the code looks like after Task 1.1
- avoid pretending we already know whether selection state, explorer state, or controller cleanup should come next

Done definition:
- the next explorer task is written based on the post-1.1 state of the code
- any newly discovered exceptions or ownership facts are recorded here

Verification:
- follow-up task added to this document before the next structural change starts

Result of re-scope:
- `path_utils.dart` was purely non-UI and moved cleanly to `lib/model/shared/services/path_utils.dart`
- selection state split cleanly into non-UI core plus view-side input handling
- the main remaining explorer dependency problem is state ownership via `ExplorerState`
- the next batch should focus on `ExplorerState`, not a broader explorer refactor

## Later Hotspots

Do not expand these into detailed task trees until the current hotspot is partially cleaned up.

### App shell and module registration
Track here when ready:
- remove misleading `controller -> view` ownership patterns
- clarify where module descriptors live
- separate service construction from screen ownership

Done definition for starting this hotspot:
- file explorer hotspot has produced a stable pattern worth reusing
- we can describe the next batch concretely from current code, not guesses

Current next-step note:
- shell/module ownership reached a checkpoint (`docs/shell_module_ownership_todo.md`)
- docker overview ownership reached a checkpoint (`docs/docker_workspace_ownership_todo.md`)
- workspace-core tab ownership reached a checkpoint (`docs/workspace_core_ownership_todo.md`)
- explorer controller/adapter ownership reached a checkpoint (`docs/explorer_ui_adapter_ownership_todo.md`)
- server/WSL binding ownership reached a checkpoint (`docs/server_wsl_binding_ownership_todo.md`)
- UI-adapter dialog/content ownership reached a checkpoint (`docs/ui_adapter_dialog_ownership_todo.md`)
- `lib/model` now has no `package:cwatch/controller/` imports
- tab-assembly ownership reached a checkpoint under the shell/framework vs removable feature-module boundary (`docs/tab_assembly_ownership_todo.md`)
- WSL and server now establish the pattern: feature-specific tab assembly belongs to the feature module, while workspace restoration logic should depend on narrow callbacks/contracts
- the next dependency-direction batch is shared theme registry ownership (`docs/theme_registry_ownership_todo.md`)
- this is the strongest remaining `model -> view` seam and is now a reusable shell/framework ownership issue rather than a feature-module ownership issue
- shared theme registry ownership reached a checkpoint and removed the `theme_config_loader -> editor view path` dependency
- `lib/model` now also no longer imports controller workspace tab-option types through `tab_options_mixin.dart`
- the next remaining ownership cleanup is feature-specific UI adapters versus acceptable shared-shell UI dependencies (`docs/feature_ui_adapter_ownership_todo.md`)
- feature-specific UI adapter ownership reached a checkpoint; remaining adapter-side widget imports are now mostly explicit shared-shell UI usage

### Docker feature shell
Track here when ready:
- clarify ownership of docker workflow classes versus presentation classes
- reduce controller imports of docker view-side helpers

Done definition for starting this hotspot:
- shell/module ownership rules are clearer than they are today

### Servers and Kubernetes shells
Track here when ready:
- reduce shell widgets owning broad workflow coordination
- normalize naming and ownership of workspace-style classes

Done definition for starting this hotspot:
- docker or shell cleanup has produced a reusable pattern

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 0 | Rules and baseline queries | active | rules are documented and queries are reusable |
| 1.1 | Explorer path utilities | completed | non-UI path helpers no longer live under `view/` |
| 1.2 | Explorer re-scope | completed | next explorer task is written from what we learned in 1.1 |
| 1.3 | Explorer selection ownership | completed | model no longer depends on view-local selection logic |
| 1.4 | Explorer state ownership | completed | model no longer depends on controller-owned explorer state |
| 2 | Shell/module hotspot | queued | re-scoped after explorer cleanup |
| 3 | Docker hotspot | queued | re-scoped after earlier hotspots |
| 4 | Servers/Kubernetes hotspot | queued | re-scoped after earlier hotspots |

## Repo-level checkpoint

Current state:
- `lib/model` has no imports from `package:cwatch/controller/`
- explorer hotspot model-side dependency cleanup is complete
- shell/module ownership reached a checkpoint
- docker overview ownership reached a checkpoint
- workspace-core tab ownership reached a checkpoint
- explorer controller/adapter ownership reached a checkpoint
- server/WSL binding ownership reached a checkpoint
- UI-adapter dialog/content ownership reached a checkpoint
- the next dependency-direction work is tab-assembly ownership

## Completion Metric

This document is serving its purpose if:
- it tells us what to work on next
- each finished batch has a clear done definition
- later work is re-scoped from current knowledge instead of guessed months in advance
- dependency violations trend downward after each hotspot pass
