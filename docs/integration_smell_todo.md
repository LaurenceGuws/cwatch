# Integration Smell TODO

Status: active
Purpose: turn the integration-smell cleanup into a tracked workstream with one concrete current batch and looser queued hotspots after it.

## Working Rules

- do not try to redesign every shell/shared surface at once
- document canonical shared elements before replacing local variants
- explicit override beats accidental fork
- annotations/codegen should start only from stable metadata, not active runtime behavior

## Current Best Entry Point

The first useful batch is:
- map the current shell/shared subsystem surfaces
- identify obvious local re-creations and shadowed shared elements
- focus on the highest-signal hotspots:
  - tab chip / tab shell surfaces
  - explorer shared surfaces
  - reusable dialogs, lists, context menus, and settings scaffolding

Why this is first:
- the repo now has enough structural cleanup that the integration layer is visible
- polishing the shell requires knowing which surfaces are actually canonical
- metadata/codegen decisions would be premature until the shared subsystem map exists

## Task 14.1: define the shell/shared subsystem map
Status: completed

Goal:
- make the shared shell subsystem visible as a system instead of a loose set of widgets/helpers

Current files in scope:
- `README.md`
- `docs/rewrite_foundations.md`
- `docs/integration_smell_foundations.md`
- representative shell/shared UI hotspots such as:
  - `lib/view/shared/views/shared/tabs/tab_chip.dart`
  - `lib/view/shared/views/shared/tabs/file_explorer/`
  - `lib/view/shared/widgets/`
  - `lib/view/core/tabs/`
  - `lib/view/core/navigation/`

Actions:
- define the main shell/shared UI subsystems
- record which surfaces are currently canonical, partial, or ambiguous
- record where features appear to re-create or shadow shared behavior
- identify the smallest first normalization hotspot after the map exists

Done definition:
- the shell/shared subsystem list exists in writing
- the doc names the most obvious duplicate/replacement hotspots
- one concrete next hotspot is chosen from evidence, not intuition

Verification:
- this doc contains a subsystem map section
- this doc contains a queued hotspot list
- the next task is actionable and narrower than “polish everything”

## Subsystem Map

### 1. Workspace and tab shell
Current scope:
- tab host
- tab host controller
- tabbed workspace controller
- tab chip and tab options

Current status:
- partially canonical
- ownership is much cleaner than before
- still needs an explicit shared-surface contract so features stop re-creating tab-adjacent behavior casually

### 2. Explorer shared surface
Current scope:
- file explorer tab
- explorer selection/input helpers
- explorer dialogs
- drag/drop helpers
- path/state helpers

Current status:
- much cleaner after dependency cleanup
- still a hotspot because explorer mixes reusable shell/file tooling with feature-specific behavior expectations

### 3. Shared dialog and input surface
Current scope:
- dialog keyboard shortcuts
- port-forward dialog
- explorer dialog builders
- shared text/password/confirm dialog patterns

Current status:
- high-value shared subsystem
- now has initial regression coverage
- still lacks a canonical catalog and explicit reuse/override rules

### 4. Shared list/menu/settings scaffolding
Current scope:
- generic lists and tables
- popup/context menu helpers
- settings section scaffolding
- shared settings dialog helpers

Current status:
- likely canonical in intent
- not yet documented as a visible subsystem
- likely contains shadowed feature-local variants

## Queued Hotspots

### Hotspot A: tab chip and tab shell integration
Why it matters:
- tab chip and related tab shell surfaces are part of the shell identity
- feature-local tab behavior tends to drift here first

Queued question:
- what belongs in the canonical tab shell surface vs feature-local tab decoration/action behavior

### Hotspot B: explorer reuse vs local specialization
Status: active
Why it matters:
- explorer is one of the richest shared surfaces in the app
- it is easy to re-create small explorer-adjacent widgets/helpers instead of extending the shared surface

Current result:
- the explorer shared-surface contract is now explicit
- canonical shared explorer behavior is separated from valid explorer-local dialogs and interaction exceptions

