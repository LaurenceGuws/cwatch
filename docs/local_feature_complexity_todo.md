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
Status: pending

Goal:
- define exactly what part of the remaining server-local complexity should be addressed first

Questions to answer:
- what should remain local to `server_workspace_view.dart`
- what should be split into a narrower server-local seam
- what state/probe behavior should not be pushed into generic shell code

Done definition:
- one bounded server-local cleanup seam is chosen
- the first implementation batch is clear
