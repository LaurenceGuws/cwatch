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
- shell polish will keep stalling if explorer remains “partly shared, partly special, but not clearly documented”

## Current Shared-Surface Candidates

The likely shared explorer surface includes:
- path/state helpers
- selection state
- drag/drop primitives
- shared prompt/confirm integration points already moved out of local widget files
- generic file action flows that should behave consistently across modules

Representative current files:
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)
- [file_explorer_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/file_explorer_controller.dart)
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
- [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
- [explorer_selection_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_selection_state.dart)
- [explorer_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_state.dart)
- [path_utils.dart](/home/home/personal/cwatch/lib/model/shared/services/path_utils.dart)

## Current Ambiguities

### 1. Explorer is shared, but not yet explicitly partitioned

We have already moved several non-UI or shared UI pieces out of feature-local ownership.

What is still unclear:
- which explorer pieces are now canonical shared shell/file tooling
- which pieces are still explorer-local because their interaction contract is genuinely richer or more specific

### 2. Some explorer dialogs should remain local

Examples:
- rename/move/delete flows in [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
- merge-conflict flow in [explorer_merge_conflict_dialog.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_merge_conflict_dialog.dart)

These may be valid explorer-local surfaces even though they live under shared widgets.

The next pass should not flatten them automatically into generic shell prompts just because they are “dialogs”.

### 3. The explorer shell contract is still implicit

Explorer currently acts like a reusable shell subsystem, but the repo does not yet state:
- what explorer behaviors are mandatory shared behavior
- what explorer-specific overrides are acceptable
- which explorer-side widgets/helpers should be reused rather than re-created

## Questions This Hotspot Should Answer

1. What is the canonical shared explorer surface?
2. Which explorer interactions are required shared behavior?
3. Which explorer dialogs/builders remain valid explorer-local exceptions?
4. Which current explorer helpers are truly reusable shell/file primitives?
5. Where should future modules reuse explorer behavior instead of recreating nearby widgets/helpers?

## First Safe Batch

The first batch should be a contract pass, not a broad explorer rewrite.

Why:
- explorer is broad enough that implementation without an explicit contract will drift
- we already have enough cleanup history to define a real boundary instead of guessing
- explorer affects shell polish directly, so the contract matters before more code movement

## Task 14.26: define the explorer shared-surface contract
Status: queued

Goal:
- make the canonical shared explorer surface explicit and separate it from valid explorer-local behavior

Files in scope:
- [file_explorer_tab.dart](/home/home/personal/cwatch/lib/view/shared/views/shared/tabs/file_explorer/file_explorer_tab.dart)
- [file_explorer_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/file_explorer_controller.dart)
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
- [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
- [explorer_merge_conflict_dialog.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_merge_conflict_dialog.dart)
- [explorer_selection_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_selection_state.dart)
- [explorer_state.dart](/home/home/personal/cwatch/lib/model/shared/services/explorer_state.dart)

Done definition:
- the canonical shared explorer surface is named
- valid explorer-local exceptions are named
- one concrete follow-up cleanup batch is chosen
