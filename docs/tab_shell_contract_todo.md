# Tab Shell Contract TODO

Status: active
Purpose: define the canonical shared tab shell surface so shell polish and feature-level overrides stop drifting implicitly.

## Why This Exists

The tab shell is now the first normalization hotspot in the integration-smell layer.

This is the right place to start because:
- it is the clearest shell-identity surface
- it is used across servers, docker, kubernetes, and WSL
- feature modules currently hand-assemble tab behavior around a common shared core
- shell polish will stay fragile until the shared tab contract is explicit

## Current Shared Tab Shell Surface

The current shared core already exists:
- [workspace_tab.dart](/home/home/personal/cwatch/lib/controller/core/workspace/workspace_tab.dart)
- [tab_options.dart](/home/home/personal/cwatch/lib/controller/core/workspace/tab_options.dart)
- [tab_host_controller.dart](/home/home/personal/cwatch/lib/controller/core/workspace/tab_host_controller.dart)
- [tab_host_view.dart](/home/home/personal/cwatch/lib/view/core/tabs/tab_host_view.dart)
- [tab_view_registry.dart](/home/home/personal/cwatch/lib/view/core/tabs/tab_view_registry.dart)
- [tabbed_workspace_shell.dart](/home/home/personal/cwatch/lib/view/core/tabs/tabbed_workspace_shell.dart)
- [tab_chip.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/tab_chip.dart)

This means the problem is no longer missing primitives.

The problem is contract ambiguity:
- what the shell guarantees
- what features must provide
- which tab-level behavior is mandatory shared behavior
- which tab-level behavior is feature-owned

## Current Integration Smells In This Hotspot

### 1. Feature modules still hand-assemble chip integration

Servers, Docker, Kubernetes, and WSL all:
- wrap `TabChip` themselves
- map `WorkspaceTab` state into chip props
- decide how options flow into the chip
- add local tab actions near the chip boundary

That is not always wrong, but it is currently under-specified.

### 2. Picker/base-tab behavior is feature-owned but not described at the tab shell level

This is consistent with the placeholder-tab rule, but the tab shell contract does not currently explain:
- what the shell should treat as generic picker/base-tab behavior
- what is entirely feature-local
- where picker-specific exceptions are acceptable in chip behavior and tab actions

### 3. Command-palette and tab-option integration is repeated

Several feature views repeat the same pattern:
- read `tab.optionsController`
- expose those entries through a command palette section
- append generic tab actions such as rename/close/new

That is a strong sign of an under-defined shell integration surface.

### 4. Tab close/rename/drag rules are mixed between shared state and feature-local policy

`WorkspaceTab` exposes:
- `canRename`
- `canDrag`
- `isPicker`
- `optionsController`

Feature modules add:
- close warnings
- picker-specific restrictions
- extra menu items
- local action visibility rules

These are all valid inputs, but the contract for them is not explicit.

## Canonical Shared Tab Shell Contract

### Shared shell responsibilities

The shared tab shell should own:
- tab list state and selection semantics
- base-tab existence rules
- tab host rendering
- tab body keep-alive and view registry behavior
- common chip structure and interaction shell
- common tab actions:
  - select
  - close
  - drag/reorder
  - rename trigger when permitted
  - overflow/options trigger

### Feature responsibilities

Feature modules should own:
- tab creation
- tab body content
- tab metadata:
  - title
  - label
  - icon
  - workspace state
- feature-local tab options
- feature-specific close warnings
- whether a specific tab can be renamed or dragged
- placeholder-tab behavior and picker semantics

### Shared shell inputs from features

The shared tab shell should accept feature-provided inputs, not require feature-local chip reassembly for routine cases.

Stable shared inputs already visible in the codebase:
- `WorkspaceTab`
- `TabChipOption`
- `TabCloseWarning`
- selected state
- rename/close/reorder callbacks

## Mandatory Shared Behavior

The following should be treated as mandatory shared tab-shell behavior:
- one shared chip structure
- one shared close affordance model
- one shared drag/reorder interaction model
- one shared options affordance model
- one shared selected/hover/focus visual contract
- one shared base-tab handling model through `TabHostController`

If a feature needs different data, it should provide different tab metadata.
If a feature needs different behavior, it should do so through explicit extension/override seams.

It should not silently re-create chip assembly by default.

## Allowed Feature Overrides

