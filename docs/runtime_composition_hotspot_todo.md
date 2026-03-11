# Runtime Composition Hotspot TODO

Status: checkpointed
Purpose: track the next bounded cleanup batches for the current highest-value repo hotspot: runtime and composition ownership.

## Task 25.1: start the runtime/composition hotspot pass
Status: completed

Goal:
- treat runtime/composition ownership cleanup as the first active hotspot from the fresh current-state review
- keep this pass focused on ownership clarity, not on broad layer replacement

Done definition:
- there is one runtime/composition TODO for the new pass
- the first bounded batch is named

Result:
- runtime/composition ownership is now the active repo hotspot
- the first bounded batch should reduce ownership blur without reopening already-checkpointed Docker, SSH, theme, or table internals

## Task 25.2: define the first bounded runtime/composition batch
Status: completed

Goal:
- choose one concrete cleanup slice with strong ownership value and low ambiguity

Done definition:
- one first batch is explicit
- the batch has a clear stop condition
- later concerns remain queued instead of over-planned

Result:
- the first bounded runtime/composition batch is now:
  - server workspace runtime ownership cleanup
- target files:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
  - [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
  - related server feature files only as needed
- stop condition:
  - server workspace runtime assembly, persistence ownership, and feature-local controller ownership are easier to locate from one feature seam
  - no Docker, SSH, theme, or StructuredDataTable reopening is mixed into this batch
  - behavior stays stable

Why this is the right first cut:
- server workspace assembly currently shows the ownership blur clearly
- it sits at the intersection of bindings, view-hosted workflow ownership, and runtime bags
- it is a better proving slice for the new hotspot than reopening already-reduced subsystem internals

## Queued Next Batches

These are intentionally not yet active:
- workspace-shell hosting reuse across Docker/Server/WSL
- settings mutation/composition cleanup
- SSH factory/runtime-cache simplification
- file-operation UI deduplication
- config metadata single-source-of-truth cleanup

## Task 25.3: define the first server runtime ownership cut
Status: completed

Goal:
- choose one concrete ownership seam inside the server workspace runtime setup
- keep the batch focused on feature-local runtime assembly rather than broad workspace redesign

Done definition:
- one server runtime ownership seam is explicit
- the stop condition is clear from the current file shape

Result:
- the first implementation batch is now:
  - move server runtime assembly into the server feature runtime seam
- target files:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- stop condition:
  - server-specific runtime assembly no longer lives in a dedicated cross-folder binding
  - the server feature runtime is the obvious place to find server runtime construction
  - behavior stays stable

Why this is the right first cut:
- the current binding is only used by the server feature view
- the assembly logic is feature-specific rather than shared DI infrastructure
- moving it feature-local improves ownership clarity without changing runtime behavior

## Task 25.4: implement the first server runtime ownership cut
Status: completed

Goal:
- move server workspace runtime construction into the server feature runtime seam

Done definition:
- [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart) owns server-specific runtime assembly through a feature-local constructor/factory
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) no longer depends on a dedicated server workspace binding
- the deleted binding did not provide shared reuse beyond this feature

Result:
- server-specific runtime assembly now lives in:
  - [server_workspace_runtime.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_runtime.dart)
- the server workspace view now depends directly on the feature runtime seam:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- the dedicated cross-folder server binding was removed:
  - [server_workspace_binding.dart](/home/home/personal/cwatch/lib/controller/di/bindings/server_workspace_binding.dart)

## Task 25.5: define the next server runtime ownership cut
Status: completed

Goal:
- choose the next ownership seam from the current server runtime/controller state
- keep the batch on restore-time tab reconstruction rather than broad shell redesign

Done definition:
- one new server ownership batch is explicit
- the stop condition reflects the current code shape

Result:
- the next bounded runtime/composition batch is now:
  - server workspace restore ownership cleanup
