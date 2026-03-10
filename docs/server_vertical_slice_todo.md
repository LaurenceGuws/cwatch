# Server Vertical Slice TODO

Status: active
Purpose: define the third true vertical slice after the explorer and Docker checkpoints, using the ownership, composition, settings, integration, and testing groundwork already landed around the server workspace.

## Why Servers Are Next

Servers are the strongest next slice because:
- major groundwork already exists around:
  - runtime graph extraction
  - shell/tab ownership cleanup
  - SSH auth ownership cleanup
  - shared shell integration cleanup
  - grouped SSH settings/config ownership
- `server_workspace_view.dart` still carries one of the heaviest mixed seams in the repo:
  - host loading
  - availability refresh
  - placeholder/list hosting
  - command contribution
  - tab opening/replacement
  - settings-driven reload behavior
- it is the strongest next proof after Docker because it pushes the same architectural direction into a more infrastructure-heavy feature without jumping straight into a full SSH transport rewrite

## Scope Of This Slice

This slice is not:
- a full SSH infrastructure rewrite
- a server-feature redesign
- a generic remote-host workspace framework

This slice is:
- proving the next vertical-slice pass on a feature with heavier runtime and host/workspace lifecycle behavior than Docker
- reducing ambiguity in `server_workspace_view.dart` and adjacent server workspace surfaces
- making server runtime, placeholder/list flow, and host-state ownership clearer end-to-end

## Current Architectural Starting Point

Relevant current files:
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
- [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
- [server_tab_builder.dart](/home/home/personal/cwatch/lib/view/features/servers/server_tab_builder.dart)
- [server_workspace_ui_adapter.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_ui_adapter.dart)
- [host_list.dart](/home/home/personal/cwatch/lib/view/features/servers/servers/host_list.dart)
- [ssh_auth_integration_todo.md](/home/home/personal/cwatch/docs/ssh_auth_integration_todo.md)

Current known truth:
- runtime ownership is materially cleaner than before
- SSH auth ownership is at a practical checkpoint
- tab shell and command contribution cleanup already reduced shell-level noise
- the main remaining architectural weight is still concentrated in `server_workspace_view.dart`

## Task 17.1: confirm Servers as the third vertical slice
Status: completed

Goal:
- choose the next true vertical slice after the Docker checkpoint from current rewrite evidence

Candidates considered:
- servers
- kubernetes

Result:
- Servers are the third vertical slice

Why this wins:
- it is the heaviest remaining feature shell with enough groundwork already in place to make a focused slice viable
- it tests the architecture against host loading and SSH-adjacent flows without requiring immediate infrastructure boundary surgery

## Task 17.2: define the Server target slice boundary
Status: queued

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in the current server runtime/service layer
- what should move out of `server_workspace_view.dart`
- what remains intentionally local to the server placeholder/list and host dashboard behavior in the first batch

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen
