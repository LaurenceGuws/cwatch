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
Status: completed

Goal:
- introduce the shared prompt helper/catalog and move `SettingsUiAdapter` to it first

Likely files in scope:
- shared prompt helper under `lib/view/shared/widgets/`
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

Done definition:
- settings-side prompt assembly is routed through the shared helper
- behavior stays the same
- the helper remains narrow enough that WSL and generic text-input adapters can adopt it next

What landed:
- [shared_prompt_dialogs.dart](/home/home/personal/cwatch/lib/view/shared/widgets/shared_prompt_dialogs.dart)
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

Result:
- settings-side password, passphrase, and destructive confirmation prompts now route through one shared helper
- the helper remains intentionally narrow:
  - text input
  - secret/password input
  - destructive confirmation
- richer domain dialogs remain out of scope

Next executable batch:
- `Task 14.15`: adopt the shared prompt helper in `WslUiAdapter`

## Task 14.15: adopt the shared prompt helper in `WslUiAdapter`
Status: completed

Goal:
- move the WSL rename prompt onto the shared text-input helper without growing the helper API

What landed:
- [wsl_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/wsl_ui_adapter.dart)

Result:
- WSL tab rename now uses the shared text prompt helper
- the helper API did not need to grow for this adoption
- the next best adopters are still the generic text-input adapters:
  - `DockerOverviewUiAdapter`
  - `ExplorerUiAdapter`

Next executable batch:
- `Task 14.16`: adopt the shared prompt helper in `DockerOverviewUiAdapter`

## Task 14.16: adopt the shared prompt helper in `DockerOverviewUiAdapter`
Status: completed

Goal:
- move the docker overview text-input prompt onto the shared helper without turning the helper into a docker-specific API

What landed:
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)

Result:
- Docker overview text input now uses the shared prompt helper
- hint text and initial value fit the existing helper shape cleanly
- the next remaining generic text-input adopter is `ExplorerUiAdapter`

Next executable batch:
- `Task 14.17`: adopt the shared prompt helper in `ExplorerUiAdapter`

## Task 14.17: adopt the shared prompt helper in `ExplorerUiAdapter`
Status: completed

Goal:
- move the explorer adapter's small prompt flows onto the shared helper without pulling richer explorer dialogs into it

What landed:
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)

Result:
- explorer generic text input now uses the shared text prompt helper
- explorer multi-delete confirmation now uses the shared confirm prompt helper
- rename, move, delete, navigate, and merge-conflict dialogs remain on their explorer-specific builder path

Next executable batch:
- re-scope whether the dialog/settings hotspot should:
  - checkpoint here
  - or continue into `ExplorerDialogBuilders`
