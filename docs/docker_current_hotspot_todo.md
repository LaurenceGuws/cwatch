# Docker Current Hotspot TODO

Status: active
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
