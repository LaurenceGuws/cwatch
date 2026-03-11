# Product Polish TODO

Status: active
Purpose: track small, visible, high-leverage consistency improvements now that the structural rewrite layers are checkpointed.

## Task 21.1: start the product polish layer
Status: completed

Goal:
- make product polish and consistency an explicit tracked layer instead of an ad hoc cleanup pass

Done definition:
- there is one high-level polish scope doc
- there is one actionable TODO doc for the layer
- the current best first hotspot is named

Result:
- the product polish layer is now explicitly tracked
- the first hotspot should be placeholder and empty-state polish

## Task 21.2: define the placeholder/empty-state polish target
Status: completed

Goal:
- identify the current canonical shared empty-state framing
- identify the most visible inconsistent adopters
- choose one narrow first implementation batch

Questions to answer:
- which surfaces already use `StandardEmptyState`
- which placeholder or unavailable surfaces still drift in wording, spacing, action placement, or icon treatment
- what should become the shared default framing without flattening feature-specific behavior

Done definition:
- one bounded placeholder/empty-state batch is chosen
- the first implementation slice is explicit

Result:
- the canonical shared empty-state path remains:
  - [standard_empty_state.dart](/home/home/personal/cwatch/lib/view/shared/widgets/standard_empty_state.dart)
- the first visible inconsistency batch should target:
  - Kubernetes placeholder/context-list empty states that still use plain `Text`
  - Docker remote picker empty/unavailable states that do not yet use the same shared framing quality as local contexts
  - one shared improvement to `StandardEmptyState` only if it is justified by at least two adopters in the same batch

Why this is the right first cut:
- these are highly visible placeholder-entry surfaces
- they sit directly on top of the placeholder-tab rule
- they already overlap with capability and entry-surface polish without reopening ownership work
- this avoids jumping into dashboard-specific empty states, which are richer and more feature-local

What should wait:
- Kubernetes dashboard-level unavailable and no-data cards
- Docker overview tab empty states
- lower-priority settings/debug-log empty states

First implementation batch:
- normalize Kubernetes context placeholder/list empty states onto `StandardEmptyState`
- normalize Docker remote picker "no ready remotes" framing onto the same shared path
- only extend `StandardEmptyState` if the two adopters reveal one real missing shared affordance

## Task 21.3: implement the first placeholder/empty-state polish batch
Status: completed

Goal:
- normalize the first visible placeholder/empty-state inconsistencies onto the existing shared empty-state path

Done definition:
- Kubernetes placeholder/list empty states no longer use plain `Text` fallback blocks
- Docker remote picker empty/unavailable states use the same shared empty-state framing quality
- no new generic dashboard framework is introduced

Result:
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart) now uses `StandardEmptyState` for context-load failure and no-context states
- [kubernetes_context_picker.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_context_picker.dart) now uses `StandardEmptyState` for context-load failure and no-context states
- [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart) now uses `StandardEmptyState` for remote "no Docker-ready hosts" states with a real retry action

Why this batch is a good checkpoint:
- it improves the most visible placeholder-entry surfaces without reopening ownership work
- it strengthens one canonical shared path instead of adding a new UI abstraction
- it leaves richer dashboard-specific unavailable states for a later dashboard-focused polish batch

## Task 21.4: define the resource dashboard polish target
Status: completed

Goal:
- identify the shared visual drift across server, docker, and kubernetes dashboard/resource surfaces
- define which dashboard primitives should become consistent without flattening feature-owned composition
- choose one narrow first implementation batch

Questions answered:
- where do chart containers, summary cards, metadata rows, and section headers drift today
- which dashboard states should stay local because they are domain-specific
- what is the smallest useful shared dashboard language we can improve first

Done definition:
- one bounded resource-dashboard polish batch is chosen
- the first implementation slice is explicit

Result:
- the strongest current drift is in:
  - section framing between server resource panels, Docker chart/table surfaces, and Kubernetes dashboard sections
  - summary/metric card presentation
  - metadata label/value styling and chip treatment
