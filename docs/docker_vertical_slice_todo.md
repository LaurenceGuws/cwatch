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
Status: queued

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
