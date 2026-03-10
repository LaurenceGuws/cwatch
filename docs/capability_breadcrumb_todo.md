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
Status: completed

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

Result:
- the shared capability/breadcrumb contract is now explicit

### Shared shell responsibilities

Shared shell/UI surfaces should own:
- simple capability-unavailable empty-state framing for optional integrations
- consistent wording shape for:
  - unavailable optional capability
  - retry action when retry is meaningful
- generic breadcrumb direction such as “this path is optional” or “use another path/settings”

### Feature responsibilities

Feature modules should own:
- domain-specific guidance about what the unavailable capability actually blocks
- backend-specific wording
- richer unavailable dashboards and warnings where the surface is more than a simple empty state
- feature-specific remediation steps

### Valid local exceptions

Local capability guidance is valid when:
- the surface is a dashboard rather than a simple empty state
- the unavailable condition depends on feature-specific backend semantics
- the user needs domain-specific explanation rather than a generic shell breadcrumb

Examples:
- Docker engine picker local CLI-unavailable path
  - valid as a proving slice for shared empty-state-based surfacing
- Kubernetes dashboard unavailable state
  - valid local exception because it is dashboard-level guidance, not a simple empty state

### What this means in practice

- simple optional-capability absence can reuse `StandardEmptyState`
- richer “dashboard unavailable” states should remain feature-local unless multiple features converge on the same richer pattern
- this hotspot should not try to unify all unavailable/error states

## Task 14.59: re-scope the capability/breadcrumb hotspot
Status: completed

Goal:
- decide whether there is one more narrow normalization batch worth doing now or whether this hotspot is already at a good checkpoint

Likely outcomes:
- checkpoint now because the contract is enough
- or normalize one additional simple capability-unavailable empty-state path if a second clear adopter exists

Done definition:
- the next batch is chosen or the hotspot is checkpointed

Result:
- the capability/breadcrumb hotspot is now at a good checkpoint
- there is not a second clear simple adopter worth normalizing right now

Why this is the right stop point:
- Docker engine picker already proves the shared empty-state-style capability path
- the next visible unavailable surface is Kubernetes dashboard unavailability
- that surface is richer, dashboard-level, and correctly belongs to the local-exception side of the contract

What this hotspot has now proved:
- the capability rule is not just a product statement; it now has an explicit UI contract
- simple optional-capability absence is a shared shell concern
- richer feature/dashboard unavailable guidance remains intentionally local

Current checkpoint summary:
- shared shell capability surfacing should stay narrow
- `StandardEmptyState` is sufficient for simple optional-capability absence
- dashboard-level unavailable states should not be flattened into a generic shell component yet

## Task 14.60: choose the next integration-smell move after capability/breadcrumb
Status: queued

Goal:
- decide whether to:
  - checkpoint the whole integration-smell layer and roll up the state
  - or identify one last high-signal hotspot from the current evidence

Done definition:
- the next move is chosen explicitly
