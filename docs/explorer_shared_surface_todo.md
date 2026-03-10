# Explorer Shared Surface TODO

Status: active
Purpose: scope the next integration-smell hotspot: clarify which explorer pieces are canonical shared shell/file tooling and which remain valid explorer-local behavior.

## Why This Is Next

The tab shell hotspot is checkpointed.

The dialog/settings hotspot is checkpointed.

The SSH auth hotspot is checkpointed.

The next highest-value shared subsystem is explorer.

Why explorer now:
- it is one of the richest reusable shell/file surfaces in the app
- it already has materially cleaner dependency ownership than before
- it still mixes:
  - shared file tooling expectations
  - explorer-specific interaction flows
  - local builder/dialog behavior
- shell polish will keep stalling if explorer remains "partly shared, partly special, but not clearly documented"

## Canonical Shared Explorer Surface

The explorer subsystem is now shared in the same sense that the tab shell is shared:
- it provides a reusable file-tooling surface
- it should survive removal of SSH, Docker, Kubernetes, and WSL modules
- feature modules should consume it rather than rebuild nearby file tooling casually

The canonical shared explorer surface is:
- explorer state and selection primitives
- path/history/search/file-loading behavior
- file-operation orchestration and clipboard/trash integration
- reusable explorer tab chrome and list interaction behavior
- generic prompt/confirm entry points for simple explorer actions

Representative current files:
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)
- [file_explorer_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/file_explorer_controller.dart)
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
- [explorer_selection_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_selection_state.dart)
- [explorer_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_state.dart)
- [path_utils.dart](/home/home/personal/cwatch/lib/model/shared/services/path_utils.dart)

## Required Shared Behavior

The following explorer behavior should be treated as canonical shared behavior unless there is a real subsystem reason not to:
- path navigation and history semantics
- search activation/reset and streamed search result behavior
- selection ownership and selection clearing rules
- drag/drop session primitives
- clipboard/cut/copy/paste flows
- trash integration and restore notifications
- generic snack-bar and prompt integration points
- base explorer tab layout expectations such as breadcrumbs, settings toggle, and entry-list hosting

These are the behaviors feature modules should reuse, not recreate with near-identical widgets/helpers.

## Valid Explorer-Local Exceptions

Not every explorer-adjacent dialog or interaction should become a generic shell widget.

Valid explorer-local exceptions are:
- rename/move/delete dialog flows in [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
- merge resolution flow in [explorer_merge_conflict_dialog.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_merge_conflict_dialog.dart)
- input-specific selection wrappers in [selection_controller.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/selection_controller.dart)
- dense explorer row/list interaction details that are tightly coupled to explorer semantics

Why these remain local:
- they are not generic shell prompts
- they carry richer file-operation semantics than the shared prompt helper should absorb
- flattening them now would hide valid explorer-specific interaction rules under fake genericity

## Reuse Rules

Future modules should:
- reuse `FileExplorerController` and the shared explorer state/services when they need file-tooling behavior
- reuse `FileExplorerTab` when they need the canonical explorer surface rather than a superficially similar file browser
- use `ExplorerUiAdapter` plus shared prompt helpers for simple prompt/confirm flows
- treat explorer-local dialog builders as the default for richer file-operation dialogs rather than rebuilding local versions nearby

Future modules should not:
- re-create path/history/search logic in feature-local widgets
- fork explorer selection state for cosmetic reasons
- create feature-local rename/move/delete dialogs that only restate explorer behavior with minor copy changes
- bypass the explorer controller/service surface just to wire another small file browser directly

## Current Ambiguities That Remain

### 1. `FileExplorerTab` is both canonical and heavy

It is clearly the canonical shared explorer tab surface.

It is also still a large widget that mixes:
- shared explorer chrome
- list/input handling
- settings visibility state
- desktop drop integration

That is a maintenance problem, but not an ownership ambiguity anymore.

### 2. `ExplorerUiAdapter` still mixes shared prompts and explorer-local dialogs

That is acceptable for now because it is the explorer UI seam.

The important rule is:
- simple prompts should route through shared prompt helpers
- rich explorer dialogs should stay on explorer-local builders

### 3. Shared explorer surface is documented, not yet cataloged

We now have the rule set, but not yet a smaller internal helper catalog for explorer chrome sections such as:
- toolbar/header actions
- settings panel section wiring
- list host scaffolding

That is follow-up work, not a prerequisite for the contract.

## Questions This Hotspot Has Now Answered

1. What is the canonical shared explorer surface?
- the reusable file-tooling subsystem centered on shared controller/state/tab behavior

2. Which explorer interactions are required shared behavior?
- navigation, selection, search, clipboard, trash, drag/drop primitives, and base tab chrome/layout behavior

3. Which explorer dialogs/builders remain valid explorer-local exceptions?
- rename/move/delete builders, merge conflict dialog, and input-specific selection wrapper logic

4. Which current explorer helpers are truly reusable shell/file primitives?
- state, selection, path helpers, controller/service orchestration, and simple prompt integration points

5. Where should future modules reuse explorer behavior instead of recreating nearby widgets/helpers?
- any time they need the canonical file-tooling surface rather than a genuinely different domain-specific file interaction contract

## Task 14.27: define the explorer shared-surface contract
Status: completed

Goal:
- make the canonical shared explorer surface explicit and separate it from valid explorer-local behavior

Done definition:
- the canonical shared explorer surface is named
- valid explorer-local exceptions are named
- one concrete follow-up cleanup batch is chosen

Result:
- the canonical shared explorer surface is now explicit
- valid explorer-local exceptions are now explicit
- the next cleanup batch is narrowed to explorer chrome/helper extraction, not a broad explorer rewrite

## Task 14.28: scope explorer chrome/helper cleanup
Status: completed

Goal:
- identify the smallest shared helper extraction inside `FileExplorerTab` that improves explorer polish without flattening valid explorer-local interaction behavior

Candidates considered:
- header/toolbar action row
- settings panel host wiring
- entry-list host/scaffold sections around loading/error/drop-overlay states

Decision:
- the first cleanup batch should target a shared explorer chrome scaffold around:
  - `PathNavigator` hosting
  - loading/error/streaming/drop-overlay content hosting
  - floating settings window hosting

Why this is the right first cut:
- it is clearly shared explorer chrome, not domain-specific file-operation behavior
- it sits at the top of `FileExplorerTab`, where shell polish is most visible
- it avoids destabilizing the denser explorer list/input behavior in `_buildEntriesList()`
- it does not flatten valid explorer-local dialogs into fake generic prompts

Why the other candidates wait:
- header/toolbar action row
  - currently mostly lives inside `PathNavigator`, so extracting it first would cut across a less stable seam
- entry-list behavior
  - too tightly coupled to selection/input behavior and should not be the first polish extraction

Done definition:
- one narrow helper extraction is selected
- the extraction is justified as shared explorer chrome, not explorer-specific dialog behavior

Result:
- the next explorer cleanup batch is now explicit: shared explorer chrome scaffold extraction

## Task 14.29: extract shared explorer chrome scaffold
Status: queued

Goal:
- pull the top-level shared explorer chrome hosting out of `FileExplorerTab` into a narrower helper/widget without moving explorer-specific list/input behavior

Expected scope:
- path navigator host
- loading/error/streaming/drop-overlay host
- floating settings host

Out of scope:
- `_buildEntriesList()` selection/list behavior
- explorer dialog builders
- merge conflict flow

Done definition:
- `FileExplorerTab` delegates top-level chrome hosting to one narrower shared helper
- explorer-specific list/input behavior remains in place
- the result reads as shared explorer chrome rather than another generic shell widget
