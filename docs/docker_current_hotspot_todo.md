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
Status: pending

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
