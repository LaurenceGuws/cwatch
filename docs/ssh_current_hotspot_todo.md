# SSH Current Hotspot TODO

Status: checkpointed
Purpose: track the next bounded cleanup batches for the current highest-value remaining subsystem hotspot.

## Task 23.1: start the current SSH hotspot pass
Status: completed

Goal:
- treat SSH runtime simplification as the first active hotspot from the fresh current-state review
- keep this pass narrowly focused on what still smells now, not what already got cleaned up in the infrastructure boundary pass

Done definition:
- there is one SSH-only TODO for the new pass
- the first bounded SSH batch is named

Result:
- SSH is now the active current-state hotspot
- the first bounded batch should target the densest remaining runtime seam rather than reopening provider-selection or failure-vocabulary work

## Task 23.2: define the first bounded SSH batch
Status: completed

Goal:
- choose one concrete SSH cleanup slice with strong value and low ambiguity

Questions to answer:
- what in [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart) is true transport behavior vs runtime-orchestration smell
- whether the first batch should stay on process SSH or reopen builtin client complexity first
- whether the first batch should stay in runtime/session orchestration or move into file-operation helpers

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later SSH concerns remain queued instead of over-planned

## Queued Next Batches

These are intentionally not yet active:
- process SSH file-operation command assembly cleanup
- builtin client retry/prompt/runtime cleanup
- terminal session startup/lifecycle cleanup
- shell factory cache simplification

Result:
- the first bounded SSH batch is now:
  - process SSH run-result handling split
- target files:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - new SSH-local helper under `lib/model/services_infra/ssh/`
- stop condition:
  - repeated process-result success/failure/output normalization no longer lives inline across many `ProcessRemoteShellService` methods
  - provider selection, runtime failure mapping, and public `RemoteShellService` behavior stay stable in this batch
  - builtin SSH remains untouched in this batch

Why this is the right first cut:
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart) is now the densest remaining SSH file by far
- it still mixes many method-specific command flows with repeated process-run/result-handling patterns
- it gives a real subsystem simplification without reopening the already-cleaned provider/failure seams


## Task 23.3: implement the process SSH run-result handling split
Status: completed

Goal:
- extract the repeated process-run result handling pattern out of `ProcessRemoteShellService`

Done definition:
- one SSH-local helper owns run-result debug emission and exists-check verification shaping
- `ProcessRemoteShellService` no longer repeats the same result-to-debug/result-to-verification pattern inline across multiple methods
- focused regression coverage exists for the new helper


## Task 23.4: implement the process SSH file-operation command assembly split
Status: completed

Goal:
- extract repeated remote file-operation command planning out of `ProcessRemoteShellService`

Done definition:
- one SSH-local helper owns file-operation command assembly and path-derived directory planning
- `ProcessRemoteShellService` no longer owns inline file-operation shell command string construction across read/write/move/copy/delete/verification flows
- focused regression coverage exists for the new helper


## Task 23.5: implement the process SSH search-planning split
Status: completed

Goal:
- extract search predicate and find-command planning out of `ProcessRemoteShellService`

Done definition:
- one SSH-local helper owns search timeout policy, predicate building, prune-clause building, and path-pattern normalization for search flows
- `ProcessRemoteShellService` no longer owns inline search-pattern/predicate planning blocks
- focused regression coverage exists for the new helper


## Task 23.6: implement the process SSH terminal-session planning split
Status: completed

Goal:
- extract terminal-session launch planning and environment shaping out of `ProcessRemoteShellService`

Done definition:
- one SSH-local helper owns terminal session launch planning
- `ProcessRemoteShellService` no longer owns inline terminal executable/argument/environment branching
- focused regression coverage exists for the new helper


## Task 23.7: checkpoint the current SSH hotspot pass
Status: completed

Goal:
- stop the SSH pass at a real checkpoint instead of forcing another weak batch

