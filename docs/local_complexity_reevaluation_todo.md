# Local Complexity Reevaluation TODO

Status: active
Purpose: track bounded cleanup reopened from fresh current-state evidence after the older broad hotspot queue was checkpointed.

## Task 28.1: start the local complexity reevaluation pass
Status: completed

Goal:
- reopen cleanup only from fresh file-level evidence in the current code state
- keep this pass focused on large mixed-responsibility files rather than recreating a broad repo-wide hotspot queue

Done definition:
- there is one active TODO for the current local-complexity pass
- the first bounded batch is named from the fresh file-size and responsibility review

Result:
- local complexity reevaluation is now the active current-state pass
- the first bounded batch should come from the clearest mixed-surface large file

## Task 28.2: define the first bounded local complexity batch
Status: completed

Goal:
- choose one large file whose size still reflects multiple distinct surfaces instead of one coherent responsibility
- keep the batch on file-level decomposition, not broader Docker workflow redesign

Done definition:
- one explicit first batch is named
- the stop condition reflects the current file shape

Result:
- the first bounded local-complexity batch is now:
  - split Docker storage lists out of `docker_lists.dart`
- target files:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
  - new Docker widget file under `lib/view/features/docker/widgets/`
- stop condition:
  - network and volume list surfaces no longer live in the same file as container and image surfaces
  - tiny shared helpers are promoted only where needed
  - behavior stays stable

Why this is the right first cut:
- `docker_lists.dart` is large because it still hosts several distinct list surfaces
- network and volume lists are the most self-contained file-level split available
- this improves navigation and maintainability without changing Docker behavior

## Task 28.3: implement the first bounded local complexity batch
Status: completed

Goal:
- move Docker storage list surfaces into their own file while keeping the rest of the Docker list feature stable

Done definition:
- network and volume list widgets no longer live in `docker_lists.dart`
- the remaining file is materially narrower around container and image surfaces
- focused Docker validation stays green

Result:
- Docker storage list surfaces now live in:
  - [docker_storage_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_storage_lists.dart)
- shared list helpers needed by both files now live in:
  - [docker_lists_helpers.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists_helpers.dart)
- the remaining mixed-surface file is narrowed:
  - [docker_lists.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_lists.dart)