- the first shared dashboard language should cover:
  - section container framing
  - metric summary card style
  - metadata key/value presentation
- the following should remain feature-owned for now:
  - feature-specific actions
  - domain grouping and ordering
  - richer dashboard flows and remediation states

Why this is the right first cut:
- it targets the most visible quality drift on active feature surfaces
- it avoids inventing a generic dashboard framework
- it gives shared visual primitives that multiple dashboards can adopt incrementally

First implementation batch:
- define and adopt a shared dashboard section/card language across:
  - server resource panels
  - docker resource trends/stats surfaces
  - kubernetes dashboard summary/resources surfaces
- start with:
  - section framing
  - metric summary cards
  - metadata label/value styling
- do not rewrite chart logic or data shaping in the first batch

## Task 21.5: implement the first resource dashboard polish batch
Status: completed

Goal:
- introduce shared dashboard primitives for the first consistency pass
- adopt them in the most visible server, Docker, and Kubernetes resource surfaces
- improve framing and metadata styling without changing feature data flow or chart logic

Done definition:
- one shared dashboard primitives file exists
- server resource panels use the shared section framing
- Docker resources use the shared section framing plus first summary/metadata cards
- Kubernetes dashboard/resources use the shared section framing plus first summary/metadata cards

Result:
- added [dashboard_primitives.dart](/home/home/personal/cwatch/lib/view/shared/widgets/dashboard/dashboard_primitives.dart)
- server resource panels now inherit shared dashboard section framing through:
  - [resource_widgets.dart](/home/home/personal/cwatch/lib/view/features/servers/widgets/resources/resource_widgets.dart)
- Docker resources now use shared dashboard primitives in:
  - [docker_resources.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_resources.dart)
- Kubernetes dashboard/resources now use shared dashboard primitives in:
  - [kubernetes_dashboard_view.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart)
  - [kubernetes_resources.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_resources.dart)

Why this is a good checkpoint:
- the dashboards now share a visible section/card language without becoming one generic dashboard framework
- metadata presentation is more intentional on Docker and Kubernetes surfaces
- chart logic, table logic, and feature-specific actions remain local

## Task 21.6: tighten shared dashboard chart chrome
Status: completed

Goal:
- remove the remaining obvious drift in chart legend styling across dashboard/resource surfaces
- extend the shared dashboard language only where there is already clear cross-feature reuse

Done definition:
- chart legends use one shared visual treatment
- Docker and Kubernetes resource charts both adopt it
- no new graph/data abstraction is introduced

Result:
- [dashboard_primitives.dart](/home/home/personal/cwatch/lib/view/shared/widgets/dashboard/dashboard_primitives.dart) now includes `DashboardLegendChip`
- Docker chart legends now use the shared legend chip in:
  - [docker_resources.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_resources.dart)
- Kubernetes chart legends now use the same shared legend chip in:
  - [kubernetes_resources.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_resources.dart)

Why this is a good checkpoint:
- the remaining chart chrome now reads as one product surface
- it improves consistency without touching chart logic, data shaping, or feature-specific metrics

## Task 21.7: normalize dashboard feedback states
Status: completed

Goal:
- tighten the remaining shared drift in dashboard loading/error/empty feedback
- keep richer domain-specific remediation local while standardizing straightforward feedback states

Done definition:
- one shared dashboard feedback primitive exists
- Docker resources use it for loading/error/chart-empty feedback
- Kubernetes dashboard/resources use it for loading/error/empty feedback

Result:
- [dashboard_primitives.dart](/home/home/personal/cwatch/lib/view/shared/widgets/dashboard/dashboard_primitives.dart) now includes `DashboardFeedbackState`
- Docker resources now use the shared feedback path in:
  - [docker_resources.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_resources.dart)
- Kubernetes dashboard/resources now use the same feedback path in:
  - [kubernetes_dashboard_view.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_dashboard_view.dart)
  - [kubernetes_resources.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/widgets/kubernetes_resources.dart)

