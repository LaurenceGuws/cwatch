# Docker Current Hotspot TODO

Status: checkpointed
Purpose: track the next bounded cleanup batches for the current largest remaining feature hotspot.

## Task 22.1: start the current Docker hotspot pass
Status: completed

Goal:
- treat Docker as the first active hotspot from the fresh current-state review
- keep this pass narrowly focused on what still smells now, not what already got cleaned up

Done definition:
- there is one Docker-only TODO for the new pass
- the first bounded Docker batch is named

Result:
- Docker is now the active current-state hotspot
- the first bounded batch should target Docker list and overview surface complexity

## Task 22.2: define the first bounded Docker batch
Status: completed

Goal:
- choose one concrete Docker cleanup slice with strong value and low ambiguity

Questions to answer:
- what in [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart) is true feature-local rendering vs local orchestration smell
- whether [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart) or `docker_lists.dart` is the better first cut
- whether the first batch should stay in UI/local state or move back into Docker service shaping

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later Docker concerns remain queued instead of over-planned

## Queued Next Batches

These are intentionally not yet active:
- Docker list decomposition
- Docker overview/local state cleanup
- Docker client parsing organization
- Docker command terminal surface cleanup


Result:
- the first bounded Docker batch is now:
  - `ContainerPeek` stats and grouping orchestration split
- target files:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
  - new Docker-local helper for container list state/projection
- stop condition:
  - grouping and stats-fetch/cache logic no longer live inline inside `_ContainerPeekState`
  - rendering stays in `docker_lists.dart`
  - the rest of Docker remains untouched in this batch

Why this is the right first cut:
- it removes real local orchestration smell from one of the heaviest Docker surfaces
- it stays feature-local and does not reopen broader Docker ownership questions
- it gives a direct seam for focused regression coverage

## Task 22.3: implement the ContainerPeek state/projection split
Status: completed

Goal:
- extract `ContainerPeek` grouping and stats projection logic into a dedicated Docker-local helper

Done definition:
- one Docker-local helper owns container grouping, flat-index lookup, uptime labels, and stats cache/projection
- `_ContainerPeekState` no longer owns inline stats future/cache helpers
- focused regression coverage exists for the new helper

## Task 22.4: define the second bounded Docker batch
Status: completed

Goal:
- choose the next Docker cleanup slice from the remaining real hotspots after the container peek split

Done definition:
- one next batch is explicit
- the batch has a clear stop condition
- later Docker concerns remain queued instead of over-planned

Result:
- the second bounded Docker batch is now:
  - `ImagePeek` grouping and expansion-state orchestration split
- target files:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
  - new Docker-local helper for image list state/projection
- stop condition:
  - repository grouping, aggregate size formatting, expansion-state ownership, and grouped row projection no longer live inline inside `_ImagePeekState`
  - rendering and prompt dialogs stay in `docker_lists.dart`
  - network/volume lists remain untouched in this batch

Why this is the right second cut:
- it removes real local orchestration smell from the next-heaviest Docker list surface
- it stays feature-local and does not reopen broader Docker ownership questions
- it gives another direct seam for focused regression coverage

## Task 22.5: implement the ImagePeek state/projection split
Status: completed

Goal:
- extract `ImagePeek` grouping, totals, and expansion-state projection logic into a dedicated Docker-local helper

Done definition:
- one Docker-local helper owns repository grouping, grouped rows, expansion-state lifecycle, total tag/repo counts, and aggregate size formatting
- `_ImagePeekState` no longer owns inline grouping/size helpers or expansion map lifecycle
- focused regression coverage exists for the new helper

## Task 22.6: define the third bounded Docker batch
Status: completed

Goal:
- choose the next Docker cleanup slice from the remaining real hotspots after the image peek split

Done definition:
- one next batch is explicit
- the batch has a clear stop condition
- later Docker concerns remain queued instead of over-planned

Result:
- the third bounded Docker batch is now:
  - network/volume section-state orchestration split
- target files:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
  - new Docker-local helper for grouped section collapse and list projection
- stop condition:
  - grouping-by-compose-ish and collapsed-section state ownership no longer live inline in `_NetworkListState` / `_VolumeListState`
  - rendering stays in `docker_lists.dart`
  - `docker_overview.dart` remains untouched in this batch

