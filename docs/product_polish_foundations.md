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

Questions:
- where do section titles, spacing, actions, and secondary labels drift
- what should be the default shell-style section framing

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

Start with:
- resource dashboard consistency

Why:
- it affects in-use feature surfaces more than entry placeholders
- the current drift is obvious in chart framing, metric summaries, and metadata styling
- server, docker, and kubernetes already provide enough evidence to define shared dashboard primitives
- it improves visible quality without reopening ownership cleanup or flattening feature-specific dashboards

Current first implementation batch:
- define the shared dashboard language from server, docker, and kubernetes resource surfaces
- start with section framing, metric summary cards, and metadata label/value presentation
- leave feature-specific actions, domain grouping, and richer dashboard flows local

Why this batch:
- it targets the most visible consistency gap in active feature work surfaces
- it builds on existing feature dashboards instead of inventing a generic dashboard framework
- it creates reusable visual primitives before touching heavier graph/data rewrites
