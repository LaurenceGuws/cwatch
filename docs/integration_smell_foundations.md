# Integration Smell Foundations

Status: active
Owner: current maintainers
Purpose: define the next rewrite layer after the first code-smell cleanup pass: clarifying how shared shell subsystems, feature modules, metadata, and local overrides integrate.

## Why This Exists

The first cleanup pass reduced structural noise:
- dependency direction is materially better
- composition ownership is clearer
- settings/state seams are cleaner
- there is now a useful regression floor

That does not mean the app's integration model is clean.

There is still a second class of design debt:
- shared shell pieces exist, but their intended reuse contract is unclear
- feature modules sometimes re-create or shadow shared UI patterns instead of extending them deliberately
- subsystem-specific overrides are often implicit rather than explicit
- metadata that could describe integration points is scattered in ad hoc code

This is integration smell:
- the problem is not only where code lives
- the problem is how subsystems discover, extend, override, and compose with each other

## Current Integration Problems

### 1. Shared shell elements are not defined as a visible subsystem

The app already has reusable shell/UI pieces:
- tab host and workspace primitives
- tab chip behavior
- shared dialogs
- explorer surfaces and helpers
- context menus
- settings controls
- common list/table patterns

But they are not documented as a coherent subsystem with clear rules.

Result:
- reuse is inconsistent
- local re-creation is easy to justify accidentally
- cleanup work keeps rediscovering the same ambiguity

### 2. Local overrides are not explicit enough

Some feature modules need their own behavior or presentation. That is fine.

The problem is:
- overrides are often not recorded as intentional
- replaced shell/shared elements are hard to spot
- the codebase does not clearly distinguish:
  - canonical shared behavior
  - permitted local override
  - accidental fork

Result:
- shared polish stalls
- feature divergence accumulates silently

### 3. Integration metadata is still hand-wired

Many integration points are expressed manually:
- settings fields and controls
- tab metadata
- command/menu entries
- context menu integration
- capability visibility

Result:
- glue code becomes repetitive
- registry-like behavior is spread across multiple files
- schema generation and external automation are harder than they should be

### 4. Reuse vs replacement is not governed

Today the repo does not have a strong rule for:
- when a feature must reuse a shell/shared element
- when a feature may override a shell/shared element
- when a duplicated local widget/helper should be removed

Result:
- the shell can’t be polished confidently because it is unclear which surfaces are actually canonical

## Rewrite Goal For This Layer

The goal is not "make everything generic."

The goal is:
- make the shell/shared subsystem visible
- define what is canonical
- define what is extension-only
- define what may be overridden locally
- define where declarative metadata should replace manual integration glue

## Boundary This Work Must Respect

The existing shell/framework rule still applies:
- shell/framework code survives removal of SSH, Docker, Kubernetes, and WSL modules
- feature modules own their own feature workflows and placeholder-tab behavior

This integration layer adds:
- shell/shared UI owns reusable primitives and default patterns
- feature modules may override only where they have a clearly different subsystem contract
- overrides must be explicit and documented
- accidental shadowing and silent widget re-creation should be treated as cleanup targets

## What Counts As A Shared Shell Element

For this workstream, a shared shell element is any reusable surface or integration primitive that should remain valid even if individual feature modules are removed.

Examples:
- tab host primitives
- tab chip primitives and tab option behavior
- generic list/table scaffolding
- reusable dialogs and dialog keyboard behavior
- explorer building blocks that are not feature-specific
- settings section scaffolding and shared settings controls
- command/context menu infrastructure
- shared capability/breadcrumb UI

These are not all equally mature today. The point of this workstream is to make that maturity explicit.

## What Counts As A Local Override

A local override is acceptable only when a feature needs:
- genuinely different behavior
- genuinely different data shape
- genuinely different interaction rules
- genuinely different visual contract

Examples of acceptable overrides:
- a feature-specific placeholder tab
- feature-specific dialog content
- a domain-specific landing surface that should not be flattened into a generic picker
- feature-specific list/item actions that do not belong in shell/shared UI

Examples of bad overrides:
- re-creating a shared shell widget because the shared one is undocumented
- local copies of shell behavior with only tiny cosmetic differences
- hidden replacement of a canonical shared element without any explicit reason

