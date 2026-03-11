# Local Feature Complexity TODO

Status: active

## Purpose

The major cross-cutting rewrite layers are now checkpointed:
- dependency direction
- composition root ownership
- settings/state taxonomy
- integration smell cleanup
- vertical slice proving
- infrastructure boundary cleanup

The strongest remaining architectural weight is now local feature complexity.

This layer is about reducing the dense local behavior blocks that remain after the bigger ownership and boundary work is done.

It is not about reopening broad cross-cutting architecture.

## Scope

Focus on feature-local surfaces that still carry too many responsibilities in one file or one widget tree, even after the earlier slice work.

Typical targets:
- heavy local state orchestration
- dense async/UI coordination
- mixed rendering and workflow handling
- product-facing interaction complexity that is still hard to reason about

Out of scope for this layer:
- new dependency-direction rules
- new composition-root refactors across the app
- new settings taxonomy work
- broad infra gateway splitting

## Selection Rule

Pick the next batch based on:
1. highest local complexity still concentrated in one surface
2. lowest risk of re-opening already-stable cross-cutting layers
3. strongest product-facing payoff

## First Candidate Ranking

1. server host list and availability/probing surface
- still carries dense host rendering, probe state, distro warmup, and feature-level action behavior
- now isolated enough after the server shell split that local cleanup can target the real remaining complexity

2. explorer entry-list interaction surface
- still carries dense pointer/keyboard/selection behavior
- high leverage, but also higher interaction risk

3. docker local dashboard/picker state surface
- still carries probe and local scan state
- lower urgency than servers or explorer

4. kubernetes context-row/dashboard local state surface
- still complex, but less urgent after its shell split checkpoint

## Task 20.1: choose the first local complexity hotspot
Status: completed

Result:
- the first local complexity hotspot should be the server host list and availability/probing surface

Why this wins:
- it is still one of the heaviest remaining local feature surfaces
- earlier server slice work already removed the top-level shell orchestration from it
- the remaining complexity is real local product behavior, not cross-cutting glue
- it is a better next move than explorer entry-list interaction, which is denser and riskier

## Task 20.2: define the server host-surface cleanup boundary
Status: completed

Goal:
- define exactly what part of the remaining server-local complexity should be addressed first

Questions to answer:
- what should remain local to `server_workspace_view.dart`
- what should be split into a narrower server-local seam
- what state/probe behavior should not be pushed into generic shell code

Done definition:
- one bounded server-local cleanup seam is chosen
- the first implementation batch is clear

Result:
- the first server-local cleanup seam should be host-surface state and probing orchestration

What should remain local to `server_workspace_view.dart`:
- host list rendering and callback wiring
- add-server dialog flow
- placeholder-host selection composition
- tab/body composition for server-specific tabs
- local settings-window visibility state

What should be split into a narrower server-local seam:
- host loading result refresh state
- background availability probe scheduling
- custom-host availability refresh
- host-availability cache mutation
- deferred distro warmup tracking
- signature-based host reload coordination inputs used by the server shell

Why this is the right cut:
- this is the densest remaining non-rendering complexity in the file
- it is still purely server-local behavior, not reusable shell logic
- it avoids flattening `HostList` or feature-specific actions into fake generic code
- it gives one seam that owns the lifecycle of host refresh, probing, and distro warmup together

First implementation batch:
- extract a server-local host surface coordinator from `server_workspace_view.dart`
- keep it feature-owned under `lib/view/features/servers/`
- leave `HostList`, `ServerWorkspaceShell`, and `ServerTabBuilder` stable for the first batch

## Task 20.3: implement the server host-surface split
Status: completed

Goal:
- extract the server-local host refresh/probe/distro orchestration seam out of `server_workspace_view.dart`

First code targets:
- host loading and custom-host update flow
- background availability checks
- on-demand distro warmup tracking
- host future notifier updates and cached-host mutation helpers

What stays stable in this batch:
- `HostList`
- `ServerWorkspaceShell`
- `ServerTabBuilder`
- add-server flow
- placeholder replacement behavior

Done definition:
- `server_workspace_view.dart` no longer owns the full host refresh/probe lifecycle directly
- the extracted seam remains server-local and does not become a shared shell abstraction

Result:
- extracted [server_host_surface_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_host_surface_controller.dart) as the server-local host refresh/probe/distro coordination seam
- `server_workspace_view.dart` now delegates:
  - host loading
  - custom-host update flow
  - background availability checks
  - host future notifier updates
  - deferred distro warmup tracking
- `HostList`, `ServerWorkspaceShell`, and `ServerTabBuilder` stayed stable in this batch

## Task 20.4: re-scope the next server local-complexity batch
Status: completed

Goal:
- decide whether the next server-local cleanup should stay in `server_workspace_view.dart` or move to the next hotspot in the local complexity layer

Questions to answer:
- is there one more bounded server-local seam with real value
- or is the remaining server view weight now mostly valid local rendering/product behavior

Done definition:
- the next local-complexity move is explicit