Done definition:
- the SSH pass is explicitly checkpointed in the tracker
- the remaining SSH weight is described as legitimate provider/runtime glue rather than the same hotspot class we started with
- the broader current-state review reflects the next hotspot order

Result:
- the current SSH pass is checkpointed
- the strongest SSH smells addressed in this pass are now:
  - process run-result handling
  - process file-operation planning
  - process search planning
  - process terminal-session planning
- the remaining weight is mostly builtin runtime glue and shell-factory/runtime caching behavior, which is lower-value than the next repo-level hotspot

## Task 23.8: resume the SSH hotspot for builtin runtime cleanup
Status: completed

Goal:
- reopen the SSH pass only for the still-dense builtin runtime glue

Done definition:
- the next builtin-side batch is explicit
- the pass stays focused on builtin runtime behavior rather than reopening provider-selection or process-side work

Result:
- the resumed SSH pass now targets builtin runtime simplification
- the first builtin batches are:
  - auth challenge handling
  - client lifecycle
  - command preparation
  - timeout handling
  - retry/error-loop ownership

## Task 23.9: implement builtin retry/error-loop cleanup
Status: completed

Goal:
- extract builtin auth-retry and outward failure-mapping policy out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns retry handling for:
  - decrypt-required
  - built-in key passphrase
  - identity passphrase
- `BuiltInSshClientManager` no longer owns the retry loop inline
- focused regression coverage exists for the new helper

Result:
- builtin retry/error-loop policy now lives in a dedicated helper
- `BuiltInSshClientManager` is further narrowed toward workflow orchestration


## Task 23.10: implement builtin streaming-output cleanup
Status: completed

Goal:
- extract UTF-8 line buffering and trailing-remainder flush behavior out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns streaming output collection and line emission
- `BuiltInSshClientManager.runCommandStreaming(...)` no longer owns inline stream chunk/remainder parsing
- focused regression coverage exists for the new helper

Result:
- builtin streaming output collection now lives in a dedicated helper
- `BuiltInSshClientManager` is further narrowed toward session workflow orchestration


## Task 23.11: implement builtin client-connection cleanup
Status: completed

Goal:
- extract builtin client connection setup and host-key verification wiring out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns:
  - username resolution
  - identity precondition check
  - client open/connect wiring
  - host-label and fingerprint formatting
  - host-key verification callback shaping
- `BuiltInSshClientManager` no longer owns `_openClient(...)` inline
- focused regression coverage exists for the new helper

Result:
- builtin client connection setup now lives in a dedicated helper
- `BuiltInSshClientManager` is further narrowed toward command/session workflow orchestration


## Task 23.12: implement builtin plain-command execution cleanup
Status: completed

Goal:
- extract the plain builtin command execution workflow out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns:
  - command execution through `SSHClient.run(...)`
  - timeout wrapping
  - client kill-on-timeout behavior
  - output decoding and completion logging
- `BuiltInSshClientManager.runCommand(...)` no longer owns that inline workflow
- focused regression coverage exists for the new helper

Result:
- plain builtin command execution now lives in a dedicated helper
- `BuiltInSshClientManager` is further narrowed toward the remaining streaming and SFTP execution branches


## Task 23.13: implement builtin SFTP execution cleanup
Status: completed

Goal:
- extract the builtin SFTP timeout/cleanup workflow out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns:
  - `client.sftp()` acquisition
  - timeout wrapping for SFTP actions
  - client/SFTP kill-on-timeout behavior
  - guaranteed SFTP cleanup on exit
- `BuiltInSshClientManager.withSftp(...)` no longer owns that inline workflow
- focused regression coverage exists for the new helper

Result:
- builtin SFTP execution now lives in a dedicated helper
- `BuiltInSshClientManager` is further narrowed toward the remaining streaming execution branch


## Task 23.14: implement builtin streaming execution cleanup
Status: completed

Goal:
- extract the builtin streaming command workflow out of `BuiltInSshClientManager`

