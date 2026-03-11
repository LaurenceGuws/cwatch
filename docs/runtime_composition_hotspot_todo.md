# Runtime Composition Hotspot TODO

Status: active
Purpose: track the next bounded cleanup batches for the current highest-value repo hotspot: runtime and composition ownership.

## Task 25.1: start the runtime/composition hotspot pass
Status: completed

Goal:
- treat runtime/composition ownership cleanup as the first active hotspot from the fresh current-state review
- keep this pass focused on ownership clarity, not on broad layer replacement

Done definition:
- there is one runtime/composition TODO for the new pass
- the first bounded batch is named

Result:
- runtime/composition ownership is now the active repo hotspot
- the first bounded batch should reduce ownership blur without reopening already-checkpointed Docker, SSH, theme, or table internals

## Task 25.2: define the first bounded runtime/composition batch
Status: completed

Goal:
- choose one concrete cleanup slice with strong ownership value and low ambiguity

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later concerns remain queued instead of over-planned

Result:
- the first bounded runtime/composition batch is now:
  - server workspace runtime ownership cleanup
- target files:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
  - [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
  - related server feature files only as needed
- stop condition:
  - server workspace runtime assembly, persistence ownership, and feature-local controller ownership are easier to locate from one feature seam
  - no Docker, SSH, theme, or StructuredDataTable reopening is mixed into this batch
  - behavior stays stable

Why this is the right first cut:
- server workspace assembly currently shows the ownership blur clearly
- it sits at the intersection of bindings, view-hosted workflow ownership, and runtime bags
- it is a better proving slice for the new hotspot than reopening already-reduced subsystem internals

## Queued Next Batches

These are intentionally not yet active:
- workspace-shell hosting reuse across Docker/Server/WSL
- settings mutation/composition cleanup
- SSH factory/runtime-cache simplification
- file-operation UI deduplication
- config metadata single-source-of-truth cleanup

## Task 25.3: define the first server runtime ownership cut
Status: completed

Goal:
- choose one concrete ownership seam inside the server workspace runtime setup
- keep the batch focused on feature-local runtime assembly rather than broad workspace redesign

Done definition:
- one server runtime ownership seam is explicit
- the stop condition is clear from the current file shape

Result:
- the first implementation batch is now:
  - move server runtime assembly into the server feature runtime seam
- target files:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- stop condition:
  - server-specific runtime assembly no longer lives in a dedicated cross-folder binding
  - the server feature runtime is the obvious place to find server runtime construction
  - behavior stays stable

Why this is the right first cut:
- the current binding is only used by the server feature view
- the assembly logic is feature-specific rather than shared DI infrastructure
- moving it feature-local improves ownership clarity without changing runtime behavior

## Task 25.4: implement the first server runtime ownership cut
Status: completed

Goal:
- move server workspace runtime construction into the server feature runtime seam

Done definition:
- [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart) owns server-specific runtime assembly through a feature-local constructor/factory
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) no longer depends on a dedicated server workspace binding
- the deleted binding did not provide shared reuse beyond this feature

Result:
- server-specific runtime assembly now lives in:
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
- the server workspace view now depends directly on the feature runtime seam:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- the dedicated cross-folder server binding was removed:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
