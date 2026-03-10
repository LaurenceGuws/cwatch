# Tab Shell Adapter TODO

Status: active
Purpose: define the first implementation-ready normalization batch for the shared tab shell: a helper/adapter that absorbs repeated chip assembly and generic tab command contribution.

## Why This Exists

The tab shell contract is now explicit.

The next useful step is not a broad tab-system rewrite.

The next useful step is:
- introduce one shared helper/adapter
- migrate the smallest feature to it first
- prove the helper removes real duplication without flattening valid feature differences

## Current Repeated Patterns

Across feature views, the same routine logic is repeated:
- wrap `TabChip`
- map `WorkspaceTab` into chip props
- bind generic callbacks:
  - select
  - close
  - rename
  - drag
- optionally wrap with `ValueListenableBuilder` for `tab.optionsController`
- expose generic tab command entries:
  - tab options
  - rename tab
  - close tab
  - new tab

This repetition is visible in:
- [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)

## Proposed Helper Shape

The first helper should live with the shared tab shell, not inside a feature.

Likely home:
- `lib/view/core/tabs/`

It should provide two small responsibilities.

### 1. Shared chip builder/helper

Responsibilities:
- build a `TabChip` from a `WorkspaceTab`
- subscribe to `tab.optionsController` when present
- apply generic chip behavior

Feature-supplied inputs:
- `hostForTab`
- `closeWarningForTab`
- `extraOptionsForTab`
- `renameTab`
- `closeTab`
- `selectTab`
- optional picker restrictions override

### 2. Shared generic tab command helper

Responsibilities:
- convert `tab.optionsController` entries into command-palette entries
- append generic tab commands:
  - rename tab
  - close tab
  - new tab

Feature-supplied inputs:
- module id
- selected tab index
- rename callback
- close callback
- new-tab callback
- extra feature command entries

## What Must Stay Feature-Owned

This helper must not absorb:
- placeholder-tab behavior
- tab body construction
- host/workspace-state interpretation
- feature-specific close warning policy
- feature-specific command categories beyond shared tab actions
- feature-specific picker option rules

## First Migration Order

### 1. WSL

Why first:
- smallest chip assembly
- no extra tab options wiring
- no close-warning complexity
- lowest-risk proving slice

### 2. Kubernetes

Why second:
- still relatively simple
- adds host mapping and options-controller usage without the heavier server/docker differences

### 3. Docker

Why third:
- adds picker-specific restrictions and picker-only options

### 4. Servers

Why last:
- adds the heaviest local behavior:
  - extra default options
  - host mapping from workspace state
  - terminal close warnings

## Task 14.5
Status: completed

What this task established:
- the helper should be split into chip-building and generic tab-command responsibilities
- WSL is the smallest proving slice
- migration order should be:
  - WSL
  - Kubernetes
  - Docker
  - Servers

Verification:
- helper responsibilities are explicit
- feature-owned exclusions are explicit
- migration order is justified and incremental

## Task 14.6: implement the shared tab-shell adapter for WSL
Status: completed

Goal:
- introduce the shared helper and migrate WSL first

Likely files in scope:
- shared tab-shell helper under `lib/view/core/tabs/`
- [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)

Done definition:
- WSL no longer hand-assembles routine `TabChip` wiring
- behavior is unchanged
- the helper remains narrow enough that Kubernetes can adopt it next without redesign

What landed:
- [workspace_tab_chip_builder.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_tab_chip_builder.dart)
- [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart) now uses the shared chip builder instead of hand-assembling routine `TabChip` wiring

What this proved:
- the shared helper can absorb routine chip assembly without flattening feature-owned tab creation
- the first seam can stay narrow:
  - shared chip-building only
  - no premature command-palette unification

Next executable batch:
- `Task 14.7`: adopt the shared chip builder in Kubernetes

## Task 14.7: adopt the shared chip builder in Kubernetes
Status: completed

Goal:
- migrate the routine Kubernetes chip assembly onto the shared helper

Done definition:
- Kubernetes no longer hand-assembles routine `TabChip` wiring
- the helper still stays narrow and does not need feature-specific growth for the routine options-controller case

What landed:
- [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart) now uses the shared chip builder instead of hand-assembling routine `TabChip` wiring

What this proved:
- the shared helper still holds when `tab.optionsController` is present
- Kubernetes did not need extra adapter growth beyond simple host mapping and generic callbacks

Next executable batch:
- `Task 14.8`: adopt the shared chip builder in Docker

## Task 14.8: adopt the shared chip builder in Docker
Status: completed

Goal:
- migrate Docker chip assembly onto the shared helper without weakening picker-specific restrictions

Done definition:
- Docker no longer hand-assembles routine `TabChip` wiring
- the shared helper still handles picker restrictions and picker-only extra options without broader redesign

What landed:
- [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart) now uses the shared chip builder instead of hand-assembling routine `TabChip` wiring

What this proved:
- the helper can handle:
  - picker-specific drag/rename restrictions
  - picker-only extra options
  - close warnings
- Docker did not require a second abstraction layer before reuse

Next executable batch:
- `Task 14.9`: adopt the shared chip builder in Servers

## Task 14.9: adopt the shared chip builder in Servers
Status: completed

Goal:
- migrate the heaviest chip assembly case onto the shared helper without losing host mapping, extra default options, or close warnings

Done definition:
- Servers no longer hand-assemble routine `TabChip` wiring
- the helper still absorbs the shared behavior while keeping server-specific inputs local

What landed:
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) now uses the shared chip builder instead of hand-assembling routine `TabChip` wiring

What this proved:
- the helper still holds for the heaviest current case:
  - host mapping from workspace state
  - extra default options
  - terminal close warnings
- the first chip-building normalization pass is complete across:
  - WSL
  - Kubernetes
  - Docker
  - Servers

Next executable batch:
- re-scope whether the next tab-shell normalization should target generic tab command contribution or stop the tab-shell hotspot at this checkpoint
