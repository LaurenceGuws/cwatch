# Docker Vertical Slice TODO

Status: active
Purpose: define the second true vertical slice after the explorer checkpoint, using the ownership, composition, settings, integration, and testing groundwork already landed in Docker.

## Why Docker Is Next

Docker is the strongest next slice because:
- major dependency and ownership cleanup already landed around:
  - docker overview controller ownership
  - tab shell integration
  - command contribution
  - runtime graph extraction
  - capability-aware missing-CLI behavior
- Docker already has useful regression coverage:
  - `docker_client_service_test.dart`
  - `docker_command_terminal` now reads through grouped preferences
  - runtime startup and missing-CLI behavior were exercised during the recent fixes
- it is broad enough to prove the architecture on:
  - module runtime composition
  - capability-aware feature behavior
  - tabbed workflow state
  - feature-local dashboards and action flows
- it is still less entangled than servers/SSH session flows

## Scope Of This Slice

This slice is not:
- a Docker feature redesign
- a generic container-management framework
- a full CLI/API transport rewrite

This slice is:
- proving the next vertical-slice pass on a feature with richer runtime and module behavior than explorer
- reducing ambiguity in `docker_view.dart` and adjacent Docker workflow surfaces
- making Docker runtime, picker/dashboard flow, and action ownership clearer end-to-end

## Current Architectural Starting Point

Relevant current files:
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [docker_view_runtime.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_runtime.dart)
- [docker_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_workspace_controller.dart)
- [docker_view_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/docker_view_controller.dart)
- [docker_overview_actions_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/docker_overview_actions_controller.dart)
- [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart)
- [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart)
- [docker_client_service.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_client_service.dart)

Current known truth:
- Docker runtime ownership is materially cleaner than before
- capability degradation for missing Docker CLI is now explicit enough to build on
- the main remaining architectural weight is still concentrated in `docker_view.dart` and the picker/overview workflow split

## Task 16.1: confirm Docker as the second vertical slice
Status: completed

Goal:
- choose the next true vertical slice after explorer from current rewrite evidence

Candidates considered:
- docker
- servers

Result:
- Docker is the second vertical slice

Why this wins:
- enough groundwork already exists to make the slice actionable
- richer runtime/module behavior than explorer, but lower infra complexity than servers
- stronger capability/degradation surface, which is a good next proof after explorer

## Task 16.2: define the Docker target slice boundary
Status: completed

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in the current Docker runtime/service layer
- what should move out of `docker_view.dart`
- what remains intentionally local to Docker picker/dashboard behavior in the first batch

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen

Result:
- the first Docker slice boundary is now explicit

### What stays stable / out of scope for the first batch

These areas should stay stable in the first Docker slice pass:
- `DockerViewRuntime`
- `DockerClientService`
- `DockerViewController`
- `DockerWorkspaceController`
- `DockerOverviewActionsController`
- `docker_engine_picker.dart`
- `docker_overview.dart`
- current capability-aware missing-CLI behavior

Why they stay stable:
- the runtime/composition and capability groundwork there is already good enough to build on
- changing picker/overview internals immediately would broaden the blast radius too early

### What stays intentionally local to Docker behavior

These remain Docker-local even after the first slice cut:
- engine-picker UI behavior
- overview/dashboard UI behavior
- Docker-specific action wording and domain behavior
- Docker tab replacement flows tied closely to picker/overview semantics

The goal is not to genericize Docker dashboards or picker screens.

### What should move out of `docker_view.dart` first

The first seam is top-level Docker module orchestration around the view shell, not the picker or overview widgets themselves.

That means extracting the logic that currently coordinates:
- command-palette registration/loading
- tab-navigation registration
- picker-tab creation/replacement helpers
- top-level context-loading kickoff and reload behavior
- Docker view-level state mapping between runtime, picker, and workspace shell

This should become a narrower Docker view-shell presenter/coordinator seam, while picker and overview rendering stay local for now.

### Why this is the right first cut

- `docker_view.dart` is still the main concentration point for mixed orchestration and rendering
- it mirrors the shape explorer had before the presenter/actions split
- it improves the Docker shell boundary without forcing early changes into the denser picker/overview widgets

## Task 16.3: implement Docker top-level view-shell split
Status: completed

Goal:
- extract top-level Docker view-shell orchestration out of `docker_view.dart` while leaving picker and overview widgets local for now

First code targets:
- command-palette and tab-navigation contribution wiring
- picker-tab creation/replacement helpers
- top-level context-loading kickoff/reload coordination
- Docker view-level derived state used to host picker vs overview tabs