- target files:
  - [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
  - new server feature-local restore helper under `lib/view/features/servers/`
- stop condition:
  - host resolution and restored tab reconstruction no longer live inline in the controller
  - the controller keeps persistence/orchestration responsibility
  - behavior stays stable

Why this is the right next cut:
- the controller still mixes workspace persistence with restore-time feature tab reconstruction
- that restore logic is feature-local assembly, not generic tabbed workspace infrastructure
- this gives a cleaner ownership split without reopening the broader workspace shell contract yet

## Task 25.6: implement the next server runtime ownership cut
Status: completed

Goal:
- move restore-time server tab reconstruction into a dedicated feature-local helper

Done definition:
- one helper owns host resolution and restored tab reconstruction
- [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart) no longer owns that inline restore support block
- focused regression coverage exists for the helper

Result:
- server restore ownership now lives in:
  - [server_workspace_tab_restorer.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_tab_restorer.dart)
- the server workspace controller now keeps persistence and restore orchestration while delegating reconstruction:
  - [server_workspace_controller.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_controller.dart)
- focused regression coverage exists in:
  - [server_workspace_tab_restorer_test.dart](/home/home/personal/cwatch/test/view/features/servers/server_workspace_tab_restorer_test.dart)

## Task 25.7: define the next server workspace hosting cut
Status: completed

Goal:
- choose the next ownership seam from the current server workspace view state
- keep the batch on feature-local tab assembly and mutation rather than broad shell extraction

Done definition:
- one new server hosting batch is explicit
- the stop condition reflects the current view shape

Result:
- the next bounded runtime/composition batch is now:
  - server workspace tab-helper split
- target files:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - new server feature-local helper under `lib/view/features/servers/`
- stop condition:
  - feature-local tab creation/open helpers and rename-state mutation no longer live inline in the view
  - the view keeps shell hosting and widget lifecycle responsibility
  - behavior stays stable

Why this is the right next cut:
- the server workspace view still mixes shell hosting with feature tab assembly details
- those tab creation and mutation rules are feature-local support logic, not widget lifecycle behavior
- this gives a real ownership improvement without prematurely attempting cross-feature shell reuse

## Task 25.8: implement the next server workspace hosting cut
Status: completed

Goal:
- move server feature tab creation/opening/rename support into a dedicated helper

Done definition:
- one helper owns feature-local server tab creation/opening and rename-state mutation
- [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart) no longer owns those inline support blocks
- focused regression coverage exists for the helper

Result:
- server feature tab support now lives in:
  - [server_workspace_tab_helper.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_tab_helper.dart)
- the server workspace view now delegates feature-local tab support while keeping shell hosting:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
- focused regression coverage exists in:
  - [server_workspace_tab_helper_test.dart](/home/home/personal/cwatch/test/view/features/servers/server_workspace_tab_helper_test.dart)

## Task 25.9: define the first cross-feature workspace-shell hosting cut
Status: completed

Goal:
- choose the first real shared seam across server, docker, and WSL workspace hosting
- keep the batch on repeated hosting policy rather than attempting a broad generic workspace shell abstraction

Done definition:
- one cross-feature seam is explicit
- the batch reflects repeated logic proven in multiple feature modules

Result:
- the next bounded runtime/composition batch is now:
  - shared workspace settings-sync policy split
- target files:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
  - new shared helper under `lib/view/core/tabs/`
- stop condition:
  - restore-on-settings-change and persist-if-pending policy no longer repeats across workspace modules
  - feature-specific side effects remain local
  - behavior stays stable

Why this is the right first cross-feature cut:
- the repeated restore/persist policy is already shared conceptually across server, docker, and WSL
- the logic is small, pure, and easy to test directly
- it reduces duplication without forcing premature convergence of richer feature-specific shell behavior

## Task 25.10: implement the first cross-feature workspace-shell hosting cut
Status: completed

Goal:
- extract shared workspace settings-sync policy into a dedicated tab-shell helper

Done definition:
- one shared helper owns restore-on-settings-change and persist-if-pending orchestration
- server, docker, and WSL workspace hosts no longer repeat that policy inline
- focused regression coverage exists for the helper

Result:
- shared workspace settings-sync policy now lives in:
  - [workspace_settings_sync.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_settings_sync.dart)
- server, docker, and WSL workspace hosting now delegate that shared policy:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- focused regression coverage exists in:
  - [workspace_settings_sync_test.dart](/home/home/personal/cwatch/test/view/core/tabs/workspace_settings_sync_test.dart)

## Task 25.11: define the next cross-feature workspace hosting cut
Status: completed

Goal:
- choose the next small but real shared workspace-hosting seam from the current cross-feature state
- keep the batch on repeated tab-host setup rather than broader shell contract redesign

Done definition:
- one new cross-feature seam is explicit
- the seam is proven by repetition across server, docker, and WSL

Result:
- the next bounded runtime/composition batch is now:
  - shared workspace tab-registry builder split
- target files:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
  - new shared helper under `lib/view/core/tabs/`
- stop condition:
  - repeated `TabViewRegistry<WorkspaceTab>` creation with the same keep-alive wrapper no longer lives inline in those feature entry views
  - behavior stays stable

Why this is the right next cut:
- the registry setup is duplicated nearly verbatim across the workspace modules
- it is a pure shared host concern, not feature policy
- it reduces duplication without forcing a larger generic workspace entry abstraction yet

## Task 25.12: implement the next cross-feature workspace hosting cut
Status: completed

Goal:
- extract shared workspace tab-registry construction into a dedicated tab-host helper

Done definition:
- one shared helper owns standard `TabViewRegistry<WorkspaceTab>` construction
- server, docker, and WSL entry views no longer repeat that setup inline
- focused regression coverage exists for the helper

Result:
- shared tab-registry construction now lives in:
  - [workspace_tab_registry_builder.dart](/home/home/personal/cwatch/lib/view/core/tabs/workspace_tab_registry_builder.dart)
- server, docker, and WSL workspace entry views now delegate that shared host concern:
  - [server_workspace_view.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_view.dart)
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- focused regression coverage exists in:
  - [workspace_tab_registry_builder_test.dart](/home/home/personal/cwatch/test/view/core/tabs/workspace_tab_registry_builder_test.dart)

## Task 25.13: define the next shared workspace chrome cut
Status: completed

Goal:
- choose the next small shared shell-host concern from the current cross-feature state
- keep the batch on repeated shell chrome registration lifecycle rather than generic feature-host redesign

Done definition:
- one new cross-feature seam is explicit
- the seam is proven by repetition across multiple workspace shells

Result:
- the next bounded runtime/composition batch is now:
  - shared workspace shell-chrome registration split
- target files:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
  - [docker_view_shell.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_shell.dart)
  - [kubernetes_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_workspace_shell.dart)
  - new shared helper under `lib/view/core/navigation/`
- stop condition:
  - repeated command-palette/tab-navigation registration and teardown no longer lives inline in those feature shells
  - feature-specific navigation and command loading stay local
  - behavior stays stable

Why this is the right next cut:
- the registration lifecycle is repeated nearly verbatim across the feature workspace shells
- it is a clear shell/framework concern, not feature policy
- it reduces duplication without forcing WSL into a command-palette shape it does not currently use

## Task 25.14: implement the next shared workspace chrome cut
Status: completed

Goal:
- extract shared workspace shell-chrome registration lifecycle into a dedicated navigation helper

Done definition:
- one shared helper owns command-palette/tab-navigation registration and teardown
- server, docker, and Kubernetes shells no longer repeat that lifecycle inline
- focused regression coverage exists for the helper

Result:
- shared workspace shell-chrome registration now lives in:
  - [workspace_shell_chrome.dart](/home/home/personal/cwatch/lib/view/core/navigation/workspace_shell_chrome.dart)
- server, docker, and Kubernetes workspace shells now delegate that shared lifecycle:
  - [server_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/servers/server_workspace_shell.dart)
  - [docker_view_shell.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view_shell.dart)
  - [kubernetes_workspace_shell.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_workspace_shell.dart)
- focused regression coverage exists in:
  - [workspace_shell_chrome_test.dart](/home/home/personal/cwatch/test/view/core/navigation/workspace_shell_chrome_test.dart)

## Task 25.15: checkpoint the current runtime/composition pass
Status: completed

Goal:
- stop the current runtime/composition pass at a real value boundary instead of forcing broader speculative host abstraction work

Done definition:
- the tracker explicitly records the current checkpoint
- the strongest repeated ownership seams removed in this pass are summarized
- the remaining runtime/composition work is described from the current code state

Result:
- the current runtime/composition pass is checkpointed from the latest code state
- the strongest ownership and hosting seams addressed in this pass are now:
  - server-specific runtime assembly ownership
  - server restore-time tab reconstruction ownership
  - server feature-local tab creation/opening/rename support ownership
  - shared workspace settings-sync policy
  - shared workspace tab-registry construction
  - shared workspace shell-chrome registration lifecycle
- the remaining runtime/composition weight is now less about repeated low-risk seams and more about larger feature-host contracts in:
  - [docker_view.dart](/home/home/personal/cwatch/lib/view/features/docker/docker_view.dart)
  - [kubernetes_context_list.dart](/home/home/personal/cwatch/lib/view/features/kubernetes/kubernetes_context_list.dart)
  - [wsl_view.dart](/home/home/personal/cwatch/lib/view/features/wsl/wsl_view.dart)
- the next reopen should come either from:
  - a clearly bounded shared workspace-host contract with strong payoff
  - or fresh evidence that one feature entry surface still carries a high-value ownership knot on its own
