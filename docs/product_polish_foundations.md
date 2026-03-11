# Product Polish Foundations

Status: active
Purpose: define the next non-structural cleanup layer now that the major rewrite and local-seam testing checkpoints are in place.

## Why This Layer Exists

The repository now has:
- clearer shell/framework vs feature ownership
- explicit placeholder-tab rules
- checkpointed vertical slices
- first-pass infrastructure cleanup
- direct regression coverage around the newest local seams

That changes the next best kind of work.

The next problem is no longer "where should this code live?".
The next problem is:
- do the shared shell surfaces feel intentional and consistent
- do feature placeholder surfaces communicate clearly
- do resource dashboards feel like they belong to the same product
- do simple unavailable/capability states behave consistently
- do reused shell widgets look and feel like one product instead of several cleanup phases stitched together

This layer is about consistency and product-facing coherence without reopening ownership cleanup by default.

## Scope

This layer should improve:
- resource dashboard consistency
- placeholder and empty-state quality
- section/list chrome consistency
- tab-shell polish
- capability breadcrumb consistency

This layer should not:
- reopen broad dependency or ownership cleanup
- introduce new generic frameworks without evidence
- flatten feature-specific dashboards or placeholder behavior into one shared UI
- rewrite already-checkpointed structural seams just because they can be made smaller

## Product Rules

### Rule 1: shared shell polish should strengthen visible consistency
If a shared shell surface already exists, polish should prefer improving that canonical surface over creating another feature-local variation.

Examples:
- `StandardEmptyState`
- `SettingsSection`
- `SectionOverflowMenu`
- `WorkspaceTabChipBuilder`
- shared placeholder/list chrome around module entry surfaces

### Rule 2: placeholder tabs stay feature-owned
The shell enforces the placeholder-tab contract, but each module still owns:
- its placeholder content
- its placeholder actions
- its placeholder-to-working-tab transitions

Polish can improve shared framing around those surfaces.
Polish must not collapse them into one generic picker page.

### Rule 3: capability breadcrumbs should be consistent, not identical
Simple optional-capability absence should feel consistent across features.
Richer domain guidance can stay local when the surface is more than a simple empty or unavailable state.

### Rule 4: polish should start where the architecture is already stable
Do not start with the heaviest bespoke dashboards.
Start with the surfaces that are already explicit shared primitives or obvious shell-level patterns.

## Best First Hotspots

### Hotspot A: placeholder and empty-state polish
Candidate surfaces:
- Docker engine picker empty/unavailable states
- server host-list empty/offline states
- explorer list empty state
- simpler placeholder tabs that still read as temporary or inconsistent

Questions:
- which shared empty-state framing is already canonical
- where are title, body, icon, action, and breadcrumb patterns inconsistent
- what should become the default shell-style placeholder framing

### Hotspot B: resource dashboard consistency
Candidate surfaces:
- server resource panels
- docker resource trends and stats tables
- kubernetes dashboard summary/resources surfaces

Questions:
- what should the default dashboard section framing be
- how should metric cards, metadata rows, and chart containers look by default
- which loading/error/empty states inside dashboards should be shared
- which parts stay feature-owned because the data model and actions are domain-specific

### Hotspot C: section and list chrome consistency
Candidate surfaces:
- settings sections
- section nav bars
- section overflow menus
- grouped list headers in server/docker/kubernetes placeholders
- `StructuredDataTable` hosting surfaces across server/docker/kubernetes/explorer/debug logs

Questions:
- where do section titles, spacing, actions, and secondary labels drift
- what should be the default shell-style section framing
- what should the default table/list hosting chrome be around `StructuredDataTable`
- where are empty/filter/action states around shared tables still inconsistent

### Hotspot D: tab-shell polish
Candidate surfaces:
- chip spacing and affordance consistency
- placeholder tab labels and icon semantics
- tab-level action naming consistency

Questions:
- which parts of the tab shell still feel mechanically reused instead of intentionally designed
- which improvements belong in shared tab-shell surfaces instead of feature-local code

### Hotspot E: capability breadcrumb polish
Candidate surfaces:
- Docker CLI unavailable surface
- Kubernetes unavailable/warning framing
- settings breadcrumbs for optional system integrations

Questions:
- what should simple capability absence look like by default
- how should shared breadcrumbs point users toward settings or built-in alternatives

## Recommended Work Sequence

1. pick one visible shell-facing hotspot
2. define the canonical product rule for that hotspot
3. make one narrow shared improvement with at least two concrete adopters
4. stop and re-scope before broadening the polish layer

## Current Recommendation

Current active hotspot:
- resource dashboard consistency is now at a good checkpoint

Why:
- the first shared dashboard language is now in place across server, docker, and kubernetes
- the biggest visible cross-feature dashboard drift has been reduced without flattening feature-owned composition
- further dashboard work now needs a sharper target, not more default expansion

Current dashboard checkpoint includes:
- shared dashboard section framing
- shared metric summary cards
- shared metadata label/value cards
- shared chart legend chrome
- shared straightforward loading/error/empty feedback

Current next polish move:
- structured table/list chrome consistency

Why:
- `StructuredDataTable` is now one of the most reused visible shell surfaces in the app
- it appears under server host lists, Docker resource/list screens, Kubernetes context/resource surfaces, explorer lists, and debug logs
- the remaining drift is now more about table hosting chrome, density, and surrounding empty/action framing than about dashboard cards

Current first implementation batch:
- scope the shared table/list chrome language around `StructuredDataTable`
- start with hosting/frame consistency, not table internals
- keep feature-specific row actions, domain columns, and row chips local

Current table/list polish direction:
- standardize the hosting surface around `StructuredDataTable`
- not the internal row/column engine

What should become shared:
- table section framing
- title/subtitle/action-bar layout above shared tables
- straightforward loading/empty/filter feedback around shared tables
- default density signals where the same table surface appears across features

What should stay feature-owned:
- domain-specific columns
- row actions and context menus
- row metadata chips
- row-level icons and value formatting

Current next table/list polish move:
- straightforward table-host feedback consistency

Why:
- the next visible shared drift is in loading and empty framing around table-hosted surfaces
- Kubernetes context selection and Docker context/remote tables still vary in surrounding feedback treatment
- debug logs and richer filtered surfaces should remain local for now because they carry more feature-specific controls

Current table/list checkpoint:
- the shared table/list host language is now in place

It currently covers:
- shared table host framing
- shared section title/subtitle layout above hosted tables
- shared straightforward loading/error/empty feedback around table-hosted surfaces

Current next polish move:
- tab-shell polish

Why:
- the shared tab-chip path already exists through:
  - [workspace_tab_chip_builder.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_tab_chip_builder.dart)
  - [tab_chip.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/tab_chip.dart)
- the remaining visible drift is now in:
  - placeholder-tab labels
  - placeholder icon semantics
  - small tab-chip affordance consistency between feature modules
- this is a visible shell-facing surface and now a stronger source of product inconsistency than the checkpointed panel/table/dashboard surfaces

Current tab-shell polish direction:
- standardize tab-shell naming and small chip affordances where the shell already owns the behavior
- not feature-specific tab actions or feature-specific tab content

What should become shared:
- placeholder-tab naming conventions
- placeholder icon semantics
- small chip affordance treatment when the same shell rule repeats

What should stay feature-owned:
- feature-specific tab actions
- feature-specific tab titles once a working tab is open
- domain-specific icons where the tab represents a concrete feature surface rather than a generic placeholder state