Current follow-up:
- [explorer_shared_surface_todo.md](/home/home/personal/cwatch/docs/explorer_shared_surface_todo.md)
- next executable batch: `Task 14.28` explorer chrome/helper cleanup

### Hotspot C: shared dialog/settings scaffolding
Why it matters:
- these are highly reusable and now partly test-covered
- they are good candidates for explicit integration rules and later metadata

Queued question:
- which shared dialog/input/settings helpers should become required defaults and which are only convenience helpers

### Hotspot D: annotation/codegen candidate selection
Why it matters:
- annotations can help reduce integration glue, but only if we start at the right seam

Queued question:
- which stable metadata target comes first:
  - config/schema fields
  - command/menu registrations
  - tab descriptors
  - capability declarations

## Next Re-scope

### Task 14.2: choose the first normalization hotspot
Status: completed

Goal:
- pick one subsystem hotspot to normalize after the shell/shared map is explicit

Likely candidates:
- tab chip / tab shell contract
- explorer shared-surface contract
- shared dialog/settings helper catalog

Done definition:
- one hotspot is selected
- the next batch is a real cleanup target, not another broad survey

Result:
- the first normalization hotspot is `tab chip / tab shell contract`

Why this wins over the other candidates:
- it is the clearest shell-identity surface
- it sits above multiple feature modules instead of one subsystem path
- it is where accidental tab-adjacent re-creation will become visible first
- polishing the shell without clarifying the tab shell contract would risk cosmetic cleanup over an unstable integration boundary

Why the other candidates wait:
- `explorer shared-surface contract`
  - still important, but richer and broader; better taken after the shell tab contract is clearer
- `shared dialog/settings helper catalog`
  - useful, but less central to shell identity than the tab shell itself

What this hotspot should answer next:
- what is the canonical tab shell surface
- what tab chip behavior is mandatory shared behavior
- what tab-level actions remain feature-owned
- what visual/interaction overrides are acceptable local exceptions

### Task 14.3: define the tab chip / tab shell contract
Status: completed

Goal:
- turn the tab shell from a partially canonical widget set into an explicit shared subsystem contract

Current files in scope:
- `lib/view/shared/views/shared/tabs/tab_chip.dart`
- `lib/controller/core/workspace/tab_options.dart`
- `lib/controller/core/workspace/workspace_tab.dart`
- `lib/controller/core/workspace/tab_host_controller.dart`
- `lib/view/core/tabs/`
- representative feature tab call sites in:
  - `lib/view/features/docker/`
  - `lib/view/features/servers/`
  - `lib/view/features/kubernetes/`
  - `lib/view/features/wsl/`

Actions:
- define the canonical responsibilities of the shared tab shell
- separate mandatory shared tab behavior from feature-owned tab metadata/actions
- record where local feature tab behavior is an allowed override vs a cleanup smell
- identify the first concrete normalization pass after the contract is written

Done definition:
- the tab shell contract exists in writing
- explicit override rules exist for tab-level behavior and presentation
- one concrete follow-up cleanup batch is chosen from that contract

What landed:
- [tab_shell_contract_todo.md](/home/home/personal/cwatch/docs/tab_shell_contract_todo.md)

Result:
- the canonical shared tab shell responsibilities are now explicit
- feature-owned tab metadata and override responsibilities are now explicit
- the main repeated integration smell is identified:
  - feature-local `WorkspaceTab -> TabChip` assembly
  - duplicated generic tab command wiring

Next executable batch:
- `Task 14.4`: scope shared tab-shell adapter cleanup

### Task 14.4: scope shared tab-shell adapter cleanup
Status: completed

What this task established:
- the first normalization batch should target a shared tab-shell adapter/helper
- that helper should absorb repeated routine chip assembly and generic tab command contribution
- feature modules should keep only the truly local tab inputs:
  - host mapping
  - close warnings
  - picker restrictions
  - extra tab options
  - extra command entries

