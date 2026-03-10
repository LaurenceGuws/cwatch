# SSH Auth Integration TODO

Status: active
Purpose: scope the next integration-smell hotspot: move SSH auth coordination, key-unlock state, and prompt gating down into the SSH API layer so feature/runtime callers stop owning auth flow details.

## Why This Exists

The current shared prompt-helper hotspot is at a good checkpoint.

The next integration issue is not generic dialog reuse.

It is SSH auth ownership:
- high-level layers still construct auth coordinators
- some high-level controllers still own decrypt/passphrase retry flow directly
- the builtin SSH path already has lower-layer retry hooks, but ownership is split across multiple places
- parallel callers can converge on the same key-unlock work, and the race handling is only partially centralized today

This is exactly the kind of integration smell that keeps high-level layers coupled to subsystem state they should not know about.

## Target Rule

High-level callers such as:
- server workspace
- docker remote scanning
- distro probing
- port-forward flows

should not know:
- whether a built-in key is decrypted
- whether a prompt is already open
- how passphrase retry is coordinated
- how key-store unlock state is cached or shared

They should only observe:
- operation succeeded
- operation failed
- capability unavailable / auth cancelled / auth failed

The SSH API layer should own:
- decrypt-needed detection
- passphrase-needed detection
- prompt gating
- per-key unlock coordination
- reuse of unlocked state across concurrent requests

## Current Integration Smells

### 1. Auth coordinator construction still happens in high-level UI adapters

Current examples:
- [server_workspace_ui_adapter.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_ui_adapter.dart)
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)

Those surfaces still expose `buildSshAuthCoordinator(...)`.

That means the server/docker feature layers still participate in wiring auth state behavior instead of just consuming SSH operations.

### 2. Prompt coordination exists in more than one place

Current partial coordination:
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
  - `_pendingDecryptRequests`
