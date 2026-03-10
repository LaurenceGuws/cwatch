# Shared Prompt Helper TODO

Status: active
Purpose: scope the first implementation-ready cleanup for the dialog/settings hotspot: a shared prompt helper/catalog for simple input, secret input, and destructive confirmation dialogs.

## Why This Exists

The dialog/settings contract is now explicit.

The next useful step is not to normalize every dialog.

The next useful step is:
- define one shared prompt helper/catalog
- move the simplest duplicated prompt flows onto it first
- leave richer custom dialogs alone

## Current Repeated Patterns

The same prompt patterns are still hand-assembled in multiple adapters:

### Secret/password input
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)
  - `promptForPassword`
  - `promptForKeyPassphrase`

### Destructive confirmation
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)
  - `confirmDeleteKeyInUse`
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
  - multi-delete confirmation
- [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
  - single delete confirmation

### Generic text input
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)
  - `showTextInputDialog`
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)
  - `showTextInputDialog`
- [wsl_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/wsl_ui_adapter.dart)
  - rename prompt

## Proposed Helper Shape

The helper should live in shared widgets/UI infrastructure, not inside one adapter.

Likely home:
- `lib/view/shared/widgets/`

The first helper/catalog should expose three prompt categories.

### 1. Shared text input prompt

Use for:
- rename prompts
- simple label/name prompts
- generic one-field input

Inputs:
- title
- label
- initial value
- hint text
- submit label
- obscure text flag
- helper text

### 2. Shared secret/password prompt

Use for:
- password input
- passphrase input

Inputs:
- title
- label
- helper text
- submit label
- optional alternate action for cases like “try without passphrase”

### 3. Shared destructive confirm prompt

Use for:
- key-delete confirm
- explorer delete/trash confirms where the body is still just title/content/actions

Inputs:
- title
- message
- confirm label
- cancel label
- destructive styling flag

## What Must Stay Local

The first helper should not absorb:
- port-forward dialog
- SSH auth/decrypt dialogs
- merge-conflict dialogs
- dialogs with complex custom bodies or async state machines

## First Migration Slice

The first migration slice should be:
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

Why first:
- it contains the densest cluster of duplicated prompt logic
- it is already functioning like a local prompt subsystem
- it is lower-risk than jumping straight into explorer or SSH auth flows

## Follow-up Migration Order

### 1. SettingsUiAdapter
- password prompt
- passphrase prompt
- destructive confirm

### 2. WslUiAdapter
- rename prompt

### 3. DockerOverviewUiAdapter / ExplorerUiAdapter
- generic text input prompt
- simple destructive confirms where the helper fits

### 4. ExplorerDialogBuilders
- only where the helper cleanly matches the existing prompt shape

## Task 14.13
Status: completed

What this task established:
- the first shared prompt helper should cover:
  - text input
  - secret/password input
  - destructive confirmation
- the first migration slice should be `SettingsUiAdapter`
- richer dialogs remain intentionally out of scope

Verification:
- helper responsibilities are explicit
- first migration slice is chosen
- migration order is incremental

## Task 14.14: implement shared prompt helper for SettingsUiAdapter
Status: queued

Goal:
- introduce the shared prompt helper/catalog and move `SettingsUiAdapter` to it first

Likely files in scope:
- shared prompt helper under `lib/view/shared/widgets/`
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

Done definition:
- settings-side prompt assembly is routed through the shared helper
- behavior stays the same
- the helper remains narrow enough that WSL and generic text-input adapters can adopt it next
