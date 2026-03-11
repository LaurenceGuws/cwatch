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
- do simple unavailable/capability states behave consistently
- do reused shell widgets look and feel like one product instead of several cleanup phases stitched together

This layer is about consistency and product-facing coherence without reopening ownership cleanup by default.

## Scope

This layer should improve:
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

### Hotspot B: section and list chrome consistency
Candidate surfaces:
- settings sections
- section nav bars
- section overflow menus
- grouped list headers in server/docker/kubernetes placeholders

Questions:
- where do section titles, spacing, actions, and secondary labels drift
- what should be the default shell-style section framing

### Hotspot C: tab-shell polish
Candidate surfaces:
- chip spacing and affordance consistency
- placeholder tab labels and icon semantics
- tab-level action naming consistency

Questions:
- which parts of the tab shell still feel mechanically reused instead of intentionally designed
- which improvements belong in shared tab-shell surfaces instead of feature-local code

### Hotspot D: capability breadcrumb polish
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
- placeholder and empty-state polish

Why:
- it is the most visible consequence of the placeholder-tab rule
- it directly affects first impressions of the shell and feature entry surfaces
- the repo already has a canonical shared primitive in `StandardEmptyState`
- it improves consistency without reopening structural ownership work

Current first implementation batch:
- Kubernetes placeholder/context-list empty-state normalization
- Docker remote picker empty/unavailable-state normalization

Why this batch:
- both are visible module entry surfaces
- both currently drift from the shared empty-state path in different ways
- together they are enough evidence to improve shared framing without prematurely touching richer dashboard-level empty states