Why this is the right third cut:
- it removes repeated local orchestration smell from two more Docker list surfaces at once
- it stays feature-local and does not reopen broader Docker ownership or overview complexity yet
- it gives a direct seam for focused regression coverage

## Task 22.7: implement the network/volume section-state split
Status: completed

Goal:
- extract grouped section projection and collapse-state ownership for Docker networks and volumes into a dedicated Docker-local helper

Done definition:
- one Docker-local helper owns compose-ish grouping, sorted section projection, collapsed-section toggling, and section count labels for network/volume lists
- `_NetworkListState` and `_VolumeListState` no longer own inline grouping/collapse helpers
- focused regression coverage exists for the new helper

## Task 22.8: define the fourth bounded Docker batch
Status: completed

Goal:
- choose the next Docker cleanup slice from the remaining real hotspots after the list-surface splits

Done definition:
- one next batch is explicit
- the batch has a clear stop condition
- later Docker concerns remain queued instead of over-planned

Result:
- the fourth bounded Docker batch is now:
  - Docker overview action/update orchestration split
- target files:
  - [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart)
  - new Docker-local helper for selection-based action routing and container/image update flows
- stop condition:
  - selection fallback helpers, tap-down action routing, image/network/volume menu routing, and container start/stop/restart update helpers no longer live inline in `_DockerOverviewState`
  - rendering, menus, and widget hosting stay in `docker_overview.dart`
  - Docker service/controller contracts stay stable in this batch

Why this is the right fourth cut:
- it removes the densest remaining non-rendering orchestration block in the Docker overview surface
- it stays feature-local and avoids reopening Docker transport/parser work
- it gives a direct seam for focused regression coverage

## Task 22.9: implement the Docker overview action/update split
Status: completed

Goal:
- extract selection-based action routing and post-action cache update helpers into a dedicated Docker-local overview helper

Done definition:
- one Docker-local helper owns selection fallback and post-action container/image/network/volume targeting helpers
- `_DockerOverviewState` no longer owns inline selection and update helper blocks
- focused regression coverage exists for the new helper

## Task 22.10: checkpoint the current Docker hotspot pass
Status: completed

Goal:
- stop the Docker pass at the point where the remaining weight is mostly valid feature-local hosting state

Done definition:
- the tracker explicitly records Docker as checkpointed for the current pass
- the next repo hotspot is named

Result:
- the current Docker hotspot pass is now checkpointed
- the remaining weight in [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart) is mostly valid Docker-local hosting behavior:
  - snapshot/tab hosting
  - distro probe triggering
  - container keyboard focus behavior
  - dashboard tab composition
- the next ranked hotspot is now:
  - `StructuredDataTable` risk reduction

Why this is the right stop:
- the Docker list surfaces are materially cleaner
- the densest non-rendering overview orchestration has been split
- pushing further now would likely optimize for file size rather than architectural value

## Task 22.11: re-scope the next Docker batch from the current code state
Status: completed

Goal:
- choose the next real Docker cleanup slice after the `StructuredDataTable` checkpoint
- avoid blindly continuing older Docker UI batches if the hotspot has shifted

Done definition:
- one new Docker batch is explicit
- the batch reflects the current code state instead of the earlier pass ordering

Result:
- the next bounded Docker batch is now:
  - Docker CLI parser organization split
- target files:
  - [docker_client_service.dart](/home/home/personal/cwatch/lib/model/features/docker/services/docker_client_service.dart)
  - new Docker parser helper under `lib/model/features/docker/services/`
- stop condition:
  - Docker JSON-line parsing and value normalization no longer live inline in `DockerClientService`
  - command execution, failure mapping, and gateway behavior stay in `DockerClientService`
  - Docker overview/widget surfaces remain untouched in this batch

Why this is the right next cut:
- `docker_client_service.dart` is now the clearest remaining Docker hotspot by file size and mixed responsibility
- it is a real subsystem boundary improvement, not file-size cleanup
- it gives direct parser coverage without reopening transport ownership

## Task 22.12: implement the Docker CLI parser organization split
Status: completed

Goal:
- extract JSON-line parsing and value normalization into a dedicated Docker parser helper

Done definition:
- one Docker helper owns context/container/image/network/volume/stats parsing
- `DockerClientService` no longer owns inline JSON-line loops and map-to-model shaping
- focused regression coverage exists for the new helper


