# Workspace Shell Hosting Hotspot TODO

Status: active
Purpose: track the next bounded cleanup batches for the current highest-value repo hotspot: workspace-shell hosting reuse.

## Task 26.1: start the workspace-shell hosting hotspot pass
Status: completed

Goal:
- treat workspace-shell hosting reuse as the first active hotspot from the current code state
- focus on repeated workspace-host lifecycle seams before inventing a larger shared host abstraction

Done definition:
- there is one active TODO for workspace-shell hosting reuse
- the first bounded batch is named from the current feature state

Result:
- workspace-shell hosting reuse is now the active repo hotspot
- the first bounded batch should come from the clearest remaining feature mismatch in the current code state

## Task 26.2: define the first bounded workspace-shell hosting batch
Status: completed

Goal:
- choose one concrete feature-local shell-hosting seam with high reuse value and low ambiguity
- keep the batch on repeated shell chrome/settings-sync ownership rather than broad feature-runtime redesign

Done definition:
- one explicit first batch is named
- the stop condition reflects the current file shape

Result:
- the first bounded workspace-shell hosting batch is now:
  - align WSL with the existing feature shell-hosting pattern
- target files:
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
  - new WSL shell helper under `lib/view/features/wsl/`
  - WSL-focused tests under `test/view/features/wsl/`
- stop condition:
  - WSL no longer owns tab-navigation registration, command-palette registration, and settings-sync policy directly in widget state
  - those shell-host lifecycle responsibilities live in a dedicated WSL feature shell helper
  - behavior stays stable

Why this is the right first cut:
- WSL is the clearest remaining mismatch against Server, Docker, and Kubernetes
- the repeated seam is shell-host lifecycle, not WSL-specific terminal behavior
- aligning WSL first gives a cleaner current-state baseline before deciding whether a broader shared host contract is warranted

## Task 26.3: implement the first bounded workspace-shell hosting batch
Status: completed

Goal:
- align WSL with the existing feature shell-hosting pattern already used by Server, Docker, and Kubernetes
- move shell-host lifecycle responsibility out of the WSL widget state without changing WSL feature behavior

Done definition:
- WSL shell-host lifecycle ownership lives in a dedicated feature shell helper
- `wsl_view.dart` no longer directly owns tab-navigation registration, command-palette registration, or settings-sync policy
- focused WSL shell coverage exists

Result:
- WSL shell-host lifecycle now lives in:
  - [wsl_view_shell.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view_shell.dart)
- the WSL feature view now delegates shell chrome and settings-sync ownership:
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- focused coverage now exists in:
  - [wsl_view_shell_test.dart](/home/home/personal/cwatch/test/view/features/wsl/wsl_view_shell_test.dart)

## Task 26.4: define the next bounded workspace-shell hosting batch
Status: completed

Goal:
- choose the next repeated shell-hosting seam from the current post-WSL state
- keep the batch on actual cross-feature bootstrap duplication rather than forcing a broad shared host abstraction

Done definition:
- one explicit next batch is named
- the stop condition reflects the current code state after WSL alignment

Result:
- the next bounded workspace-shell hosting batch is now:
  - reduce repeated workspace bootstrap wiring across Server, Docker, and WSL
- target files:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
  - shared workspace-host helper under `lib/view/core/` only if the extracted seam is genuinely cross-feature
- stop condition:
  - repeated tab-registry/bootstrap wiring is materially reduced
  - feature-local placeholder/picker behavior stays local
  - no speculative all-features workspace-host contract is introduced

Why this is the right next cut:
- WSL was the strongest mismatch, and that mismatch is now reduced
- the next real repeated seam is the remaining feature-entry bootstrap code around registry setup and shell-host initialization
- this keeps the hotspot focused on proven duplication instead of over-generalizing too early

## Task 26.5: implement the next bounded workspace-shell hosting batch
Status: completed

Goal:
- reduce the repeated feature-entry bootstrap around workspace listeners, settings listeners, shell-host initialization, and restore kickoff
- keep placeholder/picker creation and feature-specific shell behavior local

Done definition:
- Server, Docker, and WSL no longer hand-wire the same workspace host lifecycle in widget state
- the shared lifecycle seam lives in a shared workspace helper
- focused coverage exists for the shared lifecycle helper

Result:
- shared workspace host lifecycle wiring now lives in:
  - [workspace_host_lifecycle.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_host_lifecycle.dart)
- Server, Docker, and WSL now delegate the repeated bootstrap wiring:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- focused coverage now exists in:
  - [workspace_host_lifecycle_test.dart](/home/home/personal/cwatch/test/view/core/tabs/workspace_host_lifecycle_test.dart)

## Task 26.6: define the next bounded workspace-shell hosting batch
Status: completed

Goal:
- choose the next workspace-hosting seam from the current post-lifecycle state
- avoid forcing a broad shared host contract unless the remaining duplication is still concrete

Done definition:
- one explicit next move is named from the current code state
- the stop condition reflects the smaller remaining duplication

Result:
- the next bounded workspace-shell hosting move should be:
  - checkpoint this hotspot unless fresh evidence shows another concrete shared host seam with real payoff
- stop condition:
  - no broader shared workspace-host contract is introduced without a stronger repeated seam than the current code state shows
  - future work reopens from concrete duplication, not from momentum alone

Why this is the right next move:
- the largest remaining repeated host-lifecycle seam is now extracted
- what remains is more feature-local runtime and placeholder behavior than shared workspace hosting
- pushing further now risks over-generalizing valid feature differences