Why this is a good checkpoint:
- the remaining obvious dashboard-state drift is reduced
- feedback now reads as one system for straightforward loading/error/empty cases
- richer dashboard-specific guidance is still free to stay local

## Task 21.8: checkpoint dashboard polish
Status: completed

Goal:
- stop the dashboard polish layer at a defensible point
- make the current dashboard language explicit as a checkpoint instead of an endlessly expanding hotspot

Done definition:
- the dashboard polish layer is recorded as checkpointed
- the docs no longer imply that more dashboard work should continue by default

Result:
- resource dashboard consistency is now treated as a product-polish checkpoint
- the shared dashboard language currently covers:
  - section framing
  - metric summary cards
  - metadata label/value cards
  - chart legend chrome
  - straightforward feedback states
- any further dashboard work should reopen from a narrower visible issue such as:
  - table chrome density
  - server-specific metadata readability
  - richer chart presentation rules

Why this is the right stop:
- the biggest cross-feature dashboard drift is already reduced
- pushing further without a sharper target would risk generic cleanup for its own sake

## Task 21.9: define the structured table/list polish target
Status: completed

Goal:
- identify the next visible repeated shell surface after the dashboard checkpoint
- choose a narrow product-polish hotspot with multiple real adopters

Done definition:
- one next polish hotspot is chosen from current UI evidence
- the first implementation cut is explicit

Result:
- the next visible hotspot is:
  - structured table/list chrome consistency
- the strongest repeated shared surface is:
  - [structured_data_table.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table.dart)
- real adopters include:
  - server host lists
  - Docker list/resource screens
  - Kubernetes context/resource screens
  - explorer entry lists
  - debug logs

Why this is the right next move:
- it is now one of the most reused visible work surfaces in the app
- the likely remaining drift is in hosting chrome, spacing, and surrounding actions/empty states, not in dashboard cards
- it gives a high-leverage polish surface without reopening structural cleanup

First implementation batch:
- scope the shared hosting/frame language around `StructuredDataTable`
- start with table hosting chrome and density signals
- keep feature-specific row actions, column sets, and domain chips local

## Task 21.10: define the structured table/list chrome contract
Status: completed

Goal:
- define the correct boundary for polishing the shared table/list surface
- avoid drifting into a rewrite of `StructuredDataTable` internals or feature-specific row behavior

Done definition:
- the shared vs feature-owned parts of the table/list surface are explicit
- one narrow first implementation batch is chosen

Result:
- the shared shell-owned part is now scoped as:
  - hosting/frame consistency around `StructuredDataTable`
  - section title/subtitle/action layout above the table
  - straightforward empty/loading/filter feedback around the table surface
  - default density signals where the same table surface repeats
- the feature-owned part is now scoped as:
  - columns
  - row actions
  - domain chips
  - row-level icons and formatting

Why this is the right boundary:
- it gives a high-leverage polish surface without destabilizing the table engine
- it keeps feature behavior and domain expression local
- it matches how the current drift actually appears in server, Docker, Kubernetes, explorer, and debug-log surfaces

First implementation batch:
- define a shared table host/scaffold surface around `StructuredDataTable`
- prove it first on:
  - server host list sections
  - kubernetes context selection sections
  - one Docker table-hosting surface

## Task 21.11: implement the first structured table/list polish batch
Status: completed

Goal:
- introduce a shared host/scaffold around `StructuredDataTable`
- prove it on the first three visible surfaces without touching table internals or feature row behavior

Done definition:
- one shared table host/scaffold widget exists
- server host list sections use it
- kubernetes context selection sections use it
- one Docker table-hosting surface uses it

