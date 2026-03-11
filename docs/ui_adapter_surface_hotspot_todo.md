# UI Adapter Surface Hotspot TODO

Status: active
Purpose: track bounded cleanup batches for the current controller-to-UI adapter surface reduction hotspot.

## Task 29.1: start the UI-adapter hotspot pass
Status: completed

Goal:
- treat UI-adapter surface reduction as the next active repo hotspot after the config metadata checkpoint
- keep this pass focused on shrinking controller dependencies on concrete widget-era adapters, not on replacing working dialogs wholesale

Done definition:
- there is one active UI-adapter TODO for the new pass
- the first bounded batch is named from the current code state

Result:
- UI-adapter surface reduction is now the active hotspot pass
- the first bounded batch should narrow one repeated workflow seam shared by multiple controllers

## Task 29.2: define the first bounded UI-adapter batch
Status: completed

Goal:
- choose one concrete adapter-coupling slice with real reuse and low behavior risk
- keep the first batch on port-forward interaction flow rather than broad Docker/settings dialog work

Done definition:
- one first batch is explicit
- the stop condition reflects the current concrete-adapter coupling shape

Result:
- the first bounded UI-adapter batch is now:
  - extract a controller-facing port-forward UI contract and route server/docker port-forward workflow through it
- target files:
  - [server_port_forward_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/server_port_forward_controller.dart)
  - [docker_overview_actions_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/docker_overview_actions_controller.dart)
  - existing server/docker UI adapters
  - new focused helper/contract under `lib/controller/`
- stop condition:
  - the shared port-forward dialog/snackbar workflow no longer forces controllers to depend directly on feature-specific adapter classes
  - Docker port-forward orchestration is isolated from the broader Docker action controller
  - focused regression coverage exists for the new controller-facing seam

Why this is the right first cut:
- server and Docker both expose the same prompt/start/snackbar port-forward flow
- that workflow is more reusable and controller-shaped than the rest of the Docker adapter surface
- this creates a real decoupling seam without reopening the wider settings or Docker dialog stacks

## Task 29.3: define the next bounded UI-adapter batch
Status: completed

Goal:
- choose the next controller-facing workflow seam from the current UI-adapter state
- keep the batch on a dense prompt/confirm flow instead of broad adapter replacement

Done definition:
- one next batch is explicit
- the stop condition reflects a real controller-to-adapter coupling seam still present in the codebase

Result:
- the next bounded UI-adapter batch is now:
  - extract built-in SSH key prompt/confirm workflow out of `SettingsController`
- target files:
  - [settings_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/settings_controller.dart)
  - [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)
  - new settings key workflow seam under `lib/controller/`
- stop condition:
  - built-in SSH key interaction flow no longer lives inline in `SettingsController`
  - the extracted key workflow depends on a narrower key-specific UI contract rather than the full settings adapter surface
  - focused regression coverage exists for the new key workflow seam

Why this is the right next cut:
- the built-in SSH key flow is the densest remaining prompt/confirm/snackbar block in settings
- it is workflow-local and materially more dialog-shaped than the generic settings mutation methods
- extracting it narrows both controller size and concrete adapter coupling without reopening the whole settings surface

## Task 29.4: define the next bounded UI-adapter batch
Status: completed

Goal:
- choose the next Docker-specific display/prompt seam from the current UI-adapter state
- keep the batch on a cohesive feedback/display workflow rather than broad action-controller breakup

Done definition:
- one next batch is explicit
- the stop condition reflects a real concrete-adapter coupling seam still present in `DockerOverviewActionsController`

Result:
- the next bounded UI-adapter batch is now:
  - extract Docker inspect/history/log-display workflow behind a narrower display UI contract
- target files:
  - [docker_overview_actions_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/docker_overview_actions_controller.dart)
  - [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)
  - new Docker display workflow seam under `lib/controller/`
- stop condition:
  - inspect/history/log snapshot presentation no longer lives inline in the broad Docker action controller
  - the extracted workflow depends on a narrower display UI contract instead of the full Docker adapter
  - focused regression coverage exists for the new display seam

Why this is the right next cut:
- this is the clearest remaining Docker adapter-coupling block after the port-forward split
- the workflow is cohesive: load content, map errors, and present dialogs/snackbars
- extracting it narrows controller responsibility without forcing a larger Docker action redesign
