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
