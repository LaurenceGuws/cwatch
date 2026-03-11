# SSH Current Hotspot TODO

Status: active
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