Done definition:
- one builtin-local helper owns:
  - session creation for streaming commands
  - cancellation wiring
  - stdout/stderr collection orchestration
  - timeout wrapping for the streaming session
- session/client kill-on-timeout behavior
- final stdout result shaping
- `BuiltInSshClientManager.runCommandStreaming(...)` no longer owns that inline workflow
- focused regression coverage exists for the new helper

## Task 23.15: define the SSH shell-factory simplification batch
Status: completed

Goal:
- choose the first bounded batch for the reopened SSH factory/runtime-cache hotspot
- keep the batch on low-payoff indirection removal rather than broader runtime behavior changes

Done definition:
- one explicit shell-factory batch is named
- the stop condition reflects the current over-engineered factory shape

Result:
- the next bounded SSH batch is now:
  - collapse selector/request indirection into `SshShellFactory`
- target files:
  - [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
  - [ssh_shell_provider_selector.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_provider_selector.dart)
  - [ssh_shell_provider_request.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_provider_request.dart)
  - [ssh_shell_factory_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/ssh_shell_factory_binding.dart)
- stop condition:
  - factory cache and provider-selection logic are understandable from the factory itself
  - request/selector wrappers are removed if they are not shared beyond the factory
  - behavior and cache invalidation stay stable

Why this is the right next cut:
- the actual selection behavior is tiny
- the request and selector types do not currently provide meaningful reuse outside the factory
- the binding is also a one-off constructor wrapper, so this batch removes real indirection without reopening SSH runtime behavior

## Task 23.15: re-scope the next SSH batch from the current code state
Status: completed

Goal:
- choose the next real SSH cleanup slice from the current code state after the builtin/runtime pass
- avoid blindly continuing older shell-factory assumptions if the hotspot shifted

Done definition:
- one new SSH batch is explicit
- the batch reflects the current file-state rather than the earlier pass ordering

Result:
- the next bounded SSH batch is now:
  - process SSH execution-adapter split
- target files:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - new SSH-local helper under `lib/model/services_infra/ssh/`
- stop condition:
  - repeated runner/failure-mapping wrappers no longer live inline in `ProcessRemoteShellService`
  - command planning, provider selection, and public `RemoteShellService` behavior stay stable in this batch
  - builtin SSH remains untouched in this batch

Why this is the right next cut:
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart) is now the densest remaining SSH file
- the remaining repeated `_runSsh` / `_runHostCommand` / `_runProcess` wrappers are real runtime-orchestration smell
- it gives a direct seam for focused regression coverage without reopening already-cleaned planners

## Task 23.16: implement the process SSH execution-adapter split
Status: completed

Goal:
- extract repeated process-runner and failure-mapping wrappers out of `ProcessRemoteShellService`

Done definition:
- one SSH-local helper owns process SSH runner delegation and failure/cancellation mapping
- `ProcessRemoteShellService` no longer owns repeated runner/failure wrapper methods inline
- focused regression coverage exists for ssh/host/process mapping and streaming-cancellation behavior

## Task 23.17: define the next SSH batch from the current process runtime shape
Status: completed

Goal:
- choose the next real SSH cleanup slice from the current code state after the execution-adapter split
- keep the batch on repeated process-transfer support logic rather than broader method rewrites

Done definition:
- one new SSH batch is explicit
- the batch reflects the current file shape instead of older assumptions

Result:
- the next bounded SSH batch is now:
  - process SSH transfer-support split
- target files:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - new SSH-local helper under `lib/model/services_infra/ssh/`
- stop condition:
  - SCP argument assembly and remote-spec formatting no longer live inline in `ProcessRemoteShellService`
  - file-operation behavior and public `RemoteShellService` contracts stay stable in this batch
  - builtin SSH remains untouched in this batch

Why this is the right next cut:
- `ProcessRemoteShellService` still owns a small but repeated transfer-support block at the bottom of the file
- that support logic is orthogonal to the higher-level SSH operation flows
- it gives a direct seam for focused regression coverage without forcing weaker method-by-method splits

