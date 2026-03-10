# Shared Scaffolding TODO

Status: active
Purpose: define the canonical shared shell scaffolding for reusable lists, menus, and settings sections so feature modules stop silently re-creating these surfaces.

## Why This Exists

The current integration-smell checkpoints are strong enough now:
- tab shell is explicit and partially normalized
- dialog/settings prompt scaffolding is explicit and checkpointed
- SSH auth ownership is at a good checkpoint
- explorer shared surface is explicit and checkpointed
- annotation/codegen is at a good checkpoint

That means the next high-value shell cleanup is not another feature-specific pass.

It is:
- making shared list, menu, and settings scaffolding visible as one reusable subsystem
- documenting where reuse is mandatory vs where local variants are valid

## Current Shared Surface Candidates

Likely shared shell scaffolding in scope:
- generic list and table hosting in `lib/view/shared/widgets/`
- popup/context menu infrastructure
- settings section layout and settings control grouping
- shared empty-state and breadcrumb messaging used by settings-like screens

Representative current files to audit:
- `lib/view/shared/widgets/`
- `lib/view/features/settings/settings/`
- `lib/view/features/servers/servers/`
- `lib/view/features/docker/widgets/`
- `lib/view/features/kubernetes/widgets/`

## Current Integration Smells In This Hotspot

### 1. Shared scaffolding exists, but it is not described as a contract

The repo already has shared widgets and section patterns for:
- settings controls
- dialog-adjacent layout
- list/table rows and wrappers
- popup/menu behavior

But there is no explicit rule for:
- what the canonical shared scaffolding is
- what feature modules are expected to reuse
- which local variants are justified exceptions

### 2. Settings layout is at risk of drifting into feature-local section systems

Settings is one of the clearest shell-owned surfaces in the app:
- grouped controls
- section headings
- repeated toggle/select/text-entry patterns

If that stays implicit, every subsystem can drift into its own settings presentation language.

### 3. Generic lists and menus are likely being shadowed for local convenience

This is a predictable integration smell in the current repo state:
- simple feature lists and menu surfaces are easy to rebuild locally
- some of those local versions are probably valid
- some are probably just undocumented shared shell behavior wearing a local name

### 4. This hotspot should not turn into a generic design-system rewrite

The first pass should identify:
- shell-owned scaffolding
- repeated local reconstruction
- valid local exceptions

It should not try to:
- unify all feature visuals
- flatten domain-specific tables into one widget
- replace richer feature-local surfaces with generic infrastructure

## First Concrete Goal

The first useful batch is:
- define the shared list/menu/settings scaffolding contract

That contract should answer:
- which settings-section layout pieces are canonical shell scaffolding
- which list/menu surfaces are shared infrastructure vs feature-local rendering
- which local variants are intentional exceptions vs cleanup targets

## Task 14.44: choose the next integration-smell hotspot after annotation/codegen
Status: completed

Goal:
- select the next shared-surface hotspot after the annotation/codegen checkpoint

Candidates considered:
- return to annotation/codegen for generator tooling
- continue SSH compatibility cleanup
- start shared list/menu/settings scaffolding

Result:
- the next hotspot is `shared list/menu/settings scaffolding`

Why this wins:
- the annotation/codegen track is now at a good checkpoint and should not keep expanding without a stronger product need
- the biggest remaining shell-facing ambiguity is shared scaffolding around settings, lists, and menus
- this is the next place where shell polish and reuse will drift if the contract stays implicit

Why the other candidates wait:
- generator tooling
  - the manual metadata registry is still cheap enough to maintain
- SSH compatibility cleanup
  - that is now lower-level composition cleanup, not the same class of integration smell

## Task 14.45: define the shared list/menu/settings scaffolding contract
Status: queued

Goal:
- describe the canonical shared shell scaffolding for reusable settings sections, generic lists/tables, and popup/menu surfaces

Actions:
- audit the current shared widgets and current feature-local variants
- separate shell-owned scaffolding from domain-specific list/menu content
- record allowed local override categories
- identify the first narrow normalization batch after the contract is written

Done definition:
- the canonical shared scaffolding responsibilities are explicit
- valid local exception categories are explicit
- one concrete follow-up cleanup batch is chosen