- [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
  - `_pendingDecrypts`

This strongly suggests the same concern is being managed at multiple layers.

That is a smell because:
- the lock owner is ambiguous
- race handling is harder to reason about
- future fixes can easily land in the wrong layer

### 3. Some high-level controllers still run their own auth loop

Current example:
- [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart)

That controller still owns:
- decrypt-in-progress flags
- prompt serialization
- passphrase awaiting
- retry flow

That is the exact ownership pattern we want to remove from higher layers.

### 4. Key-store unlock state is not yet expressed as a clear subsystem contract

What should be explicit:
- only one decrypt prompt per key at a time
- once a key is unlocked for the session, concurrent callers should observe the unlocked state instead of re-prompting
- prompt coordination should be keyed by the auth target, not by whichever caller reached the race first

The code partially does this today, but not from one canonical place.

## Current Best Reading Of The Race Condition

There is already some race protection in the builtin path:
- `BuiltInSshClientManager._pendingDecryptRequests`
- `BuiltInSshIdentityManager._pendingDecrypts`

So this is not a greenfield problem.

The problem is:
- the same concern is guarded in more than one layer
- the ownership boundary is still wrong
- the high-level API still exposes auth wiring to feature code

That means the next pass should not start by adding more locks.

It should start by deciding which SSH layer is the canonical owner of:
- prompt serialization
- key unlock gating
- passphrase caching / reuse

## Desired Done State

When this hotspot is done:
- server/docker high-level layers do not build SSH auth coordinators
- feature controllers do not manage decrypt/prompt state directly
- the builtin SSH layer owns one canonical unlock/prompt coordination path
- concurrent requests for the same key do not create repeated decrypt prompts
- later callers observe unlocked session state instead of re-triggering the same auth flow
- CLI/system-provider paths remain free to degrade differently without forcing builtin auth concerns upward

## First Safe Batch

The first batch should be documentation and ownership scoping, not a blind auth refactor.

Why:
- there is already partial race handling in multiple places
- changing auth flow blindly risks subtle regressions in builtin SSH behavior
- the first useful step is to define the canonical owner and the first migration seam

## Task 14.20: define the SSH auth ownership contract
Status: completed

Goal:
- define exactly which SSH layer owns auth state, prompt gating, and unlock coordination

Files in scope:
- [ssh_auth_coordinator.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_auth_coordinator.dart)
- [ssh_auth_prompter.dart](/home/home/personal/cwatch/lib/controller/adapters/ssh_auth_prompter.dart)
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
- [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
- [builtin_ssh_vault.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_vault.dart)
- [server_workspace_ui_adapter.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_ui_adapter.dart)
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)
- [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart)

Done definition:
- the canonical owner of auth coordination is named
- duplicated/overlapping coordination points are identified
- one concrete first migration seam is chosen
- the user’s concurrency requirements are recorded as explicit rules

## Contract Result

### Canonical owner

The canonical owner of builtin SSH auth coordination should be:
- the builtin SSH auth/runtime layer rooted at:
  - [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
  - with state backing in the builtin key/vault subsystem

Not the owner:
- server/docker UI adapters
- feature controllers
- trash/explorer high-level flows
- feature bindings

### What this owner must control

The builtin SSH auth/runtime owner should control:
- decrypt-needed detection
- passphrase-needed detection
- per-key prompt gating
- per-key unlock coordination
- session reuse of unlocked keys
- passphrase reuse for the same auth target when valid

### What higher layers may still own

Higher layers may still own:
- how to surface final success/failure messages
- capability breadcrumbs
- feature-specific recovery messaging after an auth failure

They must not own:
- decrypt-in-progress flags
- passphrase prompt dedupe maps
- key unlock retry loops
- manual prompt serialization for builtin SSH

## Overlapping Coordination Points Found

### 1. Builtin client manager
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
  - `_pendingDecryptRequests`

This is the strongest candidate for the canonical runtime coordination owner because it already handles:
- auth exceptions
- decrypt-needed retry
- passphrase-needed retry
- auth coordinator callbacks

### 2. Builtin identity manager
- [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
  - `_pendingDecrypts`
  - `promptDecrypt`

This layer is too low to be the canonical owner of prompt coordination.

Why:
- it is an identity-loading layer
- it should not decide UI prompt serialization policy
- it should not own fallback prompting behavior once a higher builtin auth runtime exists

### 3. High-level controller-owned auth loop
- [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart)

This is explicitly wrong ownership.

Why:
- it duplicates decrypt and passphrase retry behavior outside the SSH subsystem
- it owns decrypt/prompt flags directly
- it re-creates auth-loop policy in a feature controller

### 4. High-level auth coordinator construction
- [server_workspace_ui_adapter.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_ui_adapter.dart)
- [docker_overview_ui_adapter.dart](/home/home/personal/cwatch/lib/controller/adapters/docker_overview_ui_adapter.dart)
- [home_shell_services_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/home_shell_services_binding.dart)

These surfaces still build `SshAuthCoordinator` via [ssh_auth_prompter.dart](/home/home/personal/cwatch/lib/controller/adapters/ssh_auth_prompter.dart).

That is better than feature controllers doing the auth loop themselves, but it still keeps auth wiring too high in the stack.

## First Migration Seam

The first migration seam should be:
- make `BuiltInSshClientManager` the single runtime owner of builtin auth coordination
- remove duplicated decrypt gating from `BuiltInSshIdentityManager`
- stop high-level controllers from owning builtin auth loops

This means the first code batch after this contract should target:
1. `BuiltInSshIdentityManager`
2. `BuiltInSshClientManager`
3. `TrashTabController`

Not first target:
- server/docker UI adapters

Why:
- until the builtin runtime owner is singular, moving adapter wiring alone would just hide the same ambiguity

## Specific Ownership Decisions

### Decision 1: `BuiltInSshClientManager` becomes the prompt-gating owner

Reason:
- it already sits at the retry boundary for SSH operations
- it already translates builtin auth exceptions into retryable auth flows
- it already has the stronger auth-context view

### Decision 2: `BuiltInSshIdentityManager` should stop owning prompt coordination

Reason:
- identity loading should prepare identities, not orchestrate prompt races
- its pending-decrypt map is overlapping state, not a distinct concern

### Decision 3: `TrashTabController` should consume builtin auth behavior, not reimplement it

Reason:
- the controller is currently compensating for missing subsystem ownership
- its decrypt/prompt state should collapse into the builtin SSH layer

### Decision 4: `SshAuthPrompter` is still a UI adapter, not the auth-state owner

Reason:
- the prompt widget layer can remain a UI adapter
- but it should feed a lower-layer auth subsystem owner rather than leave state policy spread upward

## Next Executable Batch

### Task 14.21: scope builtin SSH auth consolidation
Status: completed

Goal:
- define the smallest code batch that consolidates decrypt/prompt ownership into `BuiltInSshClientManager` without broad SSH API churn

Likely files in scope:
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
- [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
- [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart)

Done definition:
- the first consolidation slice is chosen
- duplicated coordination points to remove are named
- the batch is narrow enough to implement incrementally

## Result Of The Scope Pass

The first consolidation slice should be:

1. remove builtin prompt/decrypt coordination from [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
2. keep one canonical pending-decrypt path in [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
3. collapse [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart) onto that builtin auth path instead of letting it run a parallel auth loop

This is the right first slice because it removes the overlapping coordination where it is most obvious without requiring immediate churn in:
- server workspace adapter wiring
- docker overview adapter wiring
- `SshAuthPrompter`
- CLI/system-provider paths

## Why This Slice Is Narrow Enough

It avoids broad churn in these areas:
- `server_workspace_ui_adapter.dart`
- `docker_overview_ui_adapter.dart`
- `server_workspace_binding.dart`
- `docker_overview_actions_controller.dart`
- `port_forward_service.dart`

Those are real follow-ups, but they should come after builtin runtime ownership is singular.

## Duplicated Coordination To Remove First

### Remove from `BuiltInSshIdentityManager`
- `_pendingDecrypts`
- direct `promptDecrypt` ownership
- direct decrypt-prompt fallback in `ensureDecrypted(...)`
- direct decrypt-prompt fallback in `loadIdentities(...)`

Desired replacement:
- identity manager reports auth/decrypt state upward through builtin SSH exceptions
- client manager performs the retry/prompt coordination

### Remove from `TrashTabController`
- `_decryptInProgress`
- `_pendingPassphrasePrompts`
- `_withBuiltinDecrypt(...)`
- `_promptDecrypt(...)`
- `_awaitPassphraseInput(...)`
- controller-owned retry loop around builtin SSH auth exceptions

Desired replacement:
- the controller calls shell operations through the builtin SSH layer
- builtin SSH layer handles decrypt/passphrase coordination
- controller only surfaces final user-facing outcomes

## Keep For The First Slice

Keep for now:
- `SshAuthPrompter` as the UI prompt adapter
- `buildSshAuthCoordinator(...)` call sites in high-level UI adapters
- `withDecryptFallback(...)` compatibility paths where they are still used by non-builtin callers

Reason:
- those are not the source of the current duplicated lock ownership
- moving them first would hide the real builtin-runtime ambiguity rather than remove it

## First Code Batch After This Scope

### Task 14.22: consolidate builtin decrypt coordination
Status: queued

Goal:
- make `BuiltInSshClientManager` the only builtin decrypt/prompt coordination owner

Likely files in scope:
- [builtin_ssh_client_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_ssh_client_manager.dart)
- [builtin_identity_manager.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/builtin/builtin_identity_manager.dart)
- [trash_tab_controller.dart](/home/home/personal/cwatch/lib/controller/controllers/trash_tab_controller.dart)
- [trash_tab_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/trash_tab_binding.dart)

Done definition:
- builtin decrypt coordination exists in one place
- identity manager no longer owns overlapping pending-decrypt state
- trash tab no longer owns decrypt/prompt state machines
- concurrent requests for the same key still converge correctly

## Explicit Concurrency Rules

These rules are now in scope for this hotspot:

1. Only one decrypt prompt per key at a time
2. Parallel callers for the same key must converge on the same unlock flow
3. Once the key is unlocked for the session, later parallel callers must observe that unlocked state instead of prompting again
4. High-level callers must not own prompt locking or decrypt-in-progress flags
5. The key store / builtin SSH auth subsystem should be the guard for key-unlock coordination