Result:
- the server local-complexity hotspot is now at a good checkpoint
- the next active hotspot in this layer should move to explorer entry-list interaction complexity

Why this is the right stop:
- the previous batch already removed the densest remaining non-rendering server-local coordination
- what remains in `server_workspace_view.dart` is mostly valid feature-local behavior:
  - host list rendering and callback wiring
  - add-server flow
  - tab restoration and server-specific tab creation
  - local settings-window state
- extracting more now would likely create a fake local manager layer instead of a stronger architecture seam

Checkpoint summary:
- server host refresh/probe/distro coordination is now split into `server_host_surface_controller.dart`
- server local-complexity hotspot is checkpointed

## Task 20.5: choose the next local complexity hotspot
Status: completed

Result:
- the next local complexity hotspot should be explorer entry-list interaction complexity

Why this wins now:
- it remains one of the densest local interaction surfaces in the repo
- earlier explorer slice work already removed top-level orchestration and action workflow weight
- the remaining complexity is now concentrated in list interaction, pointer/keyboard handling, and selection-heavy behavior

## Task 20.6: define the explorer entry-list cleanup boundary
Status: completed

Goal:
- define exactly what part of the remaining explorer-local interaction complexity should be addressed first

Questions to answer:
- what should remain local to `file_explorer_tab.dart`
- what should be split into a narrower explorer-local seam
- what interaction behavior should not be pushed into shared shell code

Done definition:
- one bounded explorer-local cleanup seam is chosen
- the first implementation batch is clear

Result:
- the first explorer-local cleanup seam should be entry-list interaction wiring

What should remain local to `file_explorer_tab.dart`:
- top-level tab composition
- presenter/action seam composition
- path navigator hosting
- tab option updates
- desktop-drop hover state and outer drop-host wiring

What should be split into a narrower explorer-local seam:
- `FileEntryList` callback assembly
- selection-controller delegation for pointer and keyboard events
- copy/cut/paste/delete/rename keyboard action routing
- selected-entry lookup and drag-start wiring
- list-focus handoff and `markNeedsBuild` callback routing

Why this is the right cut:
- this is the densest remaining interaction block in the explorer tab
- it is still explorer-local behavior, not reusable shell infrastructure
- it avoids forcing selection semantics or drag behavior into generic list widgets
- it gives one seam that owns the mapping between entry-list events and explorer actions/selection state

First implementation batch:
- extract an explorer-local entry-list interaction helper from `file_explorer_tab.dart`
- keep it feature-owned under `lib/view/shared/views/shared/tabs/file_explorer/`
- leave `FileEntryList`, `SelectionController`, and `FileExplorerTabActions` stable for the first batch

## Task 20.7: implement the explorer entry-list interaction split
Status: completed

Goal:
- extract the explorer-local entry-list interaction wiring out of `file_explorer_tab.dart`

First code targets:
- entry pointer-down wiring
- drag-hover and drag-selection stop wiring
- keyboard action routing
- selected-entry lookup for drag/copy/cut/delete/rename
- `FileEntryList` callback assembly around selection and actions

What stays stable in this batch:
- `FileEntryList`
- `SelectionController`
- `FileExplorerTabActions`
- `FileExplorerTabPresenter`
- desktop-drop outer host behavior

Done definition:
- `file_explorer_tab.dart` no longer owns the dense entry-list interaction callback block directly
- the extracted seam remains explorer-local and does not become shared shell infrastructure

Result:
- extracted [file_explorer_tab_entry_interactions.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab_entry_interactions.dart) as the explorer-local entry-list interaction seam
- `file_explorer_tab.dart` now delegates:
  - `FileEntryList` callback assembly
  - selection-controller delegation for pointer and keyboard events
  - keyboard action routing for copy/cut/paste/delete/rename
  - drag-start selected-entry lookup
- `FileEntryList`, `SelectionController`, `FileExplorerTabActions`, and `FileExplorerTabPresenter` stayed stable in this batch

## Task 20.8: re-scope the next explorer local-complexity batch
Status: completed

Goal:
- decide whether the explorer local-complexity hotspot should continue or checkpoint here

Questions to answer:
- is there one more bounded explorer-local seam with real value
- or is the remaining explorer tab weight now mostly valid local interaction behavior

Done definition:
- the next local-complexity move is explicit

Result:
- the explorer local-complexity hotspot is now at a good checkpoint
- the next active hotspot in this layer should move to Docker local dashboard/picker state complexity

Why this is the right stop:
- the previous explorer batches already removed:
  - top-level presentation/orchestration
  - action/file-operation workflow routing
  - entry-list interaction callback assembly
- what remains in `file_explorer_tab.dart` is mostly valid explorer-local behavior:
  - outer drop-host wiring
  - path navigator composition
  - tab option updates
  - widget lifecycle glue
- extracting more now would likely create fake local wrappers instead of a stronger architecture seam

Checkpoint summary:
- explorer local-complexity hotspot is checkpointed

## Task 20.9: choose the next local complexity hotspot
Status: completed

