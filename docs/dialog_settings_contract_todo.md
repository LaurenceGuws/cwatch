# Dialog Settings Contract TODO

Status: active
Purpose: define the canonical shared dialog/settings scaffolding surface so prompt/confirm/input flows stop drifting across adapters and feature-local helpers.

## Why This Exists

The next integration-smell hotspot is shared dialog/settings scaffolding.

This is the right next target because:
- a shared dialog substrate already exists
- several dialog flows are already partly centralized
- the remaining duplication is visible and bounded
- this surface is smaller and safer to normalize than the broader explorer subsystem

## Current Shared Surface

Current shared dialog/settings building blocks:
- [dialog_keyboard_shortcuts.dart](/home/home/personal/cwatch/lib/view/shared/widgets/dialog_keyboard_shortcuts.dart)
- [explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart)
- [port_forward_dialog.dart](/home/home/personal/cwatch/lib/view/shared/widgets/port_forward_dialog.dart)
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

This means the problem is not absence of shared dialog code.

The problem is contract ambiguity:
- which prompt/confirm/input flows should be canonical shared scaffolding
- which flows are still valid feature-local exceptions
- where adapters should call a shared helper instead of hand-assembling their own dialog

## Current Integration Smells In This Hotspot

### 1. Shared dialog behavior exists, but prompt patterns are still duplicated

The codebase already shares:
- Enter/Escape shortcut behavior
- some explorer dialog builders
- a complex shared port-forward dialog

But multiple adapters still hand-assemble similar prompt flows:
- password prompts
- passphrase prompts
- destructive confirms
- generic text input dialogs

### 2. Settings-side prompt flows are acting like a mini dialog subsystem

[settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart) currently owns:
- password prompt
- passphrase prompt
- destructive key-delete confirmation

Those are valid flows, but they strongly suggest a reusable shared prompt layer rather than a settings-only local pattern.

### 3. Explorer has a clearer builder surface than settings does

[explorer_dialog_builders.dart](/home/home/personal/cwatch/lib/view/shared/widgets/explorer_dialog_builders.dart) already behaves like a shared dialog catalog.

Settings prompt flows do not yet have the same explicit shared shape.

### 4. Some dialog flows are genuinely too specific to normalize yet

Examples:
- SSH auth dialogs in [ssh_auth_prompter.dart](/home/home/personal/cwatch/lib/controller/adapters/ssh_auth_prompter.dart)
- the full port-forward dialog
- merge-conflict dialogs

Those should remain out of the first batch unless the shared contract clearly reaches them.

## Canonical Shared Dialog/Settings Contract

### Shared responsibilities

The shared dialog/settings scaffolding should own:
- common keyboard shortcut behavior for dialog confirm/cancel
- common prompt patterns:
  - text input
  - secret/password input
  - destructive confirmation
- common button ordering and dialog affordance rules
- common “empty/unavailable” breadcrumb messaging patterns when appropriate

### Feature or adapter responsibilities

Feature modules or adapters should own:
- domain wording
- domain validation rules
- domain-specific side effects after dialog completion
- complex domain-specific dialog bodies
- flows that include domain-specific async orchestration beyond simple prompting

### Allowed local exceptions

Local exceptions are valid when a dialog needs:
- a rich custom body
- domain-specific multi-step validation
- complex async lifecycle behavior
- substantially different interaction structure than a prompt/confirm dialog

Examples of valid exceptions:
- SSH auth/decrypt dialogs
- merge-conflict resolution
- port-forward matrix/table editing

## Best Current Next Cleanup Target

The smallest high-value normalization after this contract is:
- introduce a shared prompt helper/catalog for:
  - text input
  - password/passphrase input
  - destructive confirmation

Why this is next:
- it directly attacks duplicated adapter-side prompt assembly
- it leaves richer custom dialogs alone
- it gives adapters a canonical shared integration path without flattening domain logic

## Task 14.12
Status: completed

What this task established:
- the canonical shared dialog/settings responsibilities
- the adapter/feature-owned dialog responsibilities
- the valid exception list for richer domain-specific dialogs
- the next cleanup target: a shared prompt helper/catalog

