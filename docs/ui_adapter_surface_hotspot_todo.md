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