Result:
- the next local complexity hotspot should be Docker local dashboard/picker state complexity

Why this wins now:
- it remains one of the heavier local feature shells after the earlier Docker slice checkpoint
- unlike explorer, it still has meaningful local state around context probing, remote scan state, picker readiness, and overlay coordination
- it is lower interaction risk than reopening more explorer pointer/selection work

## Task 20.10: define the Docker local state cleanup boundary
Status: completed

Goal:
- define exactly what part of the remaining Docker-local complexity should be addressed first

Questions to answer:
- what should remain local to `docker_view.dart`
- what should be split into a narrower Docker-local seam
- what state/probe behavior should not be pushed into generic shell code

Done definition:
- one bounded Docker-local cleanup seam is chosen
- the first implementation batch is clear

Result:
- the first Docker-local cleanup seam should be scan/probe/readiness state orchestration

What should remain local to `docker_view.dart`:
- tab shell composition and chip wiring
- rename-tab flow
- picker overlay visibility state
- dashboard-opening and child-tab opening flows
- workspace restore glue

What should be split into a narrower Docker-local seam:
- remote scan state and cancellation bookkeeping
- remote status future lifecycle
- scan progress notifier updates
- cached-ready state loading and picker refresh triggers
- local context probe/readiness future lifecycle
- host filtering and reachability/probe orchestration used by the picker surface

Why this is the right cut:
- this is the densest remaining non-rendering local state block in the Docker view
- it is still feature-local behavior, not shell or infra ownership
- it avoids flattening picker/dashboard UI into another fake shared layer
- it gives one seam that owns Docker picker readiness and scan lifecycle coherently

First implementation batch:
- extract a Docker-local scan/probe state coordinator from `docker_view.dart`
- keep it feature-owned under `lib/view/features/docker/`
- leave `DockerViewShell`, `DockerTabBuilder`, and infra service seams stable for the first batch

## Task 20.11: implement the Docker local state split
Status: completed

Goal:
- extract the Docker-local scan/probe/readiness orchestration seam out of `docker_view.dart`

First code targets:
- remote scan state and cancellation bookkeeping
- cached-ready load/update helpers
- local context status future lifecycle
- remote host filtering and probe coordination
- picker refresh triggers caused by scan/readiness updates

What stays stable in this batch:
- `DockerViewShell`
- `DockerTabBuilder`
- `EnginePicker`
- Docker infra service seams
- dashboard-opening flows

Done definition:
- `docker_view.dart` no longer owns the full scan/probe/readiness lifecycle directly
- the extracted seam remains Docker-local and does not become shared shell infrastructure

Result:
- extracted [docker_local_state_controller.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_local_state_controller.dart) as the Docker-local scan/probe/readiness seam
- `docker_view.dart` now delegates:
  - remote scan state and cancellation bookkeeping
  - cached-ready loading and notifier updates
  - local context status future lifecycle
  - remote host filtering and probe coordination
  - picker refresh triggers caused by readiness updates
- `DockerViewShell`, `DockerTabBuilder`, `EnginePicker`, and Docker infra seams stayed stable in this batch

## Task 20.12: re-scope the next Docker local-complexity batch
Status: completed

Goal:
- decide whether the Docker local-complexity hotspot should continue or checkpoint here

Questions to answer:
- is there one more bounded Docker-local seam with real value
- or is the remaining Docker view weight now mostly valid feature-local behavior

Done definition:
- the next local-complexity move is explicit

Result:
- the Docker local-complexity hotspot is now at a good checkpoint
- the next active hotspot in this layer should move to Kubernetes local context-row/dashboard state complexity

Why this is the right stop:
- the previous Docker batches already removed:
  - top-level shell orchestration
  - scan/probe/readiness state orchestration
- what remains in `docker_view.dart` is mostly valid Docker-local behavior:
  - picker overlay visibility
  - rename-tab flow
  - dashboard-opening and child-tab flows
  - workspace restore glue
- extracting more now would likely create a fake local manager layer instead of a stronger architecture seam

Checkpoint summary:
- Docker local-complexity hotspot is checkpointed

## Task 20.13: choose the next local complexity hotspot
Status: completed

Result:
- the next local complexity hotspot should be Kubernetes local context-row/dashboard state complexity

Why this wins now:
- it is the strongest remaining feature-local surface after the server, explorer, and Docker checkpoints
- the earlier Kubernetes shell split removed top-level orchestration, but local row/dashboard state is still concentrated in one feature surface
- it is the natural next hotspot before ending or checkpointing the local-complexity layer more broadly

## Task 20.14: define the Kubernetes local state cleanup boundary
Status: pending

Goal:
- define exactly what part of the remaining Kubernetes-local complexity should be addressed first

Questions to answer:
- what should remain local to `kubernetes_context_list.dart`
- what should be split into a narrower Kubernetes-local seam
- what state/interaction behavior should not be pushed into shared shell code

Done definition:
- one bounded Kubernetes-local cleanup seam is chosen
- the first implementation batch is clear