## Task 23.18: implement the process SSH transfer-support split
Status: completed

Goal:
- extract process SSH SCP argument assembly and remote-spec formatting into a dedicated SSH-local helper

Done definition:
- one SSH-local helper owns SCP argument assembly and remote-spec shaping
- `ProcessRemoteShellService` no longer owns that transfer-support block inline
- focused regression coverage exists for SCP flags/identity shaping and remote-spec formatting

## Task 23.19: define the next SSH batch from the current process support shape
Status: completed

Goal:
- choose the next real SSH cleanup slice from the current code state after the transfer-support split
- keep the batch on repeated directory/verification support rather than broader method rewrites

Done definition:
- one new SSH batch is explicit
- the batch reflects the current file shape instead of older assumptions

Result:
- the next bounded SSH batch is now:
  - process SSH path-support split
- target files:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - new SSH-local helper under `lib/model/services_infra/ssh/`
- stop condition:
  - remote-directory creation support and debug exists-check verification no longer live inline in `ProcessRemoteShellService`
  - file-operation behavior and public `RemoteShellService` contracts stay stable in this batch
  - builtin SSH remains untouched in this batch

Why this is the right next cut:
- `ProcessRemoteShellService` still carries a small repeated support block for mkdir and debug verification flows
- that support logic is orthogonal to the higher-level SSH operations that call it
- it gives a direct seam for focused regression coverage without forcing weaker flow-by-flow splits

## Task 23.20: implement the process SSH path-support split
Status: completed

Goal:
- extract process SSH remote-directory creation and exists-check verification support into a dedicated SSH-local helper

Done definition:
- one SSH-local helper owns remote-directory creation and debug exists-check verification shaping
- `ProcessRemoteShellService` no longer owns that path-support block inline
- focused regression coverage exists for empty-directory skip, mkdir command shaping, and debug verification behavior

## Task 23.21: define the next SSH batch from the current process command-support shape
Status: completed

Goal:
- choose the next real SSH cleanup slice from the current code state after the path-support split
- keep the batch on repeated command/logging/output support rather than broad flow rewrites

Done definition:
- one new SSH batch is explicit
- the batch reflects the current file shape instead of older assumptions

Result:
- the next bounded SSH batch is now:
  - process SSH command-support split
- target files:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - new SSH-local helper under `lib/model/services_infra/ssh/`
- stop condition:
  - repeated command start/complete logging and command-output emission no longer live inline in `ProcessRemoteShellService`
  - public `RemoteShellService` behavior stays stable in this batch
  - builtin SSH remains untouched in this batch

Why this is the right next cut:
- `ProcessRemoteShellService` still repeats the same logging/output support around list, home, and plain command flows
- that support logic is orthogonal to the higher-level SSH operations that call it
- it gives a direct seam for focused regression coverage without forcing weaker flow-by-flow splits

## Task 23.22: implement the process SSH command-support split
Status: completed

Goal:
- extract process SSH command logging and output-emission support into a dedicated SSH-local helper

Done definition:
- one SSH-local helper owns command start/complete logging, structured failure logging, and result-handler output emission for process-side command flows
- `ProcessRemoteShellService` no longer owns that command-support block inline
- focused regression coverage exists for output emission and structured failure logging

Result:
- builtin streaming execution now lives in a dedicated helper
- `BuiltInSshClientManager` is reduced to thin workflow wrappers around extracted builtin helpers


## Task 23.15: checkpoint the resumed builtin SSH pass
Status: completed

Goal:
- stop the resumed builtin SSH pass at a real checkpoint instead of forcing smaller and smaller extractions

Done definition:
- the SSH tracker explicitly marks the resumed builtin pass as checkpointed
- the remaining SSH weight is described as shell-factory/runtime-cache glue rather than inline builtin workflow bulk
- the broader current-state review is aligned with the new state