Verification:
- this doc names the shared dialog/settings contract explicitly
- this doc distinguishes canonical prompt scaffolding from valid rich-dialog exceptions
- one concrete follow-up cleanup batch is chosen

## Task 14.13: scope shared prompt helper/catalog cleanup
Status: completed

Goal:
- define the smallest shared helper/catalog that absorbs duplicated prompt flows without overreaching into richer dialogs

Likely first target:
- settings-side prompt flows in `SettingsUiAdapter`

Likely scope:
- shared text input dialog helper
- shared secret/password prompt helper
- shared destructive confirm helper

Done definition:
- helper responsibilities are explicit
- first migration slice is chosen
- the next code batch is implementation-ready rather than exploratory

What landed:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Result:
- the first shared prompt helper should cover:
  - text input
  - secret/password input
  - destructive confirmation
- the first migration slice is `SettingsUiAdapter`

Next executable batch:
- `Task 14.14`: implement shared prompt helper for `SettingsUiAdapter`

## Task 14.14: implement shared prompt helper for SettingsUiAdapter
Status: completed

Goal:
- introduce the shared prompt helper/catalog and move the settings-side prompt flows onto it first

What landed:
- [shared_prompt_dialogs.dart](/home/home/personal/cwatch/lib/view/shared/widgets/shared_prompt_dialogs.dart)
- [settings_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/settings_ui_adapter.dart)

Result:
- settings-side password prompt uses the shared prompt helper
- settings-side key passphrase prompt uses the shared prompt helper
- settings-side destructive key-delete confirmation uses the shared prompt helper
- the shared helper stayed narrow enough to remain reusable for simpler follow-up adopters

Next executable batch:
- `Task 14.15`: adopt the shared prompt helper in `WslUiAdapter`

## Task 14.15: adopt the shared prompt helper in `WslUiAdapter`
Status: completed

Goal:
- prove the shared prompt helper on a simpler generic text-input adopter after the settings slice

What landed:
- [wsl_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/wsl_ui_adapter.dart)

Result:
- WSL rename prompt now uses the shared text-input helper
- the helper stayed narrow and did not need new knobs for this adopter

Next executable batch:
- `Task 14.16`: adopt the shared prompt helper in `DockerOverviewUiAdapter`

## Task 14.16: adopt the shared prompt helper in `DockerOverviewUiAdapter`
Status: completed

Goal:
- prove the shared text-input helper on a second generic adopter with initial-value and hint-text support

What landed:
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)

Result:
- Docker overview text input now routes through the shared prompt helper
- the helper already covered the needed shape without API growth

Next executable batch:
- `Task 14.17`: adopt the shared prompt helper in `ExplorerUiAdapter`

## Task 14.17: adopt the shared prompt helper in `ExplorerUiAdapter`
Status: completed

Goal:
- prove the shared prompt helper on the remaining simple explorer-side prompt flows while leaving richer explorer dialogs local

What landed:
- [explorer_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/explorer_ui_adapter.dart)

Result:
- explorer text input and multi-delete confirmation now route through the shared helper
- explorer-specific dialog builders remain intact for the richer file-operation flows

Next executable batch:
- re-scope whether the dialog/settings hotspot is ready for a checkpoint

## Task 14.18: re-scope the dialog/settings hotspot after `ExplorerUiAdapter`
Status: completed

Goal:
- decide whether this hotspot still needs another cleanup pass or is ready to checkpoint

Result:
- this hotspot is at a good checkpoint
- the canonical shared prompt path is now explicit and adopted where the fit is clean
- richer dialogs remain valid local exceptions and should not be flattened further in this pass

Checkpoint summary:
- shared prompt helper covers the small prompt/confirm cases
- `ExplorerDialogBuilders` remains local for richer explorer-specific dialog flows
- SSH auth, merge-conflict, and port-forward dialogs remain explicit exceptions

Next executable batch:
- choose the next integration-smell hotspot after dialog/settings scaffolding