Why this is the right next batch:
- it directly attacks the repeated feature-level integration smell we just documented
- it is narrower than redesigning the tab model or shell
- it gives shell polish one canonical tab integration path

Current follow-up doc:
- [tab_shell_contract_todo.md](/home/home/personal/cwatch/docs/tab_shell_contract_todo.md)

Next executable batch:
- `Task 14.5`: add shared tab-shell adapter TODO

### Task 14.5: add shared tab-shell adapter TODO
Status: completed

What this task established:
- the shared tab-shell helper should be split into:
  - chip-building
  - generic tab-command contribution
- WSL is the right proving slice
- migration order should be:
  - WSL
  - Kubernetes
  - Docker
  - Servers

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next executable batch:
- `Task 14.6`: implement the shared tab-shell adapter for WSL

### Task 14.6: implement the shared tab-shell adapter for WSL
Status: completed

What this task established:
- the shared chip-building helper works as a narrow first implementation slice
- WSL no longer hand-assembles routine `TabChip` wiring
- the adapter can stay focused on shared shell behavior without prematurely absorbing feature runtime logic

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next executable batch:
- `Task 14.7`: adopt the shared chip builder in Kubernetes

### Task 14.7: adopt the shared chip builder in Kubernetes
Status: completed

What this task established:
- the shared chip-building helper also works for the routine options-controller case
- Kubernetes no longer hand-assembles routine `TabChip` wiring

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next executable batch:
- `Task 14.8`: adopt the shared chip builder in Docker

### Task 14.8: adopt the shared chip builder in Docker
Status: completed

What this task established:
- the shared chip-building helper also works for picker restrictions, close warnings, and picker-only extra options
- Docker no longer hand-assembles routine `TabChip` wiring

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next executable batch:
- `Task 14.9`: adopt the shared chip builder in Servers

### Task 14.9: adopt the shared chip builder in Servers
Status: completed

What this task established:
- the shared chip-building helper also works for the heaviest current case
- Servers no longer hand-assemble routine `TabChip` wiring
- the first chip-building normalization pass is now complete across the main tabbed modules

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next executable batch:
- re-scope whether the next tab-shell normalization should target generic tab command contribution or stop the hotspot at this checkpoint

### Task 14.10: checkpoint the tab-shell hotspot
Status: completed

What this task established:
- the first chip-building normalization pass is enough to checkpoint the hotspot
- the remaining duplication in generic tab command contribution is real, but no longer urgent enough to block moving to the next shared subsystem

Why this is the right pause point:
- the shared shell’s most visible tab chrome now has a canonical integration path
- continuing immediately into command-palette helpers would risk merging two subsystems:
  - tab shell
  - command system
- the next pass should be chosen deliberately instead of turning this hotspot into an endless drain

Current follow-up doc:
- [tab_shell_adapter_todo.md](/home/home/personal/cwatch/docs/tab_shell_adapter_todo.md)

Next best direction:
- move to the next integration-smell hotspot, likely:
  - explorer shared-surface contract
  - or shared dialog/settings scaffolding

### Task 14.11: choose the next integration-smell hotspot after tab shell
Status: completed

What this task checked:
- whether the next shared subsystem should be:
  - explorer shared-surface contract
  - shared dialog/settings scaffolding

Result:
- the next hotspot is `shared dialog/settings scaffolding`

Why this wins:
- it is already partly centralized through:
  - `DialogKeyboardShortcuts`
  - `ExplorerDialogBuilders`
  - `SettingsUiAdapter`
  - `port_forward_dialog.dart`
- it already has initial regression coverage
- the remaining duplication is visible and bounded:
  - repeated text/password/confirm dialog patterns
  - repeated settings-side prompt flows
- it is narrower and safer than the full explorer surface, which is richer and more behavior-heavy

Why explorer waits:
- explorer is still an important hotspot
- but it mixes more interaction, list behavior, path/search behavior, and shell/file semantics
- it is a better next target after the dialog/settings surface is made more explicit

