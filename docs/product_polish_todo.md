# Product Polish TODO

Status: active
Purpose: track small, visible, high-leverage consistency improvements now that the structural rewrite layers are checkpointed.

## Task 21.1: start the product polish layer
Status: completed

Goal:
- make product polish and consistency an explicit tracked layer instead of an ad hoc cleanup pass

Done definition:
- there is one high-level polish scope doc
- there is one actionable TODO doc for the layer
- the current best first hotspot is named

Result:
- the product polish layer is now explicitly tracked
- the first hotspot should be placeholder and empty-state polish

## Task 21.2: define the placeholder/empty-state polish target
Status: completed

Goal:
- identify the current canonical shared empty-state framing
- identify the most visible inconsistent adopters
- choose one narrow first implementation batch

Questions to answer:
- which surfaces already use `StandardEmptyState`
- which placeholder or unavailable surfaces still drift in wording, spacing, action placement, or icon treatment
- what should become the shared default framing without flattening feature-specific behavior

Done definition:
- one bounded placeholder/empty-state batch is chosen
- the first implementation slice is explicit

Result:
- the canonical shared empty-state path remains:
  - [standard_empty_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/standard_empty_state.dart)
- the first visible inconsistency batch should target:
  - Kubernetes placeholder/context-list empty states that still use plain `Text`
  - Docker remote picker empty/unavailable states that do not yet use the same shared framing quality as local contexts
  - one shared improvement to `StandardEmptyState` only if it is justified by at least two adopters in the same batch

Why this is the right first cut:
- these are highly visible placeholder-entry surfaces
- they sit directly on top of the placeholder-tab rule
- they already overlap with capability and entry-surface polish without reopening ownership work
- this avoids jumping into dashboard-specific empty states, which are richer and more feature-local

What should wait:
- Kubernetes dashboard-level unavailable and no-data cards
- Docker overview tab empty states
- lower-priority settings/debug-log empty states

First implementation batch:
- normalize Kubernetes context placeholder/list empty states onto `StandardEmptyState`
- normalize Docker remote picker "no ready remotes" framing onto the same shared path
- only extend `StandardEmptyState` if the two adopters reveal one real missing shared affordance

## Task 21.3: implement the first placeholder/empty-state polish batch
Status: completed

Goal:
- normalize the first visible placeholder/empty-state inconsistencies onto the existing shared empty-state path

Done definition:
- Kubernetes placeholder/list empty states no longer use plain `Text` fallback blocks
- Docker remote picker empty/unavailable states use the same shared empty-state framing quality
- no new generic dashboard framework is introduced

Result:
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart) now uses `StandardEmptyState` for context-load failure and no-context states
- [kubernetes_context_picker.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_context_picker.dart) now uses `StandardEmptyState` for context-load failure and no-context states
- [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart) now uses `StandardEmptyState` for remote "no Docker-ready hosts" states with a real retry action

Why this batch is a good checkpoint:
- it improves the most visible placeholder-entry surfaces without reopening ownership work
- it strengthens one canonical shared path instead of adding a new UI abstraction
- it leaves richer dashboard-specific unavailable states for a later dashboard-focused polish batch
