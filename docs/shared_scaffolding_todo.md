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
Status: completed

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

Result:
- the shared scaffolding contract is now explicit around the current real primitives:
  - `SettingsSection`
  - `SectionList`
  - `StructuredDataTable`
  - `ActionPicker`
  - `StandardEmptyState`
  - `SectionNavBar`

### Canonical shared responsibilities

The shared shell scaffolding should own:
- repeated settings-section framing and section collapse/expand behavior
- generic list/card framing with shared divider/title treatment
- complex reusable table/list infrastructure with selection, keyboard, and context-menu support
- generic action-picker surfaces for simple option selection
- canonical empty-state/breadcrumb presentation for non-domain-specific “nothing here / unavailable” messaging
- section navigation chrome used to move between shared screen subsections

### Feature responsibilities

Feature modules should own:
- domain rows, columns, and action labels
- domain-specific validation and side effects
- domain-specific menu contents and availability rules
- richer dashboards and cards whose value is in their custom content, not in generic scaffolding

### Allowed local exceptions

Local exceptions are valid when a surface needs:
- domain-specific data density or rendering contracts
- domain-specific multi-step controls
- richer dashboard cards or status panels
- custom interaction models beyond generic section/list/menu scaffolding

Examples of valid local exceptions:
- Docker `SectionCard`
- Kubernetes dashboard cards and direct `DataTable` surfaces
- server-specific action wording and host presentation
- domain-specific empty states that carry product-specific guidance

### Current integration smells still visible

- settings sections are canonical, but the repo does not yet state where feature-local section wrappers are no longer acceptable
- `StructuredDataTable` is a major shared primitive, but some feature tables still bypass it without an explicit reason
- empty-state and section-card presentation language is split between shared shell widgets and local feature wrappers

## Task 14.46: scope the first shared scaffolding normalization batch
Status: completed

Goal:
- choose the smallest normalization batch that improves shared shell polish without flattening feature-specific dashboards or tables

Current best candidate:
- settings section and empty-state scaffolding

Why this is first:
- these are the clearest shell-owned presentation contracts
- they affect multiple settings and utility surfaces directly
- they are safer to normalize than forcing `StructuredDataTable` adoption or rewriting dashboard cards

Done definition:
- the first normalization batch is chosen
- the batch is narrower than “unify all lists and menus”

Result:
- the first normalization batch should target:
  - empty-state normalization
  - thin settings-section wrapper cleanup

### Why these two win first

- both are clearly shell-owned presentation seams
- both already have canonical shared primitives in the repo
- both have visible local shadowing that is narrow and easy to reason about
- neither requires a risky rewrite of richer dashboards, tables, or menu logic

### Concrete first targets

#### Empty-state normalization

Canonical shared primitive:
- `StandardEmptyState`

Current local shadowing to start with:
- `docker_engine_picker.dart` local `EmptyState`

Rule for this batch:
- simple “nothing available / unavailable / refresh” states should use `StandardEmptyState`
- local empty-state widgets are valid only when they add meaningfully richer domain guidance or interaction

#### Thin settings-section wrapper cleanup

Canonical shared primitive:
- `SettingsSection`

Current thin wrappers to start with:
- `EditorSettingsSection`
- `TerminalSettingsSection`

Rule for this batch:
- wrappers that only provide a fixed title/description around one controls widget should be treated as cleanup candidates
- wrappers remain valid only if they add real behavior, composition, or multi-section orchestration

### Explicitly deferred from this first batch

- `StructuredDataTable` adoption pressure
- feature dashboard card unification such as Docker/Server `SectionCard`
- domain-specific action/menu surfaces
- richer domain-specific empty states with custom guidance

## Task 14.47: implement first shared scaffolding normalization batch
Status: completed

Goal:
- remove the narrowest local shadowing around shell-owned empty-state and settings-section scaffolding

First code targets:
- replace Docker engine picker's local `EmptyState` with the shared empty-state path or a thin wrapper over it
- remove or justify the thin `EditorSettingsSection` and `TerminalSettingsSection` wrappers

Done definition:
- the first empty-state shadowing case is normalized
- the first thin settings-section wrappers are removed or explicitly justified
- the shared scaffolding contract is stronger in code, not only in docs

Result:
- Docker engine picker no longer owns a local shell-level empty-state widget
- the simple Docker empty-state path now uses `StandardEmptyState`
- the thin `EditorSettingsSection` and `TerminalSettingsSection` wrappers were removed
- editor and terminal settings tabs now use `SettingsSection` directly around their controls widgets

What this proved:
- shell-owned scaffolding can be normalized without a broad design-system rewrite
- thin “wrapper just to provide title/description” layers are cleanup targets when the shared shell primitive is already good enough
- empty-state normalization is a better first shell polish seam than forcing table/card unification

## Task 14.48: re-scope the next shared scaffolding batch
Status: completed

Goal:
- decide whether the next scaffolding pass should target another empty-state/menu/settings seam or checkpoint this hotspot

Likely candidates:
- remaining empty-state shadowing such as richer Docker availability states
- settings-section consistency in the remaining settings tabs
- shared action/menu scaffolding follow-up

Done definition:
- the next narrow batch is chosen or the hotspot is checkpointed

Result:
- the next shared scaffolding batch should target:
  - shared action/menu scaffolding
- not another empty-state pass yet

Why this wins:
- the simple empty-state shadowing case is already normalized enough for now
- the remaining repeated shell-facing scaffolding is more visible in:
  - action pickers
  - popup menus
  - section-level option menus
- this is a better shell polish target than pushing `StandardEmptyState` into richer domain guidance states

Why the other candidates wait:
- another empty-state batch
  - remaining cases are more domain-specific and less obviously shell-owned
- broader settings-section consistency
  - the main wrapper smell has already been removed

## Task 14.49: scope shared action/menu scaffolding
Status: queued

Goal:
- identify the smallest shared shell action/menu seam that reduces repeated popup/action assembly without flattening domain-specific menu logic

Likely first candidates:
- `ActionPicker` adoption/extension rules
- repeated simple `PopupMenuButton<String>` assembly in:
  - server host list
  - Docker engine picker
  - Docker list sections

Done definition:
- the first action/menu normalization batch is chosen
- the batch stays narrower than “generic menu system”