Result:
- added [structured_data_table_host.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_host.dart)
- first adopters are:
  - [host_list.dart](/home/home/personal/cwatch/lib/view/features/servers/servers/host_list.dart)
  - [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
  - [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart)

Why this is a good checkpoint:
- the surrounding hosting chrome for shared tables is now more coherent
- feature-specific columns, row actions, and domain chips remain untouched
- this proves the table-host polish seam without reopening `StructuredDataTable` internals

## Task 21.12: re-scope the next structured table/list batch
Status: completed

Goal:
- decide whether table/list polish has one more real shared batch after the first host/scaffold pass

Done definition:
- either the table/list layer is checkpointed
- or one narrower next batch is chosen from visible repeated drift

Result:
- there is one more real shared batch:
  - straightforward table-host feedback consistency
- this should cover:
  - loading framing around table-hosted surfaces
  - empty-state framing around shared tables
- this should not cover:
  - debug-log filter bars
  - richer search/filter dashboards
  - feature-specific remediation or action bars

Why this is the right next cut:
- it is still a repeated visible surface around `StructuredDataTable`
- it keeps the batch narrow and product-facing
- it avoids drifting into feature-specific search/filter UX

## Task 21.13: implement the table-host feedback batch
Status: completed

Goal:
- normalize straightforward loading and empty framing around shared table-hosted surfaces
- keep richer feature-specific filters and remediation local

Done definition:
- the shared table host surface has a feedback variant
- Kubernetes context selection uses it for loading/error/empty states
- Docker local-context hosting uses it for loading state

Result:
- [structured_data_table_host.dart](/home/home/personal/cwatch/lib/view/shared/widgets/data_table/structured_data_table_host.dart) now includes `StructuredDataTableFeedback`
- Kubernetes context selection now uses the shared feedback host in:
  - [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- Docker local-context hosting now uses the same feedback host in:
  - [docker_engine_picker.dart](/home/home/personal/cwatch/lib/view/features/docker/widgets/docker_engine_picker.dart)

Why this is a good checkpoint:
- the visible table-host feedback drift is reduced on the main proving surfaces
- debug logs and richer filtered views remain local as intended
- the batch improved the shared table-host seam without expanding into feature-specific search/filter UI

## Task 21.14: checkpoint table/list polish
Status: completed

Goal:
- stop the structured table/list polish layer at a defensible point
- make the current shared table-host language explicit as a checkpoint

Done definition:
- the table/list polish layer is recorded as checkpointed
- the docs no longer imply that table/list work should continue by default

Result:
- structured table/list chrome consistency is now treated as a product-polish checkpoint
- the shared table-host language currently covers:
  - host/scaffold framing
  - section title/subtitle layout
  - straightforward loading/error/empty feedback
- any further table/list work should reopen from a narrower visible issue such as:
  - density tuning
  - action-bar consistency
  - richer filtered/table-dashboard surfaces

Why this is the right stop:
- the biggest repeated table-host drift is already reduced
- pushing further without a sharper target would risk generic cleanup instead of product value

## Task 21.15: define the floating settings/panel polish target
Status: completed

Goal:
- identify the next visible repeated shell surface after the table/list checkpoint
- choose a narrow product-polish hotspot with multiple real adopters

Done definition:
- one next polish hotspot is chosen from current UI evidence
- the first implementation cut is explicit

Result:
- the next visible hotspot is:
  - floating settings and auxiliary panel chrome consistency
- the strongest repeated shared surface is:
  - [floating_settings_window.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/settings/floating_settings_window.dart)
- real adopters include:
  - Docker picker settings overlay
  - Kubernetes list settings overlay
  - explorer floating settings host
  - editor and terminal floating settings panels

Why this is the right next move:
- these overlays are now more visually inconsistent than the checkpointed dashboard and table hosts
- they are visible, reused shell-facing surfaces
- the likely remaining drift is in chrome, spacing, and close/header treatment, not in feature-specific controls

## Task 21.16: define the floating settings/panel polish contract
Status: completed

Goal:
- define what part of floating settings/panel treatment should become consistent
- keep feature content and sizing decisions local where needed

Done definition:
- the shared polish boundary is explicit
- the first implementation batch is locked

Result:
- shared:
  - header/title/close spacing
  - panel border/radius/elevation treatment
  - default interior padding and section spacing
- feature-owned:
  - panel contents
  - feature actions/toggles
  - special sizing constraints when needed

First implementation batch:
- tighten shared chrome in [floating_settings_window.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/settings/floating_settings_window.dart)
- prove it first on:
  - Docker picker settings overlay
  - Kubernetes list settings overlay
  - explorer floating settings host

## Task 21.17: implement the first floating settings/panel polish batch
Status: completed

Goal:
- tighten the shared chrome around lightweight floating settings/panel surfaces
- improve the visible shell-facing panel treatment without changing feature-local panel contents

Done definition:
- the shared floating panel surface has more intentional chrome
- Docker, Kubernetes, explorer, editor, and terminal all inherit the shared improvement
- no feature-specific content wiring changes are needed

Result:
- [floating_settings_window.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/settings/floating_settings_window.dart) now has:
  - stronger elevation and clipping
  - cleaner border/radius treatment
  - more intentional header spacing
  - improved close affordance styling
  - normalized interior padding and divider tone
  - normalized body text spacing inside panel content

Why this is a good checkpoint:
- it improves a reused shell-facing surface directly
- it benefits multiple active features at once
- it stays inside the shared chrome boundary and does not flatten feature-specific panel contents

## Task 21.18: checkpoint floating settings/panel polish
Status: completed

Goal:
- stop the floating-panel polish layer at a defensible point
- make the current shared panel chrome language explicit as a checkpoint

Done definition:
- the floating-panel polish layer is recorded as checkpointed
- the docs no longer imply that floating-panel work should keep expanding by default

Result:
- floating settings and auxiliary panel chrome consistency is now treated as a product-polish checkpoint
- the shared floating-panel language currently covers:
  - header/title/close spacing
  - border/radius/elevation treatment
  - interior padding and divider tone
  - normalized panel body text spacing
- any further floating-panel work should reopen from a narrower visible issue such as:
  - drag affordance polish
  - panel sizing heuristics
  - panel-specific action-bar consistency

Why this is the right stop:
- the biggest repeated floating-panel drift is already reduced
- pushing further without a sharper target would risk generic cleanup instead of product value

## Task 21.19: define the tab-shell polish target
Status: completed

Goal:
- identify the next visible repeated shell surface after the floating-panel checkpoint
- choose a narrow product-polish hotspot with multiple real adopters

Done definition:
- one next polish hotspot is chosen from current UI evidence
- the first implementation cut is explicit

Result:
- the next visible hotspot is:
  - tab-shell polish
- the strongest repeated shared surface is:
  - [workspace_tab_chip_builder.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_tab_chip_builder.dart)
  - [tab_chip.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/tab_chip.dart)
- the clearest remaining drift is in:
  - placeholder-tab labels
  - placeholder icon semantics
  - small tab-chip affordance consistency across feature modules

Why this is the right next move:
- tab chips are always visible in active module surfaces
- the shared shell path already exists, so polish can happen without reopening ownership cleanup
- the likely remaining drift is in naming and chrome details, not feature tab behavior

## Task 21.20: define the tab-shell polish contract
Status: completed

Goal:
- define what part of tab-shell treatment should become more consistent
- keep feature-specific tab behavior and domain identity local

Done definition:
- the shared polish boundary is explicit
- the first implementation batch is locked

Result:
- shared:
  - placeholder-tab naming conventions
  - placeholder icon semantics
  - small tab-chip affordance treatment where the same shell rule repeats
- feature-owned:
  - feature-specific tab actions
  - feature-specific working-tab titles
  - domain-specific icons for concrete non-placeholder tabs

First implementation batch:
- tighten placeholder tab naming and icon consistency across:
  - Docker picker tabs
  - Kubernetes placeholder/context-list tabs
  - server placeholder tabs
- only touch shared chip chrome if at least two adopters need the same visible adjustment