## Declarative Metadata Direction

Annotations may help this layer, but only for stable metadata.

Good annotation/codegen candidates:
- config/schema metadata
- command registration metadata
- context-menu contribution metadata
- tab/view descriptor metadata
- capability declaration metadata

Bad early annotation targets:
- controller lifecycle
- runtime composition orchestration
- async behavior policy
- dynamic per-feature workflow logic

The correct pattern is:
- metadata is declarative
- runtime behavior stays in explicit code
- generated manifests/registries bridge the two

## Focus Areas For Deeper Analysis

### Focus Area A: shell/shared subsystem map
Questions:
- which shell/shared UI elements are canonical today
- which are partial, ambiguous, or duplicated
- which current feature-local versions are really shell/shared candidates

Deliverables:
- subsystem map
- canonical/shared element list
- duplicate/replacement hotspot list

### Focus Area B: override policy
Questions:
- where are local overrides acceptable
- where should reuse be mandatory
- which current local implementations are explicit exceptions vs cleanup targets

Deliverables:
- override rules
- explicit exception list
- removal candidates

### Focus Area C: integration metadata
Questions:
- which current integration points are hand-wired
- which are stable enough for declarative metadata
- what should be annotation-driven first

Deliverables:
- metadata candidate map
- first annotation/codegen target
- anti-goals for magic/framework bloat

### Focus Area D: shell polish readiness
Questions:
- which existing shell/shared surfaces need polish instead of replacement
- which local forks are blocking that polish
- which shared surfaces should become the default integration path

Deliverables:
- shell polish hotspot list
- shared-surface promotion list
- local replacement cleanup list

## Recommended Work Sequence

1. Map the shell/shared subsystem surfaces.
2. Choose one shell-defining shared subsystem hotspot and normalize it first.
3. Identify current feature-local re-creations and shadowed shared elements around that hotspot.
4. Write explicit override rules.
5. Scope the first annotation/codegen candidate from stable metadata.
6. Resume deeper cleanup with a clearer integration contract.

## First Normalization Hotspot

The first normalization hotspot is:
- tab chip / tab shell contract

Why this is first:
- it is the clearest shell-identity surface in the app
- it sits above multiple feature modules
- it is where shell polish and local override rules need to become explicit before broader shared-surface cleanup

What this hotspot should establish:
- the canonical shared tab shell surface
- which tab behaviors are mandatory shared behavior
- which tab-level actions and presentation details remain feature-owned
- which local tab variations are valid exceptions versus cleanup targets

Current follow-up doc:
- [tab_shell_contract_todo.md](/home/home/personal/cwatch/docs/tab_shell_contract_todo.md)

Current next normalization direction:
- shared tab-shell adapter/helper for routine chip assembly and generic tab command contribution

Current implementation-ready follow-up:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Current implementation checkpoint:
- WSL now proves the first shared chip-building seam
- Kubernetes now proves the routine options-controller adoption case
- Docker now proves the picker-restriction and extra-options adoption case
- Servers now prove the heaviest current adoption case

Current tab-shell status:
- first chip-building normalization pass complete
- generic tab command contribution remains a queued follow-up, not the active blocker

Current next hotspot:
- shared dialog/settings scaffolding

Current follow-up doc:
- [dialog_settings_contract_todo.md](/home/home/personal/cwatch/docs/dialog_settings_contract_todo.md)

Current implementation-ready follow-up:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Current implementation checkpoint:
- `SettingsUiAdapter` now proves the first shared prompt-helper slice for:
  - password prompts
  - passphrase prompts
  - destructive confirmation prompts
- `WslUiAdapter` now proves the simple shared text-input adoption case
- `DockerOverviewUiAdapter` now proves the generic text-input case with `initialValue` and `hintText`
- `ExplorerUiAdapter` now proves shared prompt adoption without absorbing richer explorer-specific dialogs

Current next normalization direction:
- adopt the shared prompt helper in smaller generic text-input adapters before exploring richer dialog flows

## Success Criteria

This layer is working when:
- maintainers can point to the canonical shared shell elements without guesswork
- local overrides are explicit and justified
- the repo stops silently re-creating shared UI patterns
- the first annotation/codegen target is chosen from stable metadata instead of abstraction hype
