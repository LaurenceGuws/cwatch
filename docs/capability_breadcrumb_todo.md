# Capability Breadcrumb TODO

Status: active
Purpose: define how optional capability failures should be surfaced in shared shell/UI terms so unavailable Docker/Kubernetes/SSH integrations degrade consistently without flattening domain-specific guidance.

## Why This Exists

The current integration-smell checkpoints are strong enough now:
- tab shell is explicit and checkpointed
- dialog/settings scaffolding is explicit and checkpointed
- shared scaffolding is explicit and checkpointed
- command contribution is explicit and checkpointed
- annotation/codegen is at a good checkpoint

The repo also already has a documented capability rule:
- system CLIs and host-config integrations are optional convenience paths
- missing integrations should degrade feature affordances and leave breadcrumbs
- they should not behave like app-fatal failures

That rule is now reflected in:
- docs
- tests
- some local UI fixes

The remaining smell is integration-level:
- unavailable capability messaging is still distributed
- some surfaces use empty states
- some use warnings
- some use local strings with no clear shared contract

## Current Shared Surface

Current evidence of capability-aware surfacing:
- [standard_empty_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/standard_empty_state.dart)
- Docker engine picker unavailable path in [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart)
- dashboard unavailable wording in [kubernetes_dashboard_view.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart)
- existing docs/tests around graceful degradation

## Current Integration Smells In This Hotspot

### 1. The rule exists, but the UI contract is not explicit

The product direction is clear:
- missing capability should degrade, not panic

What is still unclear:
- when to show a shared empty state
- when to show inline warning text
- when to show settings breadcrumbs
- when a feature should keep fully local guidance

### 2. Capability-unavailable copy is still too feature-local

Some feature-local copy is correct.

But the repo still lacks a clear contract for shared capability surfacing such as:
- unavailable because local CLI is missing
- unavailable because backend is misconfigured
- unavailable because optional path is disabled or unsupported here

### 3. This should not become a generic “error state framework”

The next pass should not try to unify:
- all warnings
- all errors
- every empty state

It should only define:
- shared capability/breadcrumb surfacing rules
- one narrow proving slice if the rule is clear enough

## Task 14.57: choose the next integration-smell hotspot after command contribution
Status: completed

Goal:
- decide the next hotspot after the command contribution checkpoint

Candidates considered:
- capability / breadcrumb integration surfacing
- stop the integration-smell layer and roll up the current state

Result:
- the next hotspot is `capability and breadcrumb surfacing`

Why this wins:
- the capability rule is already documented and partly tested
- UI surfacing is the remaining distributed seam
- this is a clearer next shell-facing concern than stopping the layer completely right now

Why stopping entirely waits:
- the integration layer has enough checkpoints to pause safely
- but capability surfacing is still an active cross-feature rule without a documented UI contract

## Task 14.58: define the shared capability/breadcrumb contract
Status: queued

Goal:
- describe which capability-unavailable states should use shared shell/UI patterns and which should remain feature-local guidance

Actions:
- audit current capability-unavailable surfaces
- separate shell-owned generic capability breadcrumbs from feature-specific guidance
- identify the first narrow normalization seam, if any

Done definition:
- the shared capability/breadcrumb responsibilities are explicit
- valid local exception categories are explicit
- one concrete next batch is chosen or the hotspot is checkpointed