## Task 22.13: implement the Docker overview runtime-side-effect split
Status: completed

Goal:
- extract the remaining overview-local service orchestration out of `docker_overview.dart`

Done definition:
- one Docker-local helper owns container distro probe triggering, start-time loading, compose-project sync, and post-action cache updates
- `docker_overview.dart` no longer owns those runtime-side-effect helpers inline
- focused regression coverage exists for the new helper


## Task 22.14: checkpoint the refreshed Docker hotspot pass
Status: completed

Goal:
- stop the Docker pass at the point where the remaining weight is mostly valid feature-local UI hosting and prompt/menu behavior

Done definition:
- the tracker explicitly records Docker as checkpointed for the refreshed pass
- the next repo hotspot is named from the fresh review order

Result:
- the refreshed Docker hotspot pass is now checkpointed
- the remaining weight in [docker_overview.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_overview.dart) and [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart) is mostly valid Docker-local hosting behavior:
  - prompt/menu flows
  - widget hosting and tab composition
  - feature-specific dashboard-opening and child-tab flows
- the next ranked hotspot is now:
  - SSH runtime simplification

Why this is the right stop:
- Docker list state, overview action state, overview runtime side effects, CLI execution, and CLI parsing now have dedicated seams
- pushing further now would likely optimize for file size rather than architectural value

## Task 22.15: define the next bounded Docker batch after the refreshed checkpoint
Status: completed

Goal:
- pick one new Docker-only cleanup slice from the current code state after the refreshed checkpoint
- keep the batch on real orchestration smell, not file-size cleanup

Done definition:
- one new Docker batch is explicit
- the batch has a clear stop condition
- the rest of Docker remains queued

Result:
- the next bounded Docker batch is now:
  - Docker workspace tab restore split
- target files:
  - [docker_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_workspace_controller.dart)
  - new Docker-local restore helper under `lib/view/features/docker/`
- stop condition:
  - tab-state decoding plus restored tab reconstruction no longer live inline in `DockerWorkspaceController`
  - workspace persistence and remote discovery remain in `DockerWorkspaceController`
  - Docker view/widget behavior stays unchanged in this batch

Why this is the right next cut:
- `docker_workspace_controller.dart` still mixes persistence/discovery concerns with a large restored-tab construction switch
- the repeated host/shell/editor/explorer reconstruction paths are real orchestration smell
- it creates a direct seam for focused restore-behavior regression coverage

## Task 22.16: implement the Docker workspace tab restore split
Status: completed

Goal:
- extract Docker tab-state decoding and restored-tab reconstruction into a dedicated Docker-local helper

Done definition:
- one Docker-local helper owns tab-state decoding, command sanitization, and restored tab reconstruction for Docker workspace tabs
- `DockerWorkspaceController` keeps workspace persistence and remote discovery only
- focused regression coverage exists for restored command/explorer behavior and invalid host restore cases

## Task 22.17: define the next bounded Docker batch after the workspace restore split
Status: completed

Goal:
- choose the next Docker-only cleanup slice from the current code state after the workspace restore split
- keep the batch on repeated Docker-local orchestration rather than prompt/menu rendering

Done definition:
- one new Docker batch is explicit
- the batch has a clear stop condition
- later Docker concerns remain queued

Result:
- the next bounded Docker batch is now:
  - Docker view tab-state mutation split
- target files:
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - new Docker-local helper under `lib/view/features/docker/`
- stop condition:
  - rename, explorer-path persistence, and picker-tab filtering logic no longer live inline in `DockerView`
  - dialog/menu presentation stays in `docker_view.dart`
  - workspace controller and tab builder contracts stay stable in this batch

Why this is the right next cut:
- `docker_view.dart` still repeats Docker-specific persisted-tab mutation rules in multiple places
- the repeated `DockerTabData` reconstruction is local orchestration smell, not just file size
- it creates a direct seam for focused regression coverage without reopening prompt/menu flows

## Task 22.18: implement the Docker view tab-state mutation split
Status: completed

Goal:
- extract Docker tab rename/path/picker-state mutation rules into a dedicated Docker-local helper

Done definition:
- one Docker-local helper owns rename-state updates, explorer-path persistence updates, and picker-tab filtering for `DockerView`
- `DockerView` keeps dialog/menu hosting and workspace actions only
- focused regression coverage exists for rename/path/picker mutation behavior
