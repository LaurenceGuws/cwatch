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