These are valid override categories:
- feature-specific close warnings
- feature-specific tab options
- feature-specific icon/label/title content
- picker-tab restrictions such as:
  - not draggable
  - not renameable
  - different option set
- feature-specific command-palette entries beyond shared tab actions

## Bad Overrides

These should be treated as cleanup smells unless explicitly justified:
- re-implementing the chip structure in feature code
- duplicating generic rename/close/new-tab command wiring per feature when the behavior is identical
- feature-local recreation of common tab action menus with only tiny differences
- feature-specific visual changes to the chip that are really shell styling concerns

## Best Current Next Cleanup Target

The smallest high-value normalization after this contract is:
- define a shared tab-shell adapter/helper around `WorkspaceTab -> TabChip` mapping and generic tab command contribution

Why this is next:
- it directly attacks the repeated feature-level chip assembly
- it does not require redesigning tab state primitives
- it gives shell polish one canonical integration path

## Task 14.3
Status: completed

What this task established:
- the canonical shared tab shell responsibilities
- the feature-owned tab responsibilities
- the allowed override categories
- the main repeated integration smell: feature-local `WorkspaceTab -> TabChip` assembly and duplicated generic tab action wiring

Verification:
- this doc names the shared tab shell contract explicitly
- this doc distinguishes mandatory shared behavior from allowed feature overrides
- one concrete follow-up cleanup target is chosen

## Task 14.4: scope shared tab-shell adapter cleanup
Status: completed

Goal:
- define the smallest shared helper/adapter that removes repeated feature-level chip assembly without flattening valid feature differences

Likely scope:
- shared `WorkspaceTab` to chip input mapping
- shared generic tab command contribution
- feature-provided overrides for:
  - close warning
  - extra tab options
  - picker restrictions

Done definition:
- the first actual normalization batch is scoped
- the scope is narrower than “rewrite the tab system”

Result:
- the first normalization batch should introduce a shared tab-shell adapter/helper
- that helper should standardize routine `WorkspaceTab -> TabChip` assembly and generic tab command contribution
- feature modules should only supply the small pieces that are truly feature-specific

## Scoped Cleanup Shape

### Shared helper responsibilities

The first shared helper should cover:
- routine `WorkspaceTab` to `TabChip` mapping
- `ValueListenableBuilder` wrapping for `tab.optionsController`
- generic chip callbacks:
  - select
  - close
  - rename trigger
  - drag index
- generic command contributions:
  - tab options
  - rename tab
  - close tab
  - new tab

### Feature-provided inputs

The helper should let features supply only what is actually local:
- host mapping for chip display
- extra tab options beyond the shared/default options
- close warning
- picker restrictions such as:
  - not draggable
  - not renameable
  - picker-only options
- feature-owned command-palette entries beyond shared tab actions

### Why this is the right first batch

It matches the repeated patterns already visible in:
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)

Repeated today:
- build `TabChip`
- read `tab.optionsController`
- pass select/close/rename/drag props
- append generic tab command entries

Feature-local differences that should remain:
- host identity mapping
- close warnings
- picker restrictions
- extra module-specific options

## Not In The First Batch

The first batch should not:
- rewrite `WorkspaceTab`
- redesign `TabHostController`
- redesign the placeholder-tab contract
- flatten all feature command palettes into one shared registry
- change tab visuals broadly

## Concrete Next Batch

### Task 14.5: add shared tab-shell adapter TODO
Status: completed

Goal:
- define the exact helper API and ownership boundary before code changes

Likely scope:
- shared chip adapter/builder under the tab shell
- shared generic tab command builder/helper
- migration plan for:
  - WSL
  - Kubernetes
  - Docker
  - Servers

Done definition:
- helper responsibilities are explicit
- migration starts with the smallest feature first
- the next code batch is implementation-ready rather than exploratory

What landed:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Result:
- the helper is split into:
  - shared chip-building
  - shared generic tab-command contribution
- WSL is selected as the proving slice
- migration order is now explicit:
  - WSL
  - Kubernetes
  - Docker
  - Servers

Next executable batch:
- `Task 14.6`: implement the shared tab-shell adapter for WSL

Current implementation checkpoint:
- WSL now uses the shared chip builder proving slice
- Kubernetes now uses the shared chip builder for the routine options-controller case
- Docker now uses the shared chip builder for picker restrictions and picker-only options