What should stay local in this batch:
- `docker_engine_picker.dart`
- `docker_overview.dart`
- feature-specific dashboard/picker rendering
- detailed overview action behavior

Done definition:
- `docker_view.dart` is materially smaller and more focused on hosting/rendering
- the new seam clearly owns top-level Docker module orchestration
- picker and overview widgets remain local and untouched except where needed for the seam

Result:
- extracted [docker_view_shell.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_shell.dart)
- moved top-level Docker module orchestration out of [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart):
  - command-palette registration/loading
  - tab-navigation registration
  - picker-tab refresh/replacement helpers
  - context-loading kickoff
- kept these local to `docker_view.dart`:
  - `_probeLocalContext`
  - `_probeHost`
  - `_pickDashboardTarget`
  - picker/overview widget composition

## Task 16.4: re-scope the next Docker slice batch
Status: completed

Goal:
- decide the next smallest Docker-local seam after the new view-shell split without broadening the slice into dashboard or transport rewrites

Likely candidates:
- split Docker picker/overview hosting state out of `docker_view.dart`
- add focused tests around the new Docker view-shell seam
- checkpoint the slice and move to tests before deeper extraction

Done definition:
- the next Docker batch is chosen from the post-shell-split code shape
- the choice reflects the new view-shell seam rather than just line-count reduction

Result:
- the next Docker batch should deepen the regression floor around the new shell seam
- it should not split picker/overview hosting state yet

Why this is the right next move:
- the remaining weight in [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart) is now concentrated in Docker-local hosting state:
  - remote scan state
  - cached-ready state
  - picker settings overlay state
  - restore/probe hooks
- that remaining code is tightly coupled to Docker picker/dashboard semantics
- extracting it immediately would risk creating a fake generic hosting abstraction instead of proving a better Docker boundary
- the new seam:
  - [docker_view_shell.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_shell.dart)
  should be locked down before further Docker-local decomposition

## Task 16.5: add focused tests for the Docker view-shell seam
Status: completed

Goal:
- add direct regression coverage around the new Docker view-shell seam before deciding whether the slice should continue or checkpoint

First test targets:
- `docker_view_shell_test.dart`
  - command-palette entry loading
  - tab-navigation behavior
  - picker-tab refresh/replacement behavior
  - context-load kickoff behavior

Done definition:
- the Docker shell seam has direct focused tests
- the tests validate the extracted orchestration boundary rather than broad Docker widget behavior
- the next slice decision can be made from a safer regression floor

Result:
- added [docker_view_shell_test.dart](/home/home/personal/cwatch/test/view/features/docker/docker_view_shell_test.dart)
- direct coverage now exists for:
  - command-palette entry loading
  - tab-navigation behavior
  - picker-tab refresh/replacement behavior
  - context-load kickoff behavior

## Task 16.6: re-scope the next Docker slice batch
Status: completed

Goal:
- decide whether the Docker slice should continue into Docker-local hosting state or checkpoint at the current shell seam

Questions to answer:
- is there another real architectural seam in `docker_view.dart`
- or is the remaining weight mostly feature-local Docker state that should stay together for now

Done definition:
- the next Docker slice move is explicit
- the choice is based on the post-test seam shape, not file-length pressure

Result:
- the Docker slice should checkpoint here
- it should not extract another seam from [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart) in this pass

Why this is the right stop:
- the remaining weight in `docker_view.dart` is mostly real Docker-local hosting and probe behavior:
  - remote scan state
  - local context probe state
  - picker settings overlay state
  - restore/probe hooks
  - dashboard-opening flows
- those concerns are tightly coupled to Docker picker/dashboard semantics
- extracting them now would likely create a fake generic “scan/host manager” layer instead of improving feature boundaries

## Task 16.7: checkpoint the first Docker vertical slice
Status: completed

Goal:
- stop the Docker slice at a defensible architectural boundary instead of continuing for file-length reduction

Done definition:
- the current Docker slice result is explicit
- the next rewrite move should come from the broader sequence, not more Docker decomposition by default

Result:
- the first Docker vertical slice is now checkpointed

What this slice proved:
- top-level Docker module orchestration can move into a dedicated seam:
  - [docker_view_shell.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_shell.dart)
- that seam is directly covered by:
  - [docker_view_shell_test.dart](/home/home/personal/cwatch/test/view/features/docker/docker_view_shell_test.dart)
- `docker_view.dart` is now narrower and the remaining weight is mostly true Docker-local behavior, not shell/runtime ambiguity