Next executable batch:
- `Task 14.12`: define the shared dialog/settings scaffolding contract

### Task 14.12: define the shared dialog/settings scaffolding contract
Status: completed

What this task established:
- the shared dialog/settings surface should cover canonical prompt scaffolding:
  - text input
  - password/passphrase input
  - destructive confirmation
- richer dialogs remain valid local exceptions:
  - SSH auth dialogs
  - merge-conflict dialogs
  - port-forward dialog

Current follow-up doc:
- [dialog_settings_contract_todo.md](/home/home/personal/cwatch/docs/dialog_settings_contract_todo.md)

Next executable batch:
- `Task 14.13`: scope shared prompt helper/catalog cleanup

### Task 14.13: scope shared prompt helper/catalog cleanup
Status: completed

What this task established:
- the first shared prompt helper should cover:
  - text input
  - secret/password input
  - destructive confirmation
- `SettingsUiAdapter` is the right proving slice
- richer dialogs remain intentionally out of scope

Current follow-up doc:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- `Task 14.14`: implement shared prompt helper for `SettingsUiAdapter`

### Task 14.14: implement shared prompt helper for `SettingsUiAdapter`
Status: completed

What this task established:
- a narrow shared prompt helper can absorb settings-side prompt assembly cleanly
- `SettingsUiAdapter` no longer behaves like a one-off local prompt subsystem
- the dialog/settings hotspot now has a concrete canonical prompt path for simple prompts

Current follow-up doc:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- `Task 14.15`: adopt the shared prompt helper in `WslUiAdapter`

### Task 14.15: adopt the shared prompt helper in `WslUiAdapter`
Status: completed

What this task established:
- the shared prompt helper also holds for a simple rename flow outside settings
- the helper can now be treated as the canonical shared path for straightforward one-field prompts
- no helper expansion was needed for this adoption

Current follow-up doc:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- `Task 14.16`: adopt the shared prompt helper in `DockerOverviewUiAdapter`

### Task 14.16: adopt the shared prompt helper in `DockerOverviewUiAdapter`
Status: completed

What this task established:
- the shared prompt helper also works for generic text input with `initialValue` and `hintText`
- the helper is holding as a general small-prompt path, not just a settings/rename helper

Current follow-up doc:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- `Task 14.17`: adopt the shared prompt helper in `ExplorerUiAdapter`

### Task 14.17: adopt the shared prompt helper in `ExplorerUiAdapter`
Status: completed

What this task established:
- the shared prompt helper now covers the remaining small explorer-side prompt flows cleanly
- the current boundary is clearer:
  - simple prompts use the shared helper
  - richer explorer dialogs stay on the explorer-specific builder path

Current follow-up doc:
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- re-scope whether the dialog/settings hotspot should checkpoint or continue into `ExplorerDialogBuilders`

### Task 14.18: re-scope the dialog/settings hotspot after `ExplorerUiAdapter`
Status: completed

What this task established:
- the dialog/settings hotspot is at a good checkpoint
- the canonical shared prompt path is now clear and adopted across the simple prompt cases
- continuing immediately into `ExplorerDialogBuilders` would start collapsing valid explorer-local behavior into generic infrastructure

Current follow-up docs:
- [dialog_settings_contract_todo.md](/home/home/personal/cwatch/docs/dialog_settings_contract_todo.md)
- [shared_prompt_helper_todo.md](/home/home/personal/cwatch/docs/shared_prompt_helper_todo.md)

Next executable batch:
- choose the next integration-smell hotspot after dialog/settings scaffolding

### Task 14.19: choose the next integration-smell hotspot after dialog/settings
Status: completed

What this task checked:
- whether to return to explorer shared-surface cleanup
- whether to jump to annotation/codegen candidate selection
- or whether a deeper subsystem-integration hotspot now has better value

Result:
- the next hotspot is `SSH auth ownership`