Result:
- builtin workflow bulk has been materially reduced through dedicated helpers for:
  - auth challenge handling
  - lifecycle
  - command preparation
  - timeout handling
  - retry/error policy
  - stream output collection
  - client connection setup
  - plain command execution
  - SFTP execution
  - streaming execution
- the remaining SSH hotspot is now the shell-factory/runtime-cache seam, not the old builtin manager knot

## Task 23.23: checkpoint the current SSH runtime state
Status: completed

Goal:
- stop the current SSH pass at the present value boundary instead of forcing another low-value process-side micro-split

Done definition:
- the SSH tracker explicitly records the current checkpoint from the latest process-side state
- the remaining SSH weight is described from the current code shape rather than from older hotspot assumptions
- any future SSH reopening is left evidence-driven

Result:
- the current SSH runtime pass is checkpointed again from the latest code state
- recent process-side batches removed the strongest remaining support-glue repetition from:
  - execution wrapping
  - transfer argument and remote-spec shaping
  - remote path preparation and verification support
  - command logging and output emission support
- [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart) remains the largest SSH file, but its remaining weight is now mostly operation-specific behavior and transport workflow hosting
- the next SSH reopen should come only from fresh evidence in:
  - [process_ssh_shell_service.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/process_ssh_shell_service.dart)
  - [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
  - builtin/process coordination semantics

## Task 23.24: define the SSH shell-factory cache-clarity batch
Status: completed

Goal:
- tighten the remaining runtime-cache ownership inside `SshShellFactory`
- keep the batch on cache-state clarity, not on changing shell behavior or call sites

Done definition:
- one explicit cache-shape batch is named
- the stop condition reflects the current shared-signature ambiguity

Result:
- the next bounded SSH batch is now:
  - split builtin/process/default-timeout cache signatures inside `SshShellFactory`
- target files:
  - [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
  - [ssh_shell_factory_test.dart](/home/home/personal/cwatch/test/model/services_infra/ssh/ssh_shell_factory_test.dart)
- stop condition:
  - builtin, process, and timeout runtimes do not share one overloaded cache-signature field
  - settings-change invalidation remains explicit and behavior stays stable
  - focused regression coverage still proves cache reuse and reset behavior

Why this is the right next cut:
- the selector/request indirection is gone, so the remaining factory smell is now local cache-state ambiguity
- one shared signature field still represents multiple runtime caches
- making cache ownership explicit improves readability without inventing another abstraction layer

## Task 23.25: checkpoint the SSH shell-factory hotspot
Status: completed

Goal:
- record that the current SSH factory/runtime-cache pass removed the main over-indirection seam from the current code state
- stop here before forcing smaller speculative SSH cleanups

Done definition:
- this TODO is checkpointed from the current code state
- completed SSH factory/cache work is recorded as enforced baseline
- the remaining SSH weight is described accurately

Result:
- SSH shell-provider indirection is removed from:
  - [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
  - [ssh_shell_provider_selector.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_provider_selector.dart)
  - [ssh_shell_provider_request.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_provider_request.dart)
  - [ssh_shell_factory_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/ssh_shell_factory_binding.dart)
- SSH factory cache ownership is now explicit inside:
  - [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart)
- focused regression coverage still exists in:
  - [ssh_shell_factory_test.dart](/home/home/personal/cwatch/test/model/services_infra/ssh/ssh_shell_factory_test.dart)
  - [server_workspace_shell_test.dart](/home/home/personal/cwatch/test/view/features/servers/server_workspace_shell_test.dart)

What remains:
- [ssh_shell_factory.dart](/home/home/personal/cwatch/lib/model/services_infra/ssh/ssh_shell_factory.dart) still hosts valid runtime selection and cache reuse behavior
- broader SSH runtime behavior is now mostly acceptable builtin/process hosting glue or operation-specific transport behavior, not the same over-engineering hotspot

Checkpoint rule:
- future SSH work should reopen from fresh evidence in runtime behavior or feature integration, not from the older shell-factory indirection hotspot
