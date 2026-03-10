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
Status: completed

Goal:
- describe what this slice is allowed to change and what it should leave alone in the first pass

Questions to answer:
- what stays in the current server runtime/service layer
- what should move out of `server_workspace_view.dart`
- what remains intentionally local to the server placeholder/list and host dashboard behavior in the first batch

Done definition:
- the slice boundary is explicit
- one concrete first implementation batch is chosen

Result:
- the first Server slice boundary is now explicit

### What stays stable / out of scope for the first batch

These areas should stay stable in the first Server slice pass:
- `ServerWorkspaceRuntime`
- `ServerWorkspaceController`
- `ServerTabBuilder`
- `ServerWorkspaceUiAdapter`
- `host_list.dart`
- current SSH auth/runtime ownership shape
- current tab-builder action surfaces

Why they stay stable:
- runtime, auth, and shell integration groundwork is already good enough to build on
- changing host list internals or SSH transport behavior immediately would broaden the blast radius too early

### What stays intentionally local to Server behavior

These remain Server-local even after the first slice cut:
- host list UI behavior
- placeholder/list presentation
- host action choices
- server-specific tab opening flows
- server-specific settings wording and remediation

The goal is not to genericize remote-host dashboards or SSH workflows.

### What should move out of `server_workspace_view.dart` first

The first seam is top-level Server workspace orchestration around the host-list shell, not the host list widget or the tab builder internals themselves.

That means extracting the logic that currently coordinates:
- host loading kickoff and refresh
- custom-host signature/path/disabled-host reload decisions
- settings-driven host-list reload behavior
- top-level command-palette and tab-navigation registration
- placeholder-tab creation/start-empty-tab helpers
- workspace-level host selection/placeholder replacement coordination

This should become a narrower Server workspace shell seam, while host-list rendering and server tab-building stay local for now.

### Why this is the right first cut

- `server_workspace_view.dart` is still the main concentration point for mixed orchestration and rendering
- the most obvious reusable architectural seam is the server workspace shell around host loading, placeholder flow, and shell-level registrations
- it mirrors the same kind of top-level split that already proved useful in explorer and Docker
- it avoids prematurely splitting the denser host-list UI and server action logic

## Task 17.3: implement Server top-level workspace-shell split
Status: completed

Goal:
- extract top-level Server workspace orchestration out of `server_workspace_view.dart` while leaving host list and server tab builder behavior local for now

First code targets:
- host loading kickoff/refresh orchestration
- settings-driven host reload coordination
- command-palette and tab-navigation registration
- placeholder-tab creation/start-empty-tab helpers
- workspace-level host-selection replacement helpers

What should stay local in this batch:
- `host_list.dart`
- `server_tab_builder.dart`
- feature-specific action flow wording
- detailed host availability and distro probing behavior

Done definition:
- `server_workspace_view.dart` is materially smaller and more focused on hosting/rendering
- the new seam clearly owns top-level Server module orchestration
- host list and server tab-builder behavior remain local and mostly untouched except where needed for the seam

Result:
- extracted [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
- moved top-level Server workspace orchestration out of [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart):
  - host loading kickoff
  - settings-driven host reload coordination
  - command-palette registration/loading
  - tab-navigation registration
  - placeholder-tab creation/start-empty-tab flow
  - workspace-level host selection and placeholder replacement helpers
- kept these local to `server_workspace_view.dart`:
  - host list rendering
  - host availability probing
  - distro on-demand warmup
  - tab/body composition
  - add-server dialog flow

## Task 17.4: re-scope the next Server slice batch
Status: completed

Goal:
- decide whether the next Server batch should deepen the regression floor around the new shell seam or extract another real server-local orchestration seam

Questions to answer:
- is there another architectural seam in `server_workspace_view.dart`
- or is the remaining weight mostly true server-local behavior that should stay together for now

Done definition:
- the next Server batch is explicit
- the choice is based on the post-split code shape, not file-length pressure

Result:
- the next Server batch should deepen the regression floor around the new shell seam
- it should not split host-list rendering, availability probing, or distro warmup yet

Why this is the right next move:
- the remaining weight in [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) is now concentrated in true Server-local behavior:
  - host list rendering
  - host availability probing
  - distro warmup
  - tab/body composition
  - add-server flow
- extracting that immediately would risk creating a fake host/workspace manager instead of improving the architecture
- the new seam:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
  should be locked down first

## Task 17.5: add focused tests for the Server workspace-shell seam
Status: completed

Goal:
- add direct regression coverage around the new Server workspace-shell seam before deciding whether the slice should continue or checkpoint

First test targets:
- `server_workspace_shell_test.dart`
  - command-palette entry loading
  - tab-navigation behavior
  - host reload coordination
  - placeholder replacement / add-tab behavior
  - settings-driven reload decisions

Done definition:
- the Server shell seam has direct focused tests
- the tests validate the extracted orchestration boundary rather than broad host-list widget behavior
- the next slice decision can be made from a safer regression floor

Result:
- added [server_workspace_shell_test.dart](/home/home/personal/cwatch/test/view/features/servers/server_workspace_shell_test.dart)
- direct coverage now exists for:
  - command-palette entry loading
  - tab-navigation behavior
  - host reload coordination
  - placeholder replacement behavior
  - add-tab behavior
  - settings-driven reload decisions

## Task 17.6: re-scope the first Server slice checkpoint
Status: completed

Goal:
- decide whether the first Server slice should continue or checkpoint at the current shell seam

Questions to answer:
- is there another real architectural seam in `server_workspace_view.dart`
- or is the remaining weight mostly true Server-local behavior that should stay together for now

Done definition:
- the next Server slice move is explicit
- the choice is based on the post-test seam shape, not file-length pressure

Result:
- the first Server slice should checkpoint here
- it should not extract another seam from [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) in this pass

Why this is the right stop:
- the remaining weight in `server_workspace_view.dart` is mostly true Server-local behavior:
  - host list rendering
  - host availability probing
  - distro warmup
  - tab/body composition
  - add-server flow
- extracting more right now would likely create a fake host/workspace manager layer instead of a better feature boundary

## Task 17.7: checkpoint the first Server vertical slice
Status: completed

Goal:
- stop the Server slice at a defensible architectural boundary instead of continuing for file-length reduction

Done definition:
- the current Server slice result is explicit
- the next rewrite move should come from the broader sequence, not more Server decomposition by default

Result:
- the first Server vertical slice is now checkpointed

What this slice proved:
- top-level Server workspace orchestration can move into a dedicated seam:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
- that seam is directly covered by:
  - [server_workspace_shell_test.dart](/home/home/personal/cwatch/test/view/features/servers/server_workspace_shell_test.dart)
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) is now narrower and the remaining weight is mostly true Server-local behavior, not shell/runtime ambiguity