Why this wins:
- it is a real subsystem boundary problem, not just a missing shared widget/helper
- high-level feature layers still touch SSH auth wiring they should not know about
- the builtin SSH path already shows partial race-handling logic, which means the right next move is ownership cleanup, not more prompt reuse
- the user requirement is explicit:
  - high-level layers should not know auth state
  - only one prompt per key at a time
  - parallel callers should converge on the same unlock flow

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- `Task 14.20`: define the SSH auth ownership contract

### Task 14.20: define the SSH auth ownership contract
Status: completed

What this task established:
- `BuiltInSshClientManager` should be the canonical runtime owner of builtin SSH auth coordination
- `BuiltInSshIdentityManager` currently overlaps that concern and should stop owning prompt/decrypt coordination
- `TrashTabController` is a concrete example of the wrong ownership pattern and should move back onto the builtin SSH auth path
- high-level adapter/binding auth coordinator construction is still too high, but it is a later follow-up after builtin runtime ownership is singular

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- `Task 14.21`: scope builtin SSH auth consolidation

### Task 14.21: scope builtin SSH auth consolidation
Status: completed

What this task established:
- the first code batch should not start at server/docker adapter wiring
- the first code batch should remove duplicated builtin decrypt coordination at the actual subsystem boundary
- `BuiltInSshIdentityManager` and `TrashTabController` are the first cleanup targets around the canonical owner in `BuiltInSshClientManager`

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- `Task 14.22`: consolidate builtin decrypt coordination

### Task 14.22: consolidate builtin decrypt coordination
Status: completed

What this task established:
- builtin decrypt/prompt coordination no longer overlaps in `BuiltInSshIdentityManager`
- `TrashTabController` no longer reimplements builtin SSH auth state machines
- the builtin shell runtime is now the effective owner of trash-side auth retry behavior

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- `Task 14.23`: scope high-level SSH auth wiring removal

### Task 14.23: scope high-level SSH auth wiring removal
Status: completed

What this task established:
- the remaining high-level SSH auth wiring is now concentrated in server/docker port-forward flows
- the best next seam is not the home-shell global auth coordinator
- the best next seam is to remove `buildSshAuthCoordinator(...)` from server/docker UI adapters and push that wiring below the feature/UI layer

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- `Task 14.24`: remove high-level auth wiring from port-forward flows

### Task 14.24: remove high-level auth wiring from port-forward flows
Status: completed

What this task established:
- the concentrated server/docker port-forward auth-wiring smell is removed
- UI adapters no longer construct SSH auth coordinators for those flows
- service-level auth coordination is now the source for those paths

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- re-scope the remaining SSH auth wiring tail

### Task 14.25: re-scope the remaining SSH auth wiring tail
Status: completed

What this task established:
- the SSH auth hotspot is at a good checkpoint
- the remaining tail is mostly:
  - app-shell composition
  - compatibility parameter cleanup
  - lower-level infra API tightening
- those are real, but they are no longer the same high-value feature/integration smell we started from

Current follow-up doc:
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Next executable batch:
- choose the next integration-smell hotspot after SSH auth ownership

### Task 14.26: choose the next integration-smell hotspot after SSH auth
Status: completed

What this task checked:
- whether to return to explorer shared-surface cleanup
- whether to jump to annotation/codegen candidate selection
- whether to continue the SSH tail despite diminishing returns

Result:
- the next hotspot is `explorer shared surface`

Why this wins:
- explorer is still one of the largest shared shell/file surfaces in the app
- it has cleaner ownership now, but the shared/local contract is still implicit
- shell polish and reuse rules will keep drifting until explorer is made explicit

Why annotation/codegen waits:
- that is still better treated as a metadata-focused pass after the remaining large shared subsystem contracts are clearer

Current follow-up doc:
- [explorer_shared_surface_todo.md](/home/home/personal/cwatch/docs/explorer_shared_surface_todo.md)

Next executable batch:
- `Task 14.27`: define the explorer shared-surface contract
