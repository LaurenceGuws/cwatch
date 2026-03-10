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

## Task 14.19: define the SSH auth ownership contract
Status: queued

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

## Explicit Concurrency Rules

These rules are now in scope for this hotspot:

1. Only one decrypt prompt per key at a time
2. Parallel callers for the same key must converge on the same unlock flow
3. Once the key is unlocked for the session, later parallel callers must observe that unlocked state instead of prompting again
4. High-level callers must not own prompt locking or decrypt-in-progress flags
5. The key store / builtin SSH auth subsystem should be the guard for key-unlock coordination
