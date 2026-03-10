# Tab Assembly Ownership TODO

Status: active
Purpose: scope the remaining tab-assembly seam using the explicit target boundary: reusable shell/framework on one side, removable feature modules on the other.

## Boundary This Hotspot Must Respect

The shell/framework layer should still make sense if SSH, Docker, Kubernetes, and WSL are removed.

That means:
- tab hosts, workspace primitives, generic tab containers, and reusable shared widgets belong to reusable shell/framework ownership
- feature-specific tab assembly belongs to the feature module unless there is a narrow, explicit module contract
- shell/framework code should not hard-code feature tab bodies as if they were part of the app core

This hotspot is not trying to remove all widget assembly from every builder.

It is trying to answer one narrower question:
- are the remaining controller-owned tab builders part of reusable shell/framework infrastructure, or are they actually feature-module composition code living in the wrong place?

## Current Problem

The remaining `controller -> view` imports are concentrated in controller-owned tab builders:
- `ServerTabBuilder` assembles server-specific and shared tab bodies
- `WslTabBuilder` assembles the WSL terminal tab

After the earlier cleanup passes, these are no longer mixed in with bindings, adapters, or model ownership issues. They are now a standalone boundary question.

## Why This Matters

If these builders are reusable shell/framework objects, then direct feature view construction is the wrong ownership signal.

If these builders are really feature-module composition objects, then they should live with the feature module or behind a narrow feature-module contract.

Either way, the repo needs one explicit rule instead of leaving this as an ambiguous exception.

## Working Rules For This Hotspot
- do not create fake abstraction layers just to avoid an import
- prefer moving ownership to the correct side over inventing generic factories too early
- shared tab infrastructure and feature tab composition are different concerns and should not be blurred together
- use the smaller WSL seam to establish the rule before touching the heavier server builder
- re-scope after the first batch lands

## First Batch Candidate

### Task 8.1: inspect WSL tab assembly ownership against the new boundary
Status: completed

Why this is first:
- `WslTabBuilder` is the smallest remaining tab-assembly seam
- it isolates the ownership question with one feature module and one shared tab body
- it should tell us whether the builder belongs in reusable shell/framework code or feature-module code

Current files in scope:
- `lib/controller/controllers/wsl_tab_builder.dart`
- `lib/view/features/wsl/wsl_view.dart`
- `lib/view/shared/views/shared/tabs/terminal/terminal_tab.dart`
- any directly related workspace/module wiring needed to clarify ownership

Actions:
- inspect what `WslTabBuilder` actually owns
- decide whether it is:
  - reusable shell/framework infrastructure,
  - feature-module tab composition, or
  - a narrow contract seam that needs to be made explicit
- make one small correction that clarifies the ownership rule
- record the rule we learn from this batch

Done definition:
- the repo is clearer about whether WSL tab assembly is shell/framework code or feature-module code
- one misleading ownership signal is removed or explicitly documented
- the next step for `ServerTabBuilder` can be scoped from evidence rather than assumption

Verification:
- `rg -n "package:cwatch/view/" lib/controller/controllers/wsl_tab_builder.dart lib/controller/controllers/server_tab_builder.dart`
- `flutter analyze`
- manual smoke check of WSL tab creation

### Task 8.2: re-scope after WSL tab assembly review
Status: completed

Purpose:
- decide whether the next batch should:
  - apply the same rule to `ServerTabBuilder`
  - move server tab assembly back into the server feature module
  - introduce a narrow module contract for feature tab assembly
  - stop this hotspot if the remaining seam is now explicit and acceptable

Done definition:
- the next tab-assembly step is written from what Task 8.1 actually proved
- any intentional exception or module-contract rule is recorded here

Verification:
- follow-up task added before the next structural change starts

Result of Task 8.1:
- `WslTabBuilder` was not reusable shell/framework infrastructure
- it was feature-module tab composition and moved to `lib/view/features/wsl/wsl_tab_builder.dart`
- `WslWorkspaceController` now depends on narrow tab-building callbacks instead of a concrete feature builder type
- `WslTabData` moved to `lib/model/features/wsl/models/wsl_tab_data.dart` because it is persistence/state metadata, not feature-view composition

### Task 8.3: apply the same ownership rule to server tab assembly
Status: queued

Why this is next:
- the WSL pass established the rule with the smallest seam
- `ServerTabBuilder` is the remaining controller-owned feature tab composer
- it likely needs the same treatment, but the heavier server surface should now be approached with the WSL pattern rather than a fresh redesign

Actions:
- inspect `ServerTabBuilder` against the same shell/framework versus feature-module rule
- move feature-specific tab assembly out of controller ownership if the same pattern holds
- keep reusable workspace primitives where they are
- use narrow callbacks/contracts where controller-owned workspace logic still needs tab reconstruction

Done definition:
- `ServerTabBuilder` is no longer an ambiguous controller-owned feature composer
- the server feature/module boundary is clearer than it is today
- any remaining controller-side tab assembly is either shared infrastructure or an explicit contract

Verification:
- `rg -n "package:cwatch/view/" lib/controller/controllers/server_tab_builder.dart`
- `flutter analyze`
- manual smoke check of server tab creation/restoration paths

## Later Work In This Hotspot

Do not expand these until Task 8.1 has landed.

### Server tab assembly
Track here when ready:
- whether `ServerTabBuilder` is feature-module composition living under `controller/`
- whether shared tabs and server-specific tabs should be assembled at the same boundary

### Module contract shape
Track here when ready:
- whether removable feature modules should expose tab factories/descriptors through a narrow registration contract
- whether the current `WorkspaceTab(body: Widget)` shape is forcing feature composition into the wrong layer

## Tracking Table

| Item | Scope | Status | Done When |
| --- | --- | --- | --- |
| 8.1 | WSL tab assembly ownership | completed | WSL tab assembly is clearly classified as shell/framework, feature-module, or explicit contract code |
| 8.2 | Tab assembly re-scope | completed | next step is written from what 8.1 proves |
| 8.3 | Server tab assembly ownership | queued | server tab assembly is no longer an ambiguous controller-owned feature composer |

## Completion Metric

This document is serving its purpose if:
- it makes the shell/framework versus feature-module boundary explicit
- it avoids treating feature tab assembly as app-core infrastructure by accident
- it gives us a small, evidence-driven next step instead of a guessed full redesign
